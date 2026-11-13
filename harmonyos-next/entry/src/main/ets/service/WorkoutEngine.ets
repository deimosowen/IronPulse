import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  BestSet, ExerciseDef, ExerciseLog, LastWeight, Phase, Profile, SetRecord, WorkoutSession, WorkoutSummary
} from '../model/Types';
import { findExercise, findTemplate, weightStep } from '../model/Exercises';
import { HrZones } from '../common/Theme';
import { Storage } from '../data/Storage';
import { HistoryStore } from '../data/HistoryStore';
import { HeartRateService } from './HeartRateService';
import { Haptics } from './Haptics';
import { BackgroundRunner } from './BackgroundRunner';
import { kcalPerMinute } from './Calories';

const TAG = 'IronPulse.Engine';
const WARN_BEFORE_MS = 5000;
const AUTOSAVE_EVERY_MS = 15000;
const MAX_WEIGHT = 500;
const MAX_REPS = 100;

/** Плоский снимок состояния для UI. Каждый раз — новый объект (триггер @State). */
export interface EngineView {
  active: boolean;
  paused: boolean;
  phase: Phase;
  elapsedMs: number;
  hr: number;
  exerciseId: string;
  exerciseName: string;
  setNumber: number;        // номер текущего/следующего подхода
  plannedWeight: number;
  plannedReps: number;
  weightStep: number;
  restRemainingMs: number;
  restTotalMs: number;
  tonnage: number;
  calories: number;
  totalSets: number;
  exerciseSetsDone: number;
  exerciseMaxWeight: number;
  templateId: string;
  doneExerciseIds: string[];
}

export type EngineListener = (v: EngineView) => void;

function emptyView(): EngineView {
  const v: EngineView = {
    active: false, paused: false, phase: 'set', elapsedMs: 0, hr: 0,
    exerciseId: '', exerciseName: '', setNumber: 1, plannedWeight: 0, plannedReps: 0, weightStep: 2.5,
    restRemainingMs: 0, restTotalMs: 0, tonnage: 0, calories: 0, totalSets: 0,
    exerciseSetsDone: 0, exerciseMaxWeight: 0, templateId: 'free', doneExerciseIds: []
  };
  return v;
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.min(hi, Math.max(lo, v));
}

function round1(v: number): number {
  return Math.round(v * 10) / 10;
}

/**
 * Ядро тренировки (синглтон, живёт независимо от страниц).
 * Время считается по wall-clock: если процесс был приостановлен, при следующем
 * тике «пропущенное» время докручивается — общий таймер и отдых не теряются.
 */
export class WorkoutEngine {
  private static session: WorkoutSession | null = null;
  private static profile: Profile = Storage.loadProfile();
  private static listeners: Map<number, EngineListener> = new Map<number, EngineListener>();
  private static nextListenerId: number = 1;
  private static timerId: number = -1;
  private static lastSaveTs: number = 0;
  private static ctx: common.UIAbilityContext | null = null;
  private static summary: WorkoutSummary | null = null;

  // ================= Жизненный цикл =================

  static isActive(): boolean {
    return WorkoutEngine.session !== null;
  }

  static start(ctx: common.UIAbilityContext, templateId: string): void {
    WorkoutEngine.ctx = ctx;
    WorkoutEngine.profile = Storage.loadProfile();
    Haptics.enabled = WorkoutEngine.profile.vibration;
    const now = Date.now();
    const s: WorkoutSession = {
      id: `${now}`,
      templateId: templateId,
      startTs: now,
      elapsedMs: 0,
      lastTickTs: now,
      paused: false,
      finished: false,
      phase: 'set',
      restTotalMs: 0,
      restRemainingMs: 0,
      restWarned: false,
      exercises: [],
      currentIndex: 0,
      plannedWeight: 0,
      plannedReps: 0,
      calories: 0,
      hrSum: 0,
      hrSamples: 0,
      hrMax: 0,
      zoneMs: [0, 0, 0],
      customCounter: 0
    };
    WorkoutEngine.session = s;
    WorkoutEngine.summary = null;
    const t = findTemplate(templateId);
    if (t.exerciseIds.length > 0) {
      WorkoutEngine.switchTo(t.exerciseIds[0]);
    } else {
      WorkoutEngine.newCustomInternal();
    }
    WorkoutEngine.resumeServices();
    WorkoutEngine.persist();
    WorkoutEngine.emit();
  }

