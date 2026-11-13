import { ExerciseDef, Template } from './Types';

export const EXERCISES: ExerciseDef[] = [
  // Грудь
  { id: 'bench', name: 'Жим лёжа', group: 'chest', defaultWeight: 60, defaultReps: 10, step: 2.5 },
  { id: 'incline_db', name: 'Жим гантелей на наклонной', group: 'chest', defaultWeight: 22.5, defaultReps: 10, step: 2.5 },
  { id: 'dips', name: 'Отжимания на брусьях', group: 'chest', defaultWeight: 0, defaultReps: 12, step: 2.5 },
  { id: 'fly', name: 'Сведение в кроссовере', group: 'chest', defaultWeight: 15, defaultReps: 12, step: 2.5 },
  // Трицепс
  { id: 'french', name: 'Французский жим', group: 'triceps', defaultWeight: 25, defaultReps: 12, step: 2.5 },
  { id: 'pushdown', name: 'Разгибания на блоке', group: 'triceps', defaultWeight: 20, defaultReps: 12, step: 2.5 },
  // Спина
  { id: 'deadlift', name: 'Становая тяга', group: 'back', defaultWeight: 80, defaultReps: 6, step: 5 },
  { id: 'pullup', name: 'Подтягивания', group: 'back', defaultWeight: 0, defaultReps: 8, step: 2.5 },
  { id: 'row', name: 'Тяга штанги в наклоне', group: 'back', defaultWeight: 50, defaultReps: 10, step: 2.5 },
  { id: 'lat', name: 'Тяга верхнего блока', group: 'back', defaultWeight: 45, defaultReps: 12, step: 2.5 },
  // Бицепс
  { id: 'curl', name: 'Подъём штанги на бицепс', group: 'biceps', defaultWeight: 25, defaultReps: 10, step: 2.5 },
  { id: 'hammer', name: 'Молотки', group: 'biceps', defaultWeight: 12.5, defaultReps: 12, step: 2.5 },
  // Ноги
  { id: 'squat', name: 'Приседания', group: 'legs', defaultWeight: 70, defaultReps: 8, step: 5 },
  { id: 'legpress', name: 'Жим ногами', group: 'legs', defaultWeight: 120, defaultReps: 10, step: 5 },
  { id: 'rdl', name: 'Румынская тяга', group: 'legs', defaultWeight: 60, defaultReps: 10, step: 2.5 },
  { id: 'lunge', name: 'Выпады', group: 'legs', defaultWeight: 20, defaultReps: 12, step: 2.5 },
  // Плечи
  { id: 'ohp', name: 'Жим стоя', group: 'shoulders', defaultWeight: 40, defaultReps: 8, step: 2.5 },
  { id: 'lateral', name: 'Махи в стороны', group: 'shoulders', defaultWeight: 10, defaultReps: 15, step: 1 },
  { id: 'facepull', name: 'Тяга к лицу', group: 'shoulders', defaultWeight: 20, defaultReps: 15, step: 2.5 },
];

export const TEMPLATES: Template[] = [
  { id: 'free', name: 'Свободная', exerciseIds: [] },
  { id: 'chest_tri', name: 'Грудь / Трицепс', exerciseIds: ['bench', 'incline_db', 'dips', 'fly', 'french', 'pushdown'] },
  { id: 'back_bi', name: 'Спина / Бицепс', exerciseIds: ['deadlift', 'pullup', 'row', 'lat', 'curl', 'hammer'] },
  { id: 'legs_sh', name: 'Ноги / Плечи', exerciseIds: ['squat', 'legpress', 'rdl', 'lunge', 'ohp', 'lateral', 'facepull'] },
  { id: 'full', name: 'Фулбоди', exerciseIds: ['squat', 'bench', 'row', 'ohp', 'rdl', 'curl'] },
];

export function findExercise(id: string): ExerciseDef | undefined {
  return EXERCISES.find((e: ExerciseDef) => e.id === id);
}

export function findTemplate(id: string): Template {
  const t = TEMPLATES.find((x: Template) => x.id === id);
  return t !== undefined ? t : TEMPLATES[0];
}

/** Упражнения шаблона первыми, затем остальные из базы. */
export function exercisesForTemplate(templateId: string): ExerciseDef[] {
  const t = findTemplate(templateId);
  const first: ExerciseDef[] = [];
  t.exerciseIds.forEach((id: string) => {
    const e = findExercise(id);
    if (e !== undefined) {
      first.push(e);
    }
  });
  const rest = EXERCISES.filter((e: ExerciseDef) => t.exerciseIds.indexOf(e.id) < 0);
  return first.concat(rest);
}

export function weightStep(exerciseId: string): number {
  const e = findExercise(exerciseId);
  return e !== undefined ? e.step : 2.5;
}
