import * as engine from './common/engine.js';
import store from './common/store.js';
import * as platform from './common/platform.js';

/**
 * В модели FA каждая страница — отдельный бандл, поэтому общее состояние
 * (движок тренировки и хранилище) живёт здесь; страницы берут его через this.$app.$def.
 */
engine.configure({
  now: () => Date.now(),
  heartRate: () => platform.heartRate(),
  vibrate: (kind) => platform.vibrate(kind),
  saveSession: (s) => store.saveSession(s),
  clearSession: () => store.clearSession(),
  setTimeout: (fn, ms) => setTimeout(fn, ms),
  clearTimeout: (id) => clearTimeout(id),
  onActiveChange: (active) => {
    if (active) {
      platform.startHeartRate();
    } else {
      platform.stopHeartRate();
    }
    platform.holdCpu(active);
  },
  onRestMark: (ms) => platform.scheduleRestAlarm(ms)
});

export default {
  engine: engine,
  store: store,
  platform: platform,

  onCreate() {
    store.ready().then(() => {
      engine.setProfile(store.profile());
    });
  },

  onDestroy() {
    // Обязательно отпускаем датчик пульса (иначе его зелёная подсветка может остаться включённой).
    platform.stopHeartRate();
    platform.holdCpu(false);
    platform.keepScreenOn(false);
    platform.scheduleRestAlarm(-1);
  }
};