  /** Восстановление после закрытия приложения / перезагрузки часов. */
  static restore(ctx: common.UIAbilityContext): boolean {
    if (WorkoutEngine.session !== null) {
      WorkoutEngine.ctx = ctx;
      return true;
    }
    const cached = Storage.loadActiveSession();
    if (cached === null) {
      return false;
    }
    WorkoutEngine.ctx = ctx;
    WorkoutEngine.profile = Storage.loadProfile();
    Haptics.enabled = WorkoutEngine.profile.vibration;
    // Время простоя приложения не засчитываем как тренировку, если была пауза;
    // иначе считаем, что тренировка шла (часы перезагрузились посреди занятия).
    // Чтобы не «накрутить» часы при долгом простое, ограничиваем догон 10 минутами.
    const gap = Date.now() - cached.lastTickTs;
    if (gap > 10 * 60 * 1000) {
      cached.lastTickTs = Date.now() - 10 * 60 * 1000;
    }
    cached.finished = cached.finished === true; // кэш старой версии мог не содержать поле
    WorkoutEngine.session = cached;
    WorkoutEngine.summary = null;
    if (cached.finished) {
      // Тренировка завершена, но итоги не сохранены — сразу к экрану итогов.
      WorkoutEngine.summary = WorkoutEngine.buildSummary(cached);
      return true;
    }
    WorkoutEngine.resumeServices();
    WorkoutEngine.tick();
    hilog.info(0x0001, TAG, 'session restored');
    return true;
  }

  private static resumeServices(): void {
    HeartRateService.start();
    if (WorkoutEngine.ctx !== null) {
      BackgroundRunner.start(WorkoutEngine.ctx);
    }
    WorkoutEngine.scheduleTick();
    const s = WorkoutEngine.session;
    if (s !== null && s.phase === 'rest' && !s.paused) {
      BackgroundRunner.scheduleRestReminder(s.restRemainingMs / 1000);
    }
  }

  private static stopServices(): void {
    if (WorkoutEngine.timerId >= 0) {
      clearTimeout(WorkoutEngine.timerId);
      WorkoutEngine.timerId = -1;
    }
    HeartRateService.stop();
    if (WorkoutEngine.ctx !== null) {
      BackgroundRunner.stop(WorkoutEngine.ctx);
    }
  }

  // ================= Подписка UI =================

  static subscribe(l: EngineListener): number {
    const id = WorkoutEngine.nextListenerId++;
    WorkoutEngine.listeners.set(id, l);
    l(WorkoutEngine.view());
    return id;
  }

  static unsubscribe(id: number): void {
    WorkoutEngine.listeners.delete(id);
  }

  private static emit(): void {
    const v = WorkoutEngine.view();
    WorkoutEngine.listeners.forEach((l: EngineListener) => l(v));
  }

  // ================= Таймер =================

  /** Динамический шаг: 1 с, но во время отдыха — точно к моменту 00:00 и к сигналу за 5 с. */
  private static scheduleTick(): void {
    if (WorkoutEngine.timerId >= 0) {
      clearTimeout(WorkoutEngine.timerId);
    }
    let delay = 1000;
    const s = WorkoutEngine.session;
    if (s !== null && !s.paused) {
      // Выравниваем по границе секунды общего таймера, чтобы цифры менялись ровно.
      delay = 1000 - (s.elapsedMs % 1000);
      if (s.phase === 'rest') {
        const toWarn = s.restRemainingMs - WARN_BEFORE_MS;
        if (!s.restWarned && toWarn > 0 && toWarn < delay) {
          delay = toWarn;
        }
        if (s.restRemainingMs > 0 && s.restRemainingMs < delay) {
          delay = s.restRemainingMs;
        }
      }
      delay = Math.max(20, delay);
    }
    WorkoutEngine.timerId = setTimeout(() => {
      WorkoutEngine.timerId = -1;
      WorkoutEngine.tick();
    }, delay);
  }

