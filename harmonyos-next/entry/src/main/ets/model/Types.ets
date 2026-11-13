export type Phase = 'set' | 'rest';
export type Sex = 'male' | 'female';

export interface Profile {
  weightKg: number;
  age: number;
  sex: Sex;
  defaultRestSec: number;
  vibration: boolean;
  configured: boolean; // профиль заполнен при первом запуске
}

export interface SetRecord {
  weight: number;
  reps: number;
  ts: number;
}

export interface ExerciseLog {
  exerciseId: string; // id из базы или 'custom-N'
  name: string;
  sets: SetRecord[];
}

/** Полное состояние активной сессии — сериализуется в кэш для восстановления. */
export interface WorkoutSession {
  id: string;
  templateId: string;
  startTs: number;
  elapsedMs: number;        // время тренировки без пауз
  lastTickTs: number;       // момент последнего учёта времени (wall-clock)
  paused: boolean;
  finished: boolean;        // «Завершить» нажато, итоги ещё не сохранены
  phase: Phase;
  restTotalMs: number;
  restRemainingMs: number;
  restWarned: boolean;      // двойной сигнал за 5 с уже был
  exercises: ExerciseLog[];
  currentIndex: number;     // индекс в exercises
  plannedWeight: number;
  plannedReps: number;
  calories: number;
  hrSum: number;
  hrSamples: number;
  hrMax: number;
  zoneMs: number[];         // [низкая, рабочая, пиковая]
  customCounter: number;
}

export interface BestSet {
  name: string;
  sets: number;
  bestWeight: number;
  bestReps: number;
  tonnage: number;
}

/** Итог тренировки — то, что хранится в истории. */
export interface WorkoutSummary {
  id: string;
  templateId: string;
  startTs: number;
  durationMs: number;
  tonnage: number;
  setsCount: number;
  calories: number;
  hrAvg: number;
  hrMax: number;
  zoneMs: number[];
  exercises: BestSet[];
}

export interface LastWeight {
  weight: number;
  reps: number;
}

export interface ExerciseDef {
  id: string;
  name: string;
  group: string;
  defaultWeight: number;
  defaultReps: number;
  step: number; // шаг изменения веса
}

export interface Template {
  id: string;
  name: string;
  exerciseIds: string[];
}
