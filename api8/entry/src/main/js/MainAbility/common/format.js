function pad2(n) {
  return n < 10 ? '0' + n : '' + n;
}

/** ЧЧ:ММ:СС */
export function formatHms(ms) {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return pad2(h) + ':' + pad2(m) + ':' + pad2(s);
}

/** Таймер фазы: 0:38, 12:34, 1:02:05 (счёт вперёд, округление вниз). */
export function formatClock(ms) {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return h > 0 ? h + ':' + pad2(m) + ':' + pad2(s) : m + ':' + pad2(s);
}

/** ММ:СС для таймера отдыха (округление вверх: 00:00 ровно в момент окончания). */
export function formatMs(ms) {
  const total = Math.max(0, Math.ceil(ms / 1000));
  return pad2(Math.floor(total / 60)) + ':' + pad2(total % 60);
}

/** 80 → «80», 82.5 → «82.5» */
export function formatWeight(w) {
  const r = Math.round(w * 10) / 10;
  return r % 1 === 0 ? '' + r : r.toFixed(1);
}

/** 12450 → «12 450» */
export function formatTonnage(kg) {
  const s = '' + Math.round(kg);
  let out = '';
  for (let i = 0; i < s.length; i++) {
    const fromEnd = s.length - i;
    out += s.charAt(i);
    if (fromEnd > 1 && (fromEnd - 1) % 3 === 0) {
      out += ' ';
    }
  }
  return out;
}

export function formatDate(ts) {
  const d = new Date(ts);
  return pad2(d.getDate()) + '.' + pad2(d.getMonth() + 1) + ' ' + pad2(d.getHours()) + ':' + pad2(d.getMinutes());
}

/** Склонение: plural(1, 'подход', 'подхода', 'подходов') → «подход». */
export function plural(n, one, few, many) {
  const m10 = n % 10;
  const m100 = n % 100;
  if (m10 === 1 && m100 !== 11) {
    return one;
  }
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) {
    return few;
  }
  return many;
}

export function formatMinutes(ms) {
  return Math.round(ms / 60000) + ' мин';
}