  /** Учёт прошедшего времени. Вызывается таймером и при возврате приложения на передний план. */
  static tick(): void {
    const s = WorkoutEngine.session;
    if (s === null) {
      return;
    }
    const now = Date.now();
    const delta = Math.max(0, now - s.lastTickTs);
    s.lastTickTs = now;
    if (!s.paused && delta > 0) {
      s.elapsedMs += delta;
      const hr = HeartRateService.current();
      s.calories += kcalPerMinute(hr, WorkoutEngine.profile) * delta / 60000;
      if (hr > 0) {
        s.hrSum += hr * delta;
        s.hrSamples += delta;
        s.hrMax = Math.max(s.hrMax, hr);
        const z = HrZones.zoneOf(hr);
        if (z >= 0) {
          s.zoneMs[z] += delta;
        }
      }
      if (s.phase === 'rest') {
        s.restRemainingMs -= delta;
        if (!s.restWarned && s.restRemainingMs <= WARN_BEFORE_MS && s.restRemainingMs > 0 &&
          s.restTotalMs > WARN_BEFORE_MS) {
          s.restWarned = true;
          Haptics.warnDouble();
        }
        if (s.restRemainingMs <= 0) {
          WorkoutEngine.endRest(true);
        }
      }
    }
    if (now - WorkoutEngine.lastSaveTs > AUTOSAVE_EVERY_MS) {
      WorkoutEngine.persist();
    }
    WorkoutEngine.scheduleTick();
    WorkoutEngine.emit();
  }

  private static endRest(byTimer: boolean): void {
    const s = WorkoutEngine.session;
    if (s === null) {
      return;
    }
    s.phase = 'set';
    s.restRemainingMs = 0;
    s.restWarned = false;
    BackgroundRunner.cancelRestReminder();
    if (byTimer) {
      Haptics.long();
    } else {
      Haptics.tap();
    }
    WorkoutEngine.persist();
  }

  // ================= Действия пользователя =================

  /** «Завершить подход»: записываем подход и запускаем отдых. */
  static finishSet(): void {
    const s = WorkoutEngine.session;
    if (s === null || s.phase !== 'set') {
      return;
    }
    WorkoutEngine.tick();
    const log = s.exercises[s.currentIndex];
    const rec: SetRecord = { weight: s.plannedWeight, reps: s.plannedReps, ts: Date.now() };
    log.sets.push(rec);
    s.phase = 'rest';
    s.restTotalMs = WorkoutEngine.profile.defaultRestSec * 1000;
    s.restRemainingMs = s.restTotalMs;
    s.restWarned = false;
    Haptics.tap();
    if (!s.paused) {
      BackgroundRunner.scheduleRestReminder(s.restRemainingMs / 1000);
    }
    WorkoutEngine.persist();   // auto-save после каждого подхода
    WorkoutEngine.scheduleTick();
    WorkoutEngine.emit();
  }

  /** «Начать подход» — досрочное завершение отдыха. */
  static startSet(): void {
    const s = WorkoutEngine.session;
    if (s === null || s.phase !== 'rest') {
      return;
    }
    WorkoutEngine.tick();
    if (s.phase === 'rest') {
      WorkoutEngine.endRest(false);
    }
    WorkoutEngine.scheduleTick();
    WorkoutEngine.emit();
  }

  /** ±1 к отдыху (например, +30 с) */
  static addRest(deltaMs: number): void {
    const s = WorkoutEngine.session;
    if (s === null || s.phase !== 'rest') {
      return;
    }
    s.restRemainingMs = Math.max(1000, s.restRemainingMs + deltaMs);
    s.restTotalMs = Math.max(s.restTotalMs, s.restRemainingMs);
    if (s.restRemainingMs > WARN_BEFORE_MS) {
      s.restWarned = false;
    }
    if (!s.paused) {
      BackgroundRunner.scheduleRestReminder(s.restRemainingMs / 1000);
    }
    WorkoutEngine.scheduleTick();
    WorkoutEngine.emit();
  }

