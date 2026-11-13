import { kcalPerMinute } from './calories.js';
import { zoneOf } from './theme.js';

/**
 * IronPulse v2 — ядро тренировки (чистый JS, без системных API → тестируется в Node).
 *
 * Фазы: ready → set → rest → set → … ; finish → итог → close (сброс).
 * Время — по wall-clock с учётом пауз: если процесс заморозили (экран погас),
 * при следующем tick() пропущенное время докручивается.
 *
 * Отдых считается ВПЕРЁД, без цели. Сигналы: 3:00 — одна короткая вибрация, 5:00 — две короткие.
 * Упражнения: удержание «Начать подход» или кнопка в панели начинают новое упражнение.
 */

/** Отметки отдыха. Последняя задаёт шкалу кольца отдыха. */
export const REST_MARKS = [{ ms: 180000, kind: 'short1' }, { ms: 300000, kind: 'short2' }];
export const REST_SCALE_MS = REST_MARKS[REST_MARKS.length - 1].ms;
const AUTOSAVE_MS = 15000;
const MAX_CATCHUP_MS = 10 * 60 * 1000;

export function defaultProfile() {
  return { weightKg: 80, age: 30, sex: 'male', vibration: true, configured: false };
}

const noop = () => {};
let deps = {
  now: () => Date.now(),
  heartRate: () => 0,
  vibrate: noop,          // 'tap' | 'tick' | 'long' | 'short1' | 'short2'
  saveSession: noop,
  clearSession: noop,
  setTimeout: (fn, ms) => setTimeout(fn, ms),
  clearTimeout: (id) => clearTimeout(id),
  onActiveChange: noop,   // (active) — сенсоры
  onRestMark: noop        // (msUntilNextMark | -1) — резервный системный будильник
};

let session = null;
let profile = defaultProfile();
let listeners = [];
let timerId = null;
let lastSaveTs = 0;
let summary = null;

export function configure(d) {
  deps = Object.assign({}, deps, d);
}

export function setProfile(p) {
  profile = Object.assign(defaultProfile(), p);
}

export function getProfile() {
  return profile;
}

export function isActive() {
  return session !== null;
}

function emptyAcc() {
  return { hrSum: 0, hrSamples: 0, hrMax: 0 };
}

// ================= Жизненный цикл =================

export function start() {
  const now = deps.now();
  session = {
    v: 3,
    id: '' + now,
    startTs: now,
    lastTickTs: now,
    elapsedMs: 0,
    pausedMs: 0,
    paused: false,
    finished: false,
    phase: 'ready',
    phaseStartMs: 0,
    exercise: 0,
    setInExercise: 0,
    totalSets: 0,
    pendingNewExercise: false,
    restMarks: 0,             // сколько отметок REST_MARKS уже отработано в текущем отдыхе
    restHrStart: 0,
    calories: 0,
    hrSum: 0,
    hrSamples: 0,
    hrMax: 0,
    zoneMs: [0, 0, 0],
    phaseAcc: emptyAcc(),
    sets: [],
    rests: []
  };
  summary = null;
  deps.onActiveChange(true);
  persist();
  scheduleTick();
  emit();
}

export function restore(cached) {
  if (session !== null) {
    return true;
  }
  if (!cached || cached.v !== 3) {
    return false;
  }
  const now = deps.now();
  if (now - cached.lastTickTs > MAX_CATCHUP_MS) {
    cached.lastTickTs = now - MAX_CATCHUP_MS;
  }
  session = cached;
  summary = null;
  if (cached.finished) {
    summary = buildSummary(cached);
    return true;
  }
  deps.onActiveChange(true);
  tick();
  armRestMark();
  return true;
}

// ================= Подписка UI =================

export function subscribe(fn) {
  listeners.push(fn);
  fn(view());
  return () => {
    listeners = listeners.filter((l) => l !== fn);
  };
}

function emit() {
  const v = view();
  listeners.forEach((l) => l(v));
}

// ================= Таймер =================

function stopTimer() {
  if (timerId !== null) {
    deps.clearTimeout(timerId);
    timerId = null;
  }
}

function phaseMs() {
  return session.elapsedMs - session.phaseStartMs;
}

function nextMarkIn() {
  const s = session;
  if (s.phase !== 'rest' || s.restMarks >= REST_MARKS.length) {
    return -1;
  }
  return REST_MARKS[s.restMarks].ms - phaseMs();
}

