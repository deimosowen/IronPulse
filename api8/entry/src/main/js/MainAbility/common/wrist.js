/**
 * Жест руки по акселерометру: «поднял посмотреть» / «опустил».
 * Смотрим на долю силы тяжести вдоль оси, перпендикулярной экрану (z):
 * экран к лицу — z/g большое, рука опущена вдоль тела — z/g около нуля.
 * Сильные рывки (подход со штангой) пропускаем: там |a| далеко от g.
 */
export const G = 9.81;
export const RAISE_FRAC = 0.55;   // z/g выше — экран повернут к лицу
export const LOWER_FRAC = 0.3;    // z/g ниже — рука опущена / экран отвёрнут
export const RAISE_HOLD_MS = 250;
export const LOWER_HOLD_MS = 600;

/**
 * feed(x, y, z, now) → 'raise' | 'lower' | null — событие при смене положения.
 * sign: +1, если у этих часов экран вверх даёт z > 0 (так в Android/OpenHarmony).
 */
export function createWrist(sign) {
  const s = sign === -1 ? -1 : 1;
  let state = '';          // '' — ещё не знаем, 'up', 'down'
  let cand = '';
  let candSince = 0;
  let f = null;            // сглаженная доля z/g

  function feed(x, y, z, now) {
    const a = Math.sqrt(x * x + y * y + z * z);
    if (a < 0.6 * G || a > 1.4 * G) {
      cand = '';           // рука в движении — положение не определить
      return null;
    }
    const r = (s * z) / a;
    f = f === null ? r : f + 0.5 * (r - f);
    const want = f > RAISE_FRAC ? 'up' : (f < LOWER_FRAC ? 'down' : '');
    if (want === '' || want === state) {
      cand = '';
      return null;
    }
    if (cand !== want) {
      cand = want;
      candSince = now;
      return null;
    }
    if (now - candSince < (want === 'up' ? RAISE_HOLD_MS : LOWER_HOLD_MS)) {
      return null;
    }
    state = want;
    cand = '';
    return want === 'up' ? 'raise' : 'lower';
  }

  return {
    feed: feed,
    state: () => state
  };
}
