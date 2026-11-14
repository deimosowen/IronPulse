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
        hrMax: '--'
    },

    onInit() {
        this.zoneMs = [0, 0, 0];
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
        this.zoneMs = s.zoneMs;
    },

    onShow() {
        const cv = this.$refs.bg;
        if (cv) {
            drawScene(cv.getContext('2d', { antialias: true }), { scene: 'summary', zoneMs: this.zoneMs });
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
