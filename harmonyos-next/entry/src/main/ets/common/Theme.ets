/**
 * Палитра и размеры IronPulse (AMOLED-first: абсолютно чёрный фон).
 */
export class Colors {
  static readonly BG: string = '#000000';
  static readonly TEXT: string = '#FFFFFF';
  static readonly MUTED: string = '#90A4AE';
  static readonly SURFACE: string = '#1A1A1A';
  static readonly SURFACE_2: string = '#262626';
  static readonly SET: string = '#FFAB00';     // фаза «Подход»
  static readonly REST: string = '#29B6F6';    // фаза «Отдых»
  static readonly ZONE_LOW: string = '#00E676';  // < 110
  static readonly ZONE_MID: string = '#FFAB00';  // 110–145
  static readonly ZONE_HIGH: string = '#FF3D00'; // > 145
  static readonly DANGER: string = '#FF3D00';
  static readonly ON_ACCENT: string = '#000000';
}

export class Sizes {
  static readonly BUTTON_H: number = 48;   // минимальная высота крупных кнопок (vp)
  static readonly SMALL_BTN: number = 44;  // кнопки ± (vp)
  static readonly RADIUS: number = 24;
}

export class HrZones {
  static readonly LOW_MAX: number = 110;
  static readonly MID_MAX: number = 145;
  static readonly GAUGE_MIN: number = 50;
  static readonly GAUGE_MAX: number = 190;

  /** 0 — восстановление, 1 — рабочая, 2 — пиковая. -1 — нет данных. */
  static zoneOf(hr: number): number {
    if (hr <= 0) {
      return -1;
    }
    if (hr < HrZones.LOW_MAX) {
      return 0;
    }
    if (hr <= HrZones.MID_MAX) {
      return 1;
    }
    return 2;
  }

  static colorOf(hr: number): string {
    const z = HrZones.zoneOf(hr);
    if (z === 0) {
      return Colors.ZONE_LOW;
    }
    if (z === 1) {
      return Colors.ZONE_MID;
    }
    if (z === 2) {
      return Colors.ZONE_HIGH;
    }
    return Colors.SURFACE_2;
  }
}
