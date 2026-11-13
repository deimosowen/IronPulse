function pad2(n: number): string {
  return n < 10 ? `0${n}` : `${n}`;
}

/** ЧЧ:ММ:СС */
export function formatHms(ms: number): string {
  const total = Math.max(0, Math.floor(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  return `${pad2(h)}:${pad2(m)}:${pad2(s)}`;
}

/** ММ:СС (для таймера отдыха; округление вверх, чтобы 00:00 совпадало с концом) */
export function formatMs(ms: number): string {
  const total = Math.max(0, Math.ceil(ms / 1000));
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${pad2(m)}:${pad2(s)}`;
}

/** Вес: 80 → «80», 82.5 → «82.5» */
export function formatWeight(w: number): string {
  const r = Math.round(w * 10) / 10;
  return Number.isInteger(r) ? `${r}` : r.toFixed(1);
}

/** Тоннаж: 12450 → «12 450» */
export function formatTonnage(kg: number): string {
  const v = Math.round(kg);
  const s = `${v}`;
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

export function formatDate(ts: number): string {
  const d = new Date(ts);
  return `${pad2(d.getDate())}.${pad2(d.getMonth() + 1)} ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

export function formatMinutes(ms: number): string {
  return `${Math.round(ms / 60000)} мин`;
}