  /**
   * Изменение веса. В фазе отдыха правится факт только что выполненного подхода
   * И план следующего (в статистику идёт фактический результат).
   */
  static adjustWeight(steps: number): void {
    const s = WorkoutEngine.session;
    if (s === null || steps === 0) {
      return;
    }
    const log = s.exercises[s.currentIndex];
    const step = weightStep(log.exerciseId);
    s.plannedWeight = round1(clamp(s.plannedWeight + steps * step, 0, MAX_WEIGHT));
    if (s.phase === 'rest' && log.sets.length > 0) {
      log.sets[log.sets.length - 1].weight = s.plannedWeight;
    }
    WorkoutEngine.emit();
  }

  static adjustReps(steps: number): void {
    const s = WorkoutEngine.session;
    if (s === null || steps === 0) {
      return;
    }
    const log = s.exercises[s.currentIndex];
    s.plannedReps = clamp(s.plannedReps + steps, 0, MAX_REPS);
    if (s.phase === 'rest' && log.sets.length > 0) {
      log.sets[log.sets.length - 1].reps = s.plannedReps;
    }
    WorkoutEngine.emit();
  }

  /** Сохранение правок, сделанных степперами (вызывается с задержкой из UI). */
  static commitEdits(): void {
    WorkoutEngine.persist();
  }

  static togglePause(): void {
    const s = WorkoutEngine.session;
    if (s === null) {
      return;
    }
    WorkoutEngine.tick();
    s.paused = !s.paused;
    s.lastTickTs = Date.now();
    if (s.paused) {
      BackgroundRunner.cancelRestReminder();
    } else if (s.phase === 'rest') {
      BackgroundRunner.scheduleRestReminder(s.restRemainingMs / 1000);
    }
    Haptics.tap();
    WorkoutEngine.persist();
    WorkoutEngine.scheduleTick();
    WorkoutEngine.emit();
  }

  /** Выбор упражнения из списка. Счётчик подходов — по этому упражнению. */
  static selectExercise(exerciseId: string): void {
    if (WorkoutEngine.session === null) {
      return;
    }
    WorkoutEngine.switchTo(exerciseId);
    Haptics.tap();
    WorkoutEngine.persist();
    WorkoutEngine.emit();
  }

  /** «Новое упражнение» без названия — для экономии времени. */
  static newCustomExercise(): void {
    if (WorkoutEngine.session === null) {
      return;
    }
    WorkoutEngine.newCustomInternal();
    Haptics.tap();
    WorkoutEngine.persist();
    WorkoutEngine.emit();
  }

  /** «Следующее упражнение»: следующее по шаблону, иначе — новое без названия. */
  static nextExercise(): void {
    const s = WorkoutEngine.session;
    if (s === null) {
      return;
    }
    const t = findTemplate(s.templateId);
    const done = s.exercises.filter((l: ExerciseLog) => l.sets.length > 0).map((l: ExerciseLog) => l.exerciseId);
    const curId = s.exercises[s.currentIndex].exerciseId;
    const curPos = t.exerciseIds.indexOf(curId);
    let next = '';
    for (let i = 0; i < t.exerciseIds.length; i++) {
      const cand = t.exerciseIds[(Math.max(curPos, -1) + 1 + i) % t.exerciseIds.length];
      if (cand !== curId && done.indexOf(cand) < 0) {
        next = cand;
        break;
      }
    }
    if (next.length > 0) {
      WorkoutEngine.switchTo(next);
    } else {
      WorkoutEngine.newCustomInternal();
    }
    Haptics.tap();
    WorkoutEngine.persist();
    WorkoutEngine.emit();
  }

