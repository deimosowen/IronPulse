/**
 * Строки интерфейса: русский и английский. Язык берётся из системной локали часов
 * (app.js → @system.configuration); всё, кроме русского, показывается по-английски.
 * В модели FA у каждой страницы своя копия модуля, поэтому страница вызывает useLang() в onInit.
 */
const STRINGS = {
  ru: {
    start: 'СТАРТ',
    bpm: 'уд/мин',
    kcal: 'ккал',
    workout: 'ТРЕНИРОВКА',
    paused: 'НА ПАУЗЕ',
    pausedShort: 'ПАУЗА',
    pausedPill: 'на паузе',
    noHr: 'Пульс не определён',
    zones: ['Восстановление', 'Рабочая зона', 'Пиковая нагрузка'],
    ex: 'УПР',
    set: 'ПОДХОД',
    rest: 'ОТДЫХ',
    alertAt: 'сигнал ',
    past: 'дольше ',
    drop: ' уд',
    exShort: ' упр',
    noSets: 'подходов нет',
    sets: ['подход', 'подхода', 'подходов'],
    resume: 'Продолжить',
    pause: 'Пауза',
    finish: 'Завершить',
    finishSet: 'Завершить подход',
    startSet: 'Начать подход',
    newExercise: 'Новое упражнение',
    nextNew: 'Дальше — новое упр.',
    holdToFinish: 'завершить — удерживайте',
    holding: 'держите…',
    complete: 'ТРЕНИРОВКА ЗАВЕРШЕНА',
    avgHr: 'ср. пульс',
    maxHr: 'макс. пульс',
    done: 'Готово',
    details: 'ПОДРОБНО',
    exercise: 'Упражнение',
    more: 'ещё',
    avgSet: 'ср. подход',
    avgRest: 'ср. отдых',
    recovery: 'спад пульса',
    zonesTitle: 'зоны пульса',
    settings: 'Настройки',
    profile: 'Профиль',
    profileHint: 'нужен для расчёта калорий',
    weight: 'Ваш вес, кг',
    age: 'Возраст',
    mark1: 'Сигнал отдыха 1',
    mark2: 'Сигнал отдыха 2',
    sex: 'Пол',
    male: 'Муж',
    female: 'Жен',
    vibration: 'Вибрация',
    on: 'Вкл',
    off: 'Выкл',
    save: 'Сохранить',
    reminder: 'Отдых — сигнал по времени'
  },
  en: {
    start: 'START',
    bpm: 'bpm',
    kcal: 'kcal',
    workout: 'WORKOUT',
    paused: 'PAUSED',
    pausedShort: 'PAUSED',
    pausedPill: 'paused',
    noHr: 'No heart rate',
    zones: ['Recovery', 'Working zone', 'Peak effort'],
    ex: 'EX',
    set: 'SET',
    rest: 'REST',
    alertAt: 'alert at ',
    past: 'past ',
    drop: ' bpm',
    exShort: ' ex',
    noSets: 'no sets yet',
    sets: ['set', 'sets'],
    resume: 'Resume',
    pause: 'Pause',
    finish: 'Finish',
    finishSet: 'Finish set',
    startSet: 'Start set',
    newExercise: 'New exercise',
    nextNew: 'Next: new exercise',
    holdToFinish: 'hold to finish',
    holding: 'keep holding…',
    complete: 'WORKOUT COMPLETE',
    avgHr: 'avg HR',
    maxHr: 'max HR',
    done: 'Done',
    details: 'DETAILS',
    exercise: 'Exercise',
    more: 'more',
    avgSet: 'avg set',
    avgRest: 'avg rest',
    recovery: 'HR drop',
    zonesTitle: 'HR zones',
    settings: 'Settings',
    profile: 'Profile',
    profileHint: 'used to estimate calories',
    weight: 'Weight, kg',
    age: 'Age',
    mark1: 'Rest alert 1',
    mark2: 'Rest alert 2',
    sex: 'Sex',
    male: 'M',
    female: 'F',
    vibration: 'Vibration',
    on: 'On',
    off: 'Off',
    save: 'Save',
    reminder: 'Rest — time alert'
  }
};

let lang = 'ru';

/** Код языка из локали ('ru', 'en-US', 'ru_RU'…) → 'ru' | 'en'. */
export function pickLang(code) {
  return ('' + (code || '')).toLowerCase().indexOf('ru') === 0 ? 'ru' : 'en';
}

export function useLang(code) {
  lang = pickLang(code);
}

export function getLang() {
  return lang;
}

/** Весь словарь текущего языка — для привязок {{ L.key }} в hml. */
export function strings() {
  return STRINGS[lang];
}

/** Строка по ключу. */
export function t(key) {
  const v = STRINGS[lang][key];
  return v !== undefined ? v : STRINGS.ru[key];
}

/** Форма слова для числа n: ключ указывает на массив форм. */
export function tp(key, n) {
  const f = STRINGS[lang][key];
  if (lang !== 'ru') {
    return n === 1 ? f[0] : f[1];
  }
  const a = Math.abs(n) % 100;
  const b = a % 10;
  if (a > 10 && a < 20) {
    return f[2];
  }
  if (b > 1 && b < 5) {
    return f[1];
  }
  return b === 1 ? f[0] : f[2];
}
