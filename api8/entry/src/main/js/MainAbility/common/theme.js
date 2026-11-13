export const COLORS = {
  BG: '#000000',
  TEXT: '#FFFFFF',
  MUTED: '#90A4AE',
  SURFACE: '#1A1A1A',
  SURFACE_2: '#262626',
  SET: '#FFAB00',
  REST: '#29B6F6',
  ZONE_LOW: '#00E676',
  ZONE_MID: '#FFAB00',
  ZONE_HIGH: '#FF3D00'
};

export const HR = {
  LOW_MAX: 110,
  MID_MAX: 145,
  GAUGE_MIN: 50,
  GAUGE_MAX: 190
};

/** 0 — восстановление (<110), 1 — рабочая (110–145), 2 — пиковая (>145), -1 — нет данных. */
export function zoneOf(hr) {
  if (!(hr > 0)) {
    return -1;
  }
  if (hr < HR.LOW_MAX) {
    return 0;
  }
  if (hr <= HR.MID_MAX) {
    return 1;
  }
  return 2;
}

export function zoneColor(hr) {
  const z = zoneOf(hr);
  if (z === 0) {
    return COLORS.ZONE_LOW;
  }
  if (z === 1) {
    return COLORS.ZONE_MID;
  }
  if (z === 2) {
    return COLORS.ZONE_HIGH;
  }
  return COLORS.SURFACE_2;
}

/** Доля дуги пульса 0..1 для шкалы 50–190 уд/мин. */
export function hrFraction(hr) {
  if (!(hr > 0)) {
    return 0;
  }
  const v = Math.min(HR.GAUGE_MAX, Math.max(HR.GAUGE_MIN, hr));
  return (v - HR.GAUGE_MIN) / (HR.GAUGE_MAX - HR.GAUGE_MIN);
}

export const ZONE_NAMES = ['Восстановление', 'Рабочая зона', 'Пиковая нагрузка'];