  private static newCustomInternal(): void {
    const s = WorkoutEngine.session as WorkoutSession;
    s.customCounter += 1;
    const cur = s.exercises.length > 0 ? s.exercises[s.currentIndex] : undefined;
    const log: ExerciseLog = {
      exerciseId: `custom-${s.customCounter}`,
      name: `Упражнение ${s.customCounter}`,
      sets: []
    };
    WorkoutEngine.dropEmptyCurrent();
    s.exercises.push(log);
    s.currentIndex = s.exercises.length - 1;
    // Для безымянного упражнения сохраняем текущий вес/повторы как стартовую точку.
    if (cur === undefined) {
      s.plannedWeight = 20;
      s.plannedReps = 10;
    }
  }

  private static switchTo(exerciseId: string): void {
    const s = WorkoutEngine.session as WorkoutSession;
    WorkoutEngine.dropEmptyCurrent();
    let idx = s.exercises.findIndex((l: ExerciseLog) => l.exerciseId === exerciseId);
    if (idx < 0) {
      const def: ExerciseDef | undefined = findExercise(exerciseId);
      const log: ExerciseLog = {
        exerciseId: exerciseId,
        name: def !== undefined ? def.name : exerciseId,
        sets: []
      };
      s.exercises.push(log);
      idx = s.exercises.length - 1;
    }
    s.currentIndex = idx;
    const log = s.exercises[idx];
    if (log.sets.length > 0) {
      const last = log.sets[log.sets.length - 1];
      s.plannedWeight = last.weight;
      s.plannedReps = last.reps;
      return;
    }
    // Автоподстановка веса с прошлой тренировки (прогрессия нагрузок).
    const prev: LastWeight | undefined = Storage.lastWeight(exerciseId);
    if (prev !== undefined) {
      s.plannedWeight = prev.weight;
      s.plannedReps = prev.reps;
      return;
    }
    const def = findExercise(exerciseId);
    if (def !== undefined) {
      s.plannedWeight = def.defaultWeight;
      s.plannedReps = def.defaultReps;
    }
  }

  /** Пустое (без подходов) текущее упражнение убираем при переключении, чтобы не засорять итоги. */
  private static dropEmptyCurrent(): void {
    const s = WorkoutEngine.session as WorkoutSession;
    if (s.exercises.length === 0) {
      return;
    }
    const cur = s.exercises[s.currentIndex];
    if (cur !== undefined && cur.sets.length === 0) {
      s.exercises.splice(s.currentIndex, 1);
      s.currentIndex = Math.max(0, s.exercises.length - 1);
    }
  }

  // ================= Завершение =================

  /** Завершить тренировку: останавливаем сервисы и готовим итоги. Кэш остаётся до «Сохранить». */
  static finish(): WorkoutSummary | null {
    const s = WorkoutEngine.session;
    if (s === null) {
      return WorkoutEngine.summary;
    }
    WorkoutEngine.tick();
    s.paused = true;
    s.finished = true;
    WorkoutEngine.persist();
    WorkoutEngine.stopServices();
    WorkoutEngine.summary = WorkoutEngine.buildSummary(s);
    Haptics.long();
    return WorkoutEngine.summary;
  }

  static pendingSummary(): WorkoutSummary | null {
    if (WorkoutEngine.summary === null && WorkoutEngine.session !== null && WorkoutEngine.session.finished) {
      WorkoutEngine.summary = WorkoutEngine.buildSummary(WorkoutEngine.session);
    }
    return WorkoutEngine.summary;
  }

  /** «Сохранить и закрыть»: история + последние веса, очистка кэша. */
  static async saveAndClose(): Promise<void> {
    const s = WorkoutEngine.session;
    const sum = WorkoutEngine.summary;
    if (sum !== null && sum.setsCount > 0) {
      await HistoryStore.save(sum);
    }
    if (s !== null) {
      const map = Storage.loadLastWeights();
      s.exercises.forEach((l: ExerciseLog) => {
        if (l.exerciseId.startsWith('custom-') || l.sets.length === 0) {
          return;
        }
        const last = l.sets[l.sets.length - 1];
        const lw: LastWeight = { weight: last.weight, reps: last.reps };
        map[l.exerciseId] = lw;
      });
      Storage.saveLastWeights(map);
    }
    WorkoutEngine.discard();
  }

