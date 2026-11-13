import { sensor } from '@kit.SensorServiceKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'IronPulse.HR';
const INTERVAL_NS = 1000000000;   // 1 Гц
const STALE_MS = 5000;            // нет свежих данных дольше 5 с → «--»

/**
 * Пульсометр: подписка на HEART_RATE раз в секунду + датчик ношения.
 * current() возвращает 0, если контакта с кожей нет или данные устарели
 * — UI в этом случае показывает «--», а не зависшее старое значение.
 */
export class HeartRateService {
  private static hr: number = 0;
  private static lastTs: number = 0;
  private static worn: boolean = true;
  private static running: boolean = false;

  static start(): void {
    if (HeartRateService.running) {
      return;
    }
    try {
      sensor.on(sensor.SensorId.HEART_RATE, (data: sensor.HeartRateResponse) => {
        if (data.heartRate > 0 && data.heartRate < 250) {
          HeartRateService.hr = Math.round(data.heartRate);
          HeartRateService.lastTs = Date.now();
        } else {
          HeartRateService.hr = 0;
        }
      }, { interval: INTERVAL_NS });
      HeartRateService.running = true;
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0001, TAG, `HEART_RATE subscribe failed: ${err.code} ${err.message}`);
    }
    try {
      sensor.on(sensor.SensorId.WEAR_DETECTION, (data: sensor.WearDetectionResponse) => {
        HeartRateService.worn = data.value !== 0;
        if (!HeartRateService.worn) {
          HeartRateService.hr = 0;
        }
      });
    } catch (e) {
      // Датчик ношения может отсутствовать — остаётся контроль по устареванию данных.
      const err = e as BusinessError;
      hilog.warn(0x0001, TAG, `WEAR_DETECTION unavailable: ${err.code}`);
    }
  }

  static stop(): void {
    if (!HeartRateService.running) {
      return;
    }
    try {
      sensor.off(sensor.SensorId.HEART_RATE);
    } catch (e) {
      hilog.warn(0x0001, TAG, 'HEART_RATE off failed');
    }
    try {
      sensor.off(sensor.SensorId.WEAR_DETECTION);
    } catch (e) {
      hilog.warn(0x0001, TAG, 'WEAR_DETECTION off failed');
    }
    HeartRateService.running = false;
    HeartRateService.hr = 0;
  }

  /** Текущий пульс или 0 («нет данных»). */
  static current(): number {
    if (!HeartRateService.worn) {
      return 0;
    }
    if (Date.now() - HeartRateService.lastTs > STALE_MS) {
      return 0;
    }
    return HeartRateService.hr;
  }
}