/** ~1 с, выровнено по секунде фазового таймера; в отдыхе — точно к отметке. */
function scheduleTick() {
  stopTimer();
  if (session === null || session.finished) {
    return;
  }
  let delay = 1000;
  if (!session.paused) {
    delay = 1000 - (phaseMs() % 1000);
    const toMark = nextMarkIn();
    if (toMark > 0 && toMark < delay) {
      delay = toMark;
    }
    delay = Math.max(20, delay);
  }
  timerId = deps.setTimeout(() => {
    timerId = null;
    tick();
  }, delay);
}

export function tick() {
  const s = session;
  if (s === null || s.finished) {
    return;
  }
  const now = deps.now();
  const delta = Math.max(0, now - s.lastTickTs);
  s.lastTickTs = now;
  if (s.paused) {
    s.pausedMs += delta;
  } else if (delta > 0) {
    s.elapsedMs += delta;
    const hr = deps.heartRate();
    s.calories += kcalPerMinute(hr, profile) * delta / 60000;
    if (hr > 0) {
      s.hrSum += hr * delta;
      s.hrSamples += delta;
      s.hrMax = Math.max(s.hrMax, hr);
      s.phaseAcc.hrSum += hr * delta;
      s.phaseAcc.hrSamples += delta;
      s.phaseAcc.hrMax = Math.max(s.phaseAcc.hrMax, hr);
      const z = zoneOf(hr);
      if (z >= 0) {
        s.zoneMs[z] += delta;
      }
      if (s.phase === 'rest' && s.restHrStart === 0) {
        s.restHrStart = hr;
      }
    }
    if (s.phase === 'rest') {
      // После долгой «заморозки» отрабатываем только последнюю пройденную отметку и только если она свежая.
      let fired = null;
      while (s.restMarks < REST_MARKS.length && phaseMs() >= REST_MARKS[s.restMarks].ms) {
        fired = REST_MARKS[s.restMarks];
        s.restMarks += 1;
      }
      if (fired !== null) {
        if (phaseMs() - fired.ms < 5000) {
          vibrate(fired.kind);
        }
        armRestMark();
        persist();
      }
    }
  }
  if (now - lastSaveTs > AUTOSAVE_MS) {
    persist();
  }
  scheduleTick();
  emit();
}

function vibrate(kind) {
  if (profile.vibration) {
    deps.vibrate(kind);
  }
}

/** Сообщить платформе, через сколько наступит следующая отметка отдыха (-1 — нет). */
function armRestMark() {
  const s = session;
  if (s === null || s.finished || s.paused) {
    deps.onRestMark(-1);
    return;
  }
  const ms = nextMarkIn();
  deps.onRestMark(ms > 0 ? ms : -1);
}

// ================= Действия =================

/** Начать подход. newExercise — удержание кнопки (подход 1 нового упражнения). */
export function startSet(newExercise) {
  const s = session;
  if (s === null || s.finished || s.phase === 'set') {
    return;
  }
  tick();
  const now = deps.now();
  if (s.phase === 'rest') {
    const hrNow = deps.heartRate();
    s.rests.push({
      startTs: now - phaseMs(),
      durMs: phaseMs(),
      hrStart: s.restHrStart,
      hrEnd: hrNow > 0 ? hrNow : 0,
      marks: s.restMarks
    });
  }
  if (newExercise === true || s.pendingNewExercise || s.exercise === 0) {
    s.exercise += 1;
    s.setInExercise = 0;
  }
  s.pendingNewExercise = false;
  s.setInExercise += 1;
  s.totalSets += 1;
  s.phase = 'set';
  s.phaseStartMs = s.elapsedMs;
  s.phaseAcc = emptyAcc();
  vibrate(newExercise === true ? 'long' : 'tap');
  armRestMark();
  persist();
  scheduleTick();
  emit();
}

/** «Завершить подход» → отдых. */
export function finishSet() {
  const s = session;
  if (s === null || s.finished || s.phase !== 'set') {
    return;
  }
  tick();
  const now = deps.now();
  s.sets.push({
    exercise: s.exercise,
    n: s.setInExercise,
    startTs: now - phaseMs(),
    durMs: phaseMs(),
    hrAvg: s.phaseAcc.hrSamples > 0 ? Math.round(s.phaseAcc.hrSum / s.phaseAcc.hrSamples) : 0,
    hrMax: s.phaseAcc.hrMax
  });
  s.phase = 'rest';
  s.phaseStartMs = s.elapsedMs;
  s.phaseAcc = emptyAcc();
  s.restMarks = 0;
  const hr = deps.heartRate();
  s.restHrStart = hr > 0 ? hr : 0;
  vibrate('tap');
  armRestMark();
  persist();
  scheduleTick();
  emit();
}