  static discard(): void {
    WorkoutEngine.stopServices();
    WorkoutEngine.session = null;
    WorkoutEngine.summary = null;
    Storage.clearActiveSession();
    WorkoutEngine.emit();
  }

  private static buildSummary(s: WorkoutSession): WorkoutSummary {
    let tonnage = 0;
    let setsCount = 0;
    const best: BestSet[] = [];
    s.exercises.forEach((l: ExerciseLog) => {
      if (l.sets.length === 0) {
        return;
      }
      let bw = -1;
      let br = 0;
      let t = 0;
      l.sets.forEach((r: SetRecord) => {
        t += r.weight * r.reps;
        if (r.weight > bw || (r.weight === bw && r.reps > br)) {
          bw = r.weight;
          br = r.reps;
        }
      });
      tonnage += t;
      setsCount += l.sets.length;
      const b: BestSet = { name: l.name, sets: l.sets.length, bestWeight: bw, bestReps: br, tonnage: t };
      best.push(b);
    });
    const sum: WorkoutSummary = {
      id: s.id,
      templateId: s.templateId,
      startTs: s.startTs,
      durationMs: s.elapsedMs,
      tonnage: tonnage,
      setsCount: setsCount,
      calories: Math.round(s.calories),
      hrAvg: s.hrSamples > 0 ? Math.round(s.hrSum / s.hrSamples) : 0,
      hrMax: s.hrMax,
      zoneMs: [s.zoneMs[0], s.zoneMs[1], s.zoneMs[2]],
      exercises: best
    };
    return sum;
  }

  // ================= Служебное =================

  private static persist(): void {
    const s = WorkoutEngine.session;
    if (s === null) {
      return;
    }
    Storage.saveActiveSession(s);
    WorkoutEngine.lastSaveTs = Date.now();
  }

  static view(): EngineView {
    const s = WorkoutEngine.session;
    if (s === null) {
      return emptyView();
    }
    const log = s.exercises[s.currentIndex];
    let tonnage = 0;
    let totalSets = 0;
    const doneIds: string[] = [];
    s.exercises.forEach((l: ExerciseLog) => {
      totalSets += l.sets.length;
      if (l.sets.length > 0) {
        doneIds.push(l.exerciseId);
      }
      l.sets.forEach((r: SetRecord) => {
        tonnage += r.weight * r.reps;
      });
    });
    let maxW = 0;
    log.sets.forEach((r: SetRecord) => {
      maxW = Math.max(maxW, r.weight);
    });
    // В отдыхе номер показывает выполненный подход (его факт мы редактируем),
    // в работе — текущий подход.
    const setNumber = s.phase === 'rest' ? log.sets.length : log.sets.length + 1;
    const v: EngineView = {
      active: true,
      paused: s.paused,
      phase: s.phase,
      elapsedMs: s.elapsedMs,
      hr: HeartRateService.current(),
      exerciseId: log.exerciseId,
      exerciseName: log.name,
      setNumber: Math.max(1, setNumber),
      plannedWeight: s.plannedWeight,
      plannedReps: s.plannedReps,
      weightStep: weightStep(log.exerciseId),
      restRemainingMs: Math.max(0, s.restRemainingMs),
      restTotalMs: s.restTotalMs,
      tonnage: tonnage,
      calories: s.calories,
      totalSets: totalSets,
      exerciseSetsDone: log.sets.length,
      exerciseMaxWeight: maxW,
      templateId: s.templateId,
      doneExerciseIds: doneIds
    };
    return v;
  }

  static reloadProfile(): void {
    WorkoutEngine.profile = Storage.loadProfile();
    Haptics.enabled = WorkoutEngine.profile.vibration;
  }
}
