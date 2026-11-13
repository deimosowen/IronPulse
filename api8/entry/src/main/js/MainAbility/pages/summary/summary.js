import router from '@system.router';
import { formatClock, plural } from '../../common/format.js';
import { drawScene } from '../../common/draw.js';

export default {
    data: {
        total: '0:00',
        sets: 0,
        exText: '',
        setsWord: 'подходов',
        kcal: 0,
        hrAvg: '--',
        hrMax: '--',
        z0: 0,
        z1: 0,
        z2: 0,
        zEmpty: true
    },

    onInit() {
        const s = this.$app.$def.engine.pendingSummary();
        if (s === null) {
            return;
        }
        this.total = formatClock(s.durationMs);
        this.sets = s.sets;
        this.exText = s.exercises > 1 ? ' · ' + s.exercises + ' упр' : '';
        this.setsWord = plural(s.sets, 'подход', 'подхода', 'подходов');
        this.kcal = s.calories;
        this.hrAvg = s.hrAvg > 0 ? '' + s.hrAvg : '- -';
        this.hrMax = s.hrMax > 0 ? '' + s.hrMax : '- -';
        const all = s.zoneMs[0] + s.zoneMs[1] + s.zoneMs[2];
        if (all > 0) {
            this.z0 = Math.round(s.zoneMs[0] * 100 / all);
            this.z1 = Math.round(s.zoneMs[1] * 100 / all);
            this.z2 = Math.round(s.zoneMs[2] * 100 / all);
            this.zEmpty = false;
        }
    },

    onShow() {
        const cv = this.$refs.bg;
        if (cv) {
            drawScene(cv.getContext('2d', { antialias: true }), { scene: 'summary' });
        }
    },

    /** Итог нельзя потерять кнопкой «назад». */
    onBackPress() {
        return true;
    },

    close() {
        this.$app.$def.platform.vibrate('tap');
        this.$app.$def.engine.close();
        router.replace({ uri: 'pages/index/index' });
    }
};
