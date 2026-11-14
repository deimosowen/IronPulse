import router from '@system.router';
import { formatClock } from '../../common/format.js';
import { drawScene } from '../../common/draw.js';
import { useLang, strings, t, tp } from '../../common/i18n.js';

export default {
    data: {
        total: '0:00',
        sets: 0,
        exText: '',
        setsWord: '',
        kcal: 0,
        hrAvg: '--',
        hrMax: '--',
        page: 0,
        rows: [],
        avgSet: '- -',
        avgRest: '- -',
        recovery: '- -',
        zone0: '0:00',
        zone1: '0:00',
        zone2: '0:00',
        L: {}
    },

    onInit() {
        useLang(this.$app.$def.lang);
        this.L = strings();
        this.zoneMs = [0, 0, 0];
        const s = this.$app.$def.engine.pendingSummary();
        if (s === null) {
            return;
        }
        this.total = formatClock(s.durationMs);
        this.sets = s.sets;
        this.exText = s.exercises > 1 ? ' · ' + s.exercises + t('exShort') : '';
        this.setsWord = tp('sets', s.sets);
        this.kcal = s.calories;
        this.hrAvg = s.hrAvg > 0 ? '' + s.hrAvg : '- -';
        this.hrMax = s.hrMax > 0 ? '' + s.hrMax : '- -';
        this.zoneMs = s.zoneMs;
        this.fillDetails(s);
    },

    /** Второй экран: упражнения (до 4 строк), средние времена, спад пульса, время в зонах. */
    fillDetails(s) {
        const list = s.perExercise || [];
        const rows = list.length > 4 ? list.slice(0, 3) : list.slice();
        const items = rows.map((e) => ({
            key: 'e' + e.exercise,
            name: t('exercise') + ' ' + e.exercise,
            sets: e.sets + ' × ',
            avg: formatClock(e.avgSetMs)
        }));
        if (list.length > 4) {
            const rest = list.slice(3);
            items.push({
                key: 'more',
                name: t('more') + ' ' + rest.length + t('exShort'),
                sets: '' + rest.reduce((a, e) => a + e.sets, 0),
                avg: ' ' + tp('sets', rest.reduce((a, e) => a + e.sets, 0))
            });
        }
        // строки центрируются в полосе 86…234
        const h = items.length * 38 - 4;
        const top0 = 86 + Math.round((148 - h) / 2);
        items.forEach((it, i) => {
            it.top = top0 + i * 38;
        });
        this.rows = items;
        this.avgSet = s.sets > 0 ? formatClock(s.avgSetMs) : '- -';
        this.avgRest = s.rests > 0 ? formatClock(s.avgRestMs) : '- -';
        this.recovery = s.avgRecovery > 0 ? '−' + s.avgRecovery : '- -';
        this.zone0 = formatClock(s.zoneMs[0]);
        this.zone1 = formatClock(s.zoneMs[1]);
        this.zone2 = formatClock(s.zoneMs[2]);
    },

    onShow() {
        this.paint();
    },

    onPage(e) {
        this.page = e.index;
        this.paint();
    },

    paint() {
        const cv = this.$refs.bg;
        if (cv) {
            drawScene(cv.getContext('2d', { antialias: true }), { scene: 'summary', zoneMs: this.zoneMs, detail: this.page === 1 });
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
