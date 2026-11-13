import router from '@system.router';
import featureAbility from '@ohos.ability.featureAbility';
import { drawScene } from '../../common/draw.js';

function pad2(n) {
    return n < 10 ? '0' + n : '' + n;
}

export default {
    data: {
        clock: '',
        hrText: '- -',
        starting: false
    },

    onInit() {
        this.checked = false;
        this.timer = null;
    },

    onShow() {
        const def = this.$app.$def;
        def.store.ready().then(() => {
            def.engine.setProfile(def.store.profile());
            if (!this.checked) {
                this.checked = true;
                // Незавершённая тренировка (перезапуск приложения / часов) — сразу туда.
                if (def.engine.restore(def.store.cachedSession())) {
                    router.replace({ uri: def.engine.pendingSummary() ? 'pages/summary/summary' : 'pages/workout/workout' });
                    return;
                }
                if (!def.store.profile().configured) {
                    router.push({ uri: 'pages/settings/settings' });
                    return;
                }
            }
            def.platform.startHeartRate();
            this.refresh();
            this.stopTimer();
            this.timer = setInterval(() => this.refresh(), 1000);
        });
        this.paint();
    },

    onHide() {
        this.stopTimer();
        if (!this.$app.$def.engine.isActive()) {
            this.$app.$def.platform.stopHeartRate();
        }
    },

    onDestroy() {
        this.stopTimer();
    },

    stopTimer() {
        if (this.timer !== null) {
            clearInterval(this.timer);
            this.timer = null;
        }
    },

    refresh() {
        const d = new Date();
        this.clock = pad2(d.getHours()) + ':' + pad2(d.getMinutes());
        const hr = this.$app.$def.platform.heartRate();
        this.hrText = hr > 0 ? '' + hr : '- -';
    },

    paint() {
        const cv = this.$refs.bg;
        if (cv) {
            drawScene(cv.getContext('2d', { antialias: true }), { scene: 'menu' });
        }
    },

    start() {
        if (this.starting) {
            return;
        }
        this.starting = true;
        const def = this.$app.$def;
        def.platform.vibrate('tap');
        def.store.ready().then(() => this.requestHealthPermission()).then(() => {
            def.engine.setProfile(def.store.profile());
            def.engine.start();
            this.starting = false;
            router.replace({ uri: 'pages/workout/workout' });
        });
    },

    /** Пульс — user_grant-разрешение; без него калории считаются по MET. */
    requestHealthPermission() {
        return new Promise((resolve) => {
            try {
                featureAbility.getContext().requestPermissionsFromUser(['ohos.permission.READ_HEALTH_DATA'], 1, () => resolve());
            } catch (e) {
                resolve();
            }
        });
    },

    openSettings() {
        this.$app.$def.platform.vibrate('tap');
        router.push({ uri: 'pages/settings/settings' });
    }
};
