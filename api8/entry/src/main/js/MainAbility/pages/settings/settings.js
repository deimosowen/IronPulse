import router from '@system.router';
import { formatMs } from '../../common/format.js';
import { drawScene } from '../../common/draw.js';

const ROTATE_STEP = 15;

const LIMITS = {
    weight: { min: 30, max: 250, step: 1 },
    age: { min: 12, max: 99, step: 1 },
    rest: { min: 15, max: 600, step: 15 }
};

export default {
    data: {
        configured: false,
        field: 'weight',
        weightKg: 80,
        age: 30,
        restSec: 90,
        sex: 'male',
        sexText: 'Муж',
        vibration: true,
        steppers: []
    },

    onInit() {
        this.rotAcc = 0;
        const store = this.$app.$def.store;
        store.ready().then(() => {
            const p = store.profile();
            this.configured = p.configured;
            this.weightKg = p.weightKg;
            this.age = p.age;
            this.sex = p.sex;
            this.vibration = p.vibration;
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
        this.sexText = this.sex === 'male' ? 'Муж' : 'Жен';
        this.steppers = [
            { key: 'weight', title: 'Ваш вес, кг', value: '' + this.weightKg },
            { key: 'age', title: 'Возраст', value: '' + this.age }
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
        } else {
            this.restSec = clamp(this.restSec + steps * l.step);
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
            configured: true
        };
        def.store.saveProfile(p).then(() => {
            def.engine.setProfile(def.store.profile());
            def.platform.vibrate('tap');
            router.back();
        });
    }
};
