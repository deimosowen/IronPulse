import router from '@system.router';
import { formatClock } from '../../common/format.js';
import { drawScene } from '../../common/draw.js';
import { useLang, strings, t } from '../../common/i18n.js';

const ROTATE_STEP = 15;

const LIMITS = {
    weight: { min: 30, max: 250, step: 1 },
    age: { min: 12, max: 99, step: 1 },
    mark1: { min: 30, max: 570, step: 30 },
    mark2: { min: 60, max: 600, step: 30 }
};

export default {
    data: {
        configured: false,
        field: 'weight',
        weightKg: 80,
        age: 30,
        mark1: 180,
        mark2: 300,
        sex: 'male',
        sexText: '',
        vibration: true,
        steppers: [],
        L: {}
    },

    onInit() {
        useLang(this.$app.$def.lang);
        this.L = strings();
        this.rotAcc = 0;
        const store = this.$app.$def.store;
        store.ready().then(() => {
            const p = store.profile();
            this.configured = p.configured;
            this.weightKg = p.weightKg;
            this.age = p.age;
            this.sex = p.sex;
            this.vibration = p.vibration;
            this.mark1 = p.restMark1Sec;
            this.mark2 = p.restMark2Sec;
            this.refresh();
        });
    },

    onShow() {
        const cv = this.$refs.bg;
        if (cv) {
            drawScene(cv.getContext('2d', { antialias: true }), { scene: 'settings' });
        }
        try {
            this.$element('list').focus();
        } catch (e) {
            console.warn('IronPulse focus: ' + e);
        }
    },

    refresh() {
        this.sexText = t(this.sex === 'male' ? 'male' : 'female');
        this.steppers = [
            { key: 'weight', title: t('weight'), value: '' + this.weightKg },
            { key: 'age', title: t('age'), value: '' + this.age },
            { key: 'mark1', title: t('mark1'), value: formatClock(this.mark1 * 1000) },
            { key: 'mark2', title: t('mark2'), value: formatClock(this.mark2 * 1000) }
        ];
    },

    select(key) {
        this.field = key;
        this.$app.$def.platform.vibrate('tick');
    },

    change(key, steps) {
        this.field = key;
        this.$app.$def.platform.vibrate('tick');
        this.applyChange(key, steps);
    },

    applyChange(key, steps) {
        const l = LIMITS[key];
        const clamp = (v) => Math.min(l.max, Math.max(l.min, v));
        if (key === 'weight') {
            this.weightKg = clamp(this.weightKg + steps * l.step);
        } else if (key === 'age') {
            this.age = clamp(this.age + steps * l.step);
        } else if (key === 'mark1') {
            // первый сигнал всегда раньше второго: при необходимости второй сдвигается следом
            this.mark1 = clamp(this.mark1 + steps * l.step);
            this.mark2 = Math.max(this.mark2, Math.min(LIMITS.mark2.max, this.mark1 + 30));
        } else {
            this.mark2 = clamp(this.mark2 + steps * l.step);
            this.mark1 = Math.min(this.mark1, Math.max(LIMITS.mark1.min, this.mark2 - 30));
        }
        this.refresh();
    },

    /** Колесико меняет выбранное значение (точная регулировка без касаний). */
    onRotate(e) {
        const value = e && e.rotateValue !== undefined ? e.rotateValue : 0;
        this.rotAcc += value;
        const steps = this.rotAcc > 0 ? Math.floor(this.rotAcc / ROTATE_STEP) : Math.ceil(this.rotAcc / ROTATE_STEP);
        if (steps !== 0) {
            this.rotAcc -= steps * ROTATE_STEP;
            this.$app.$def.platform.vibrate('tick');
            this.applyChange(this.field, steps);
        }
    },

    toggleSex() {
        this.sex = this.sex === 'male' ? 'female' : 'male';
        this.refresh();
    },

    toggleVibration() {
        this.vibration = !this.vibration;
    },

    save() {
        const def = this.$app.$def;
        const p = {
            weightKg: this.weightKg,
            age: this.age,
            sex: this.sex,
            vibration: this.vibration,
            restMark1Sec: this.mark1,
            restMark2Sec: this.mark2,
            configured: true
        };
        def.store.saveProfile(p).then(() => {
            def.engine.setProfile(def.store.profile());
            def.platform.vibrate('tap');
            router.back();
        });
    }
};