/** Кнопка «Новое упражнение» в панели: следующий подход будет первым в новом упражнении. */
export function markNewExercise() {
  const s = session;
  if (s === null || s.finished || s.exercise === 0) {
    return;
  }
  s.pendingNewExercise = !s.pendingNewExercise;
  vibrate('tap');
  persist();
  emit();
}

export function togglePause() {
  const s = session;
  if (s === null || s.finished) {
    return;
  }
  tick();
  s.paused = !s.paused;
  s.lastTickTs = deps.now();
  vibrate('tap');
  armRestMark();
  persist();
  scheduleTick();
  emit();
}

/** Завершить тренировку → итог. Сессия в кэше до close(). */
export function finish() {
  const s = session;
  if (s === null) {
    return summary;
  }
  if (!s.finished) {
    tick();
    if (s.phase === 'set') {
      finishSet();
    }
    s.finished = true;
    s.paused = true;
    stopTimer();
    deps.onRestMark(-1);
    deps.onActiveChange(false);
    persist();
    vibrate('long');
  }
  summary = buildSummary(s);
  emit();
  return summary;
}

export function pendingSummary() {
  if (summary === null && session !== null && session.finished) {
    summary = buildSummary(session);
  }
  return summary;
}

/** «Готово» на итоге: статистика сбрасывается (история не хранится). */
export function close() {
  stopTimer();
  if (session !== null && !session.finished) {
    deps.onRestMark(-1);
    deps.onActiveChange(false);
  }
  session = null;
  summary = null;
  deps.clearSession();
  emit();
}

export function buildSummary(s) {
  const workMs = s.sets.reduce((a, x) => a + x.durMs, 0);
  const restMs = s.rests.reduce((a, x) => a + x.durMs, 0);
  return {
    durationMs: s.elapsedMs,
    pausedMs: s.pausedMs,
    sets: s.totalSets,
    exercises: s.exercise,
    calories: Math.round(s.calories),
    hrAvg: s.hrSamples > 0 ? Math.round(s.hrSum / s.hrSamples) : 0,
    hrMax: s.hrMax,
    zoneMs: [s.zoneMs[0], s.zoneMs[1], s.zoneMs[2]],
    workMs: workMs,
    restMs: restMs,
    avgSetMs: s.sets.length > 0 ? Math.round(workMs / s.sets.length) : 0,
    avgRestMs: s.rests.length > 0 ? Math.round(restMs / s.rests.length) : 0
  };
}

function persist() {
  if (session === null) {
    return;
  }
  deps.saveSession(session);
  lastSaveTs = deps.now();
}

/** Плоский снимок для UI. */
export function view() {
  const s = session;
  if (s === null) {
    return { active: false };
  }
  const hr = deps.heartRate();
  const pm = phaseMs();
  const nextIsNew = s.pendingNewExercise || s.exercise === 0;
  const resting = s.phase === 'rest';
  return {
    active: true,
    finished: s.finished,
    paused: s.paused,
    phase: s.phase,
    elapsedMs: s.elapsedMs,
    phaseMs: pm,
    hr: hr,
    zone: zoneOf(hr),
    exercise: Math.max(1, s.exercise),
    setNumber: s.phase === 'ready' ? 0 : s.setInExercise,
    nextExercise: nextIsNew ? s.exercise + 1 : Math.max(1, s.exercise),
    nextSet: nextIsNew ? 1 : s.setInExercise + 1,
    pendingNewExercise: s.pendingNewExercise,
    totalSets: s.totalSets,
    exercises: s.exercise,
    restMarks: resting ? s.restMarks : 0,             // 0 — до 3:00, 1 — после 3:00, 2 — после 5:00
    restNextMarkMs: resting && s.restMarks < REST_MARKS.length ? REST_MARKS[s.restMarks].ms : 0,
    restProgress: resting ? Math.min(1, pm / REST_SCALE_MS) : 0,
    hrDrop: resting && s.restHrStart > 0 && hr > 0 ? s.restHrStart - hr : 0,
    calories: s.calories
  };
}

/** Только для тестов. */
export function _resetForTests() {
  stopTimer();
  session = null;
  summary = null;
  listeners = [];
  lastSaveTs = 0;
  profile = defaultProfile();
}
