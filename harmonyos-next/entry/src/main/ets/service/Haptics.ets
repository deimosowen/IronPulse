import { vibrator } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'IronPulse.Haptics';

/** Тактильная обратная связь (@ohos.vibrator). */
export class Haptics {
  static enabled: boolean = true;

  private static vibrate(durationMs: number, usage: vibrator.Usage): void {
    if (!Haptics.enabled) {
      return;
    }
    try {
      vibrator.startVibration({ type: 'time', duration: durationMs }, { id: 0, usage: usage })
        .catch((e: BusinessError) => hilog.warn(0x0001, TAG, `vibrate: ${e.code}`));
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0001, TAG, `vibrate: ${err.code}`);
    }
  }

  /** Короткий одиночный отклик — начало/завершение подхода, кнопки. */
  static tap(): void {
    Haptics.vibrate(40, 'touch');
  }

  /** Шаг колесика/степпера — едва заметный тик. */
  static tick(): void {
    Haptics.vibrate(12, 'touch');
  }

  /** Двойной предупреждающий сигнал — за 5 с до конца отдыха. */
  static warnDouble(): void {
    Haptics.vibrate(120, 'alarm');
    setTimeout(() => Haptics.vibrate(120, 'alarm'), 260);
  }

  /** Длинный отчётливый сигнал — отдых закончился (00:00). */
  static long(): void {
    Haptics.vibrate(800, 'alarm');
  }
}
