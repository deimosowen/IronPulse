import sensor from '@system.sensor';
import vibrator from '@system.vibrator';
import vibratorMs from '@ohos.vibrator';
import runningLock from '@ohos.runningLock';
import reminderAgent from '@ohos.reminderAgent';
import brightness from '@system.brightness';
import { t } from './i18n.js';

/**
 * Платформенный слой для часов на HarmonyOS 3 (API 8, JS FA):
 * пульс (@system.sensor), вибрация (@system.vibrator), удержание экрана (@system.brightness).
 */
const STALE_MS = 5000; // нет свежего пульса дольше 5 с → «--»

let hr = 0;
let hrTs = 0;
let onBody = true;
let hrRunning = false;

let wakeLock = null;
const WAKE_MS = 6 * 3600 * 1000;

/**
 * Не даём процессору уснуть во время тренировки (экран при этом гаснет как обычно),
 * иначе таймеры и вибрация отдыха замирают до пробуждения экрана.
 */
export function holdCpu(on) {
  try {
    if (on) {
      if (wakeLock !== null) {
        wakeLock.lock(WAKE_MS);
        return;
      }
      runningLock.createRunningLock('ironpulse_workout', runningLock.RunningLockType.BACKGROUND)
        .then((lock) => {
          wakeLock = lock;
          wakeLock.lock(WAKE_MS);
          console.info('IronPulse wake lock on');
        })
        .catch((e) => console.error('IronPulse wake lock failed: ' + e));
    } else if (wakeLock !== null) {
      wakeLock.unlock();
      console.info('IronPulse wake lock off');
    }
  } catch (e) {
    console.error('IronPulse wake lock: ' + e);
  }
}

export function startHeartRate() {
  if (hrRunning) {
    return;
  }
  hrRunning = true;
  try {
    sensor.subscribeHeartRate({
      success: (ret) => {
        const v = Math.round(ret.heartRate);
        if (v > 0 && v < 250) {
          hr = v;
          hrTs = Date.now();
        } else {
          hr = 0;
        }
      },
      fail: (data, code) => {
        console.error('IronPulse HR subscribe failed: ' + code + ' ' + data);
      }
    });
  } catch (e) {
    console.error('IronPulse HR: ' + e);
  }
  try {
    sensor.subscribeOnBodyState({
      success: (ret) => {
        onBody = ret.value !== false;
        if (!onBody) {
          hr = 0;
        }
      },
      fail: (data, code) => {
        console.warn('IronPulse on-body unavailable: ' + code);
      }
    });
  } catch (e) {
    console.warn('IronPulse on-body: ' + e);
  }
}

export function stopHeartRate() {
  if (!hrRunning) {
    return;
  }
  hrRunning = false;
  try {
    sensor.unsubscribeHeartRate();
  } catch (e) {
    console.warn('IronPulse HR unsubscribe: ' + e);
  }
  try {
    sensor.unsubscribeOnBodyState();
  } catch (e) {
    console.warn('IronPulse on-body unsubscribe: ' + e);
  }
  hr = 0;
}

/** Текущий пульс или 0, если часы сняты / нет контакта / данные устарели. */
export function heartRate() {
  if (!onBody || Date.now() - hrTs > STALE_MS) {
    return 0;
  }
  return hr;
}

function buzz(mode) {
  try {
    vibrator.vibrate({ mode: mode });
  } catch (e) {
    console.warn('IronPulse vibrate: ' + e);
  }
}

/**
 * tap  — короткий одиночный (кнопки начала/завершения подхода)
 * tick — короткий (шаг колесика / ±)
 * warn — двойной (за 5 с до конца отдыха)
 * long — длинный (цель отдыха)
 * short1 — одна короткая (3:00 отдыха), short2 — две короткие (5:00 отдыха)
 */
/** Импульс заданной длины (мс); системный «short» слишком слабый (35 мс). */
function pulse(ms) {
  try {
    vibratorMs.vibrate(ms).catch(() => buzz('short'));
  } catch (e) {
    buzz('short');
  }
}

export function vibrate(kind) {
  if (kind === 'long') {
    buzz('long');                       // 1 с — цель отдыха
  } else if (kind === 'warn' || kind === 'short2') {
    pulse(180);                         // двойной: за 5 с до цели и на 5:00
    setTimeout(() => pulse(180), 380);
  } else if (kind === 'short1') {
    pulse(220);                         // одиночный: 3:00
  } else {
    buzz('short');                      // касания кнопок
  }
}

let screenHeld = false;

/** Не гасить экран (во время отдыха: иначе система заморозит приложение и сигналы не прозвучат). */
export function keepScreenOn(on, force) {
  if (screenHeld === on && !force) {
    return;
  }
  screenHeld = on;
  try {
    brightness.setKeepScreenOn({
      keepScreenOn: on,
      fail: (data, code) => {
        screenHeld = null;     // повторим при следующем вызове
        console.warn('IronPulse keepScreenOn failed: ' + code);
      }
    });
  } catch (e) {
    screenHeld = null;
    console.warn('IronPulse keepScreenOn: ' + e);
  }
}

let restTargetAt = 0;     // абсолютное время цели отдыха (0 — нет)
let reminderId = -1;

/** Движок сообщает, через сколько мс наступит цель отдыха (-1 — цели нет). */
export function scheduleRestAlarm(ms) {
  restTargetAt = ms >= 0 ? Date.now() + ms : 0;
  if (ms < 0) {
    disarmReminder();
  }
}

/**
 * Экран погас (страница скрыта): система заморозит приложение и таймер движка
 * не сработает — ставим системный таймер-напоминание на цель отдыха.
 */
export function armReminder() {
  disarmReminder();
  const left = restTargetAt - Date.now();
  if (restTargetAt === 0 || left < 1500) {
    return;
  }
  try {
    reminderAgent.publishReminder({
      reminderType: reminderAgent.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: Math.round(left / 1000),
      title: 'IronPulse',
      content: t('reminder'),
      ringDuration: 1,
      // Поднять IronPulse на экран: приложение оживёт и само даст длинную вибрацию.
      wantAgent: { pkgName: 'com.ironpulse.watch', abilityName: 'com.ironpulse.watch.MainAbility' },
      maxScreenWantAgent: { pkgName: 'com.ironpulse.watch', abilityName: 'com.ironpulse.watch.MainAbility' }
    }).then((id) => {
      reminderId = id;
      console.info('IronPulse reminder ' + id + ' in ' + Math.round(left / 1000) + 's');
    }).catch((e) => console.error('IronPulse reminder failed: ' + JSON.stringify(e)));
  } catch (e) {
    console.error('IronPulse reminder: ' + e);
  }
}

/** Экран снова включён — движок сам даст сигнал, системный таймер не нужен. */
export function disarmReminder() {
  if (reminderId < 0) {
    return;
  }
  const id = reminderId;
  reminderId = -1;
  try {
    reminderAgent.cancelReminder(id).catch(() => {});
  } catch (e) {
    console.warn('IronPulse cancel reminder: ' + e);
  }
}
