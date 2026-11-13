import router from '@system.router';
import { formatClock, formatHms, plural } from '../../common/format.js';
import { hrFraction, ZONE_NAMES } from '../../common/theme.js';
import { drawScene, drawHoldRing } from '../../common/draw.js';

const V_PANEL = 0;
const V_MAIN = 1;
const TAP_MAX_MS = 400;        // короче — обычное нажатие
const HOLD_NEW_MS = 1500;      // удержание «Начать подход» → новое упражнение
const HOLD_FINISH_MS = 1500;   // удержание «Завершить»
const CTA_W = 270;
const CTA_H = 80;
const DIM_AFTER_MS = 8000;      // без касаний в отдыхе → тёмный режим

export default {
    data: {
        vPage: V_MAIN,
        phase: 'ready',
        paused: false,
        nowText: '',
        timeText: '00:00:00',
        phaseText: '0:00',
        hrText: '- -',
        zoneName: 'Пульс не определён',
        zoneClass: 'zonex-pill',
        zoneDot: 'zonex-dot',
        zoneText: 'zonex-text',
        exercise: 1,
        setNumber: 1,
        restEyebrow: 'ОТДЫХ',
        restLate: false,
        markText: '',
        kcalText: '0',
        dropText: '',
        showDrop: false,
        countText: '',
        pendingNew: false,
        ctaClass: 'cta-amber',
        ctaIcon: '/common/icons/dumbbell_amber.png',
        ctaLabel: 'Начать подход',
        ctaTextClass: 'dark-amber',
        holdW: 0,
        finishHold: 0,
        dim: false,
        dimSet: false,
        dimLabel: '',
        dimSub: ''
    },

    onInit() {
        this.engine = this.$app.$def.engine;
        this.platform = this.$app.$def.platform;
        this.v = null;
        this.ctaTimer = null;
        this.ctaT0 = 0;
        this.ctaFired = false;
        this.finishTimer = null;
        this.leaving = false;
        this.lastTouch = Date.now();
        this.unsubscribe = this.engine.subscribe((v) => this.apply(v));
    },

    onShow() {
        this.platform.disarmReminder();
        this.touched();
        this.engine.tick();   // догнать время после сна экрана
        this.paint();
    },

    /** Экран погас / приложение скрыто — страхуем сигнал цели отдыха системным таймером. */
    onHide() {
        this.platform.armReminder();
    },

    /** Любое касание — выйти из тёмного режима и отложить его. */
    touched() {
        this.lastTouch = Date.now();
        if (this.dim) {
            this.dim = false;
            this.paint();
        }
    },

    wake() {
        this.touched();
    },

    onDestroy() {
        this.platform.keepScreenOn(false);
        if (this.unsubscribe) {
            this.unsubscribe();
        }
        this.stopCta();
        this.stopFinish();
    },

    /** «Назад» не выходит из тренировки — открывает панель. */
    onBackPress() {
        this.vPage = this.vPage === V_PANEL ? V_MAIN : V_PANEL;
        this.paint();
        return true;
    },

    onPage(e) {
        this.touched();
        this.vPage = e.index;
        this.paint();
        if (this.vPage === V_PANEL) {
            this.paintRing(0);
        }
    },

    // ---------- снимок движка → экран ----------

    apply(v) {
        if (!v.active) {
            return;
        }
        if (v.finished) {
            this.platform.keepScreenOn(false);
            this.goSummary();
            return;
        }
        // Вся тренировка: экран не гаснет (иначе приложение заморозят, а система покажет циферблат).
        // Без касаний 8 с — тёмный режим; смена фазы и сигналы отдыха — снова полный экран.
        this.platform.keepScreenOn(true);
        const prev = this.v;
        const event = prev !== null && (v.phase !== prev.phase || v.paused !== prev.paused || v.restMarks > prev.restMarks);
        if (event) {
            this.dim = false;
            this.lastTouch = Date.now();
        } else if (!this.dim && Date.now() - this.lastTouch > DIM_AFTER_MS && this.vPage === V_MAIN) {
            this.dim = true;
        }
        this.dimSet = v.phase === 'set' && !v.paused;
        if (v.paused) {
            this.dimLabel = 'ПАУЗА';
            this.dimSub = '';
        } else if (v.phase === 'set') {
            this.dimLabel = 'УПР ' + v.exercise + ' · ПОДХОД ' + v.setNumber;
            this.dimSub = '';
        } else if (v.phase === 'rest') {
            this.dimLabel = 'ОТДЫХ';
            this.dimSub = v.restNextMarkMs > 0 ? 'сигнал ' + formatClock(v.restNextMarkMs) : 'больше 5 минут';
        } else {
            this.dimLabel = 'ТРЕНИРОВКА';
            this.dimSub = '';
        }
        this.v = v;
        this.phase = v.phase;
        this.paused = v.paused;
        const d = new Date();
        this.nowText = (d.getHours() < 10 ? '0' : '') + d.getHours() + ':' + (d.getMinutes() < 10 ? '0' : '') + d.getMinutes();
        this.timeText = formatHms(v.elapsedMs);
        this.phaseText = formatClock(v.phaseMs);
        this.hrText = v.hr > 0 ? '' + v.hr : '- -';
        const z = v.zone >= 0 ? '' + v.zone : 'x';
        this.zoneName = v.zone >= 0 ? ZONE_NAMES[v.zone] : 'Пульс не определён';
        this.zoneClass = 'zone' + z + '-pill';
        this.zoneDot = 'zone' + z + '-dot';
        this.zoneText = 'zone' + z + '-text';
        this.exercise = v.exercise;
        this.setNumber = v.setNumber;
        this.restLate = v.restMarks >= 2;
        this.kcalText = '' + Math.round(v.calories);
        this.pendingNew = v.pendingNewExercise;
        if (v.phase === 'rest') {
            this.restEyebrow = 'ОТДЫХ · УПР ' + v.exercise + ' · ПОДХОД ' + v.setNumber;
            this.markText = v.restNextMarkMs > 0 ? 'сигнал ' + formatClock(v.restNextMarkMs) : 'больше 5 минут';
            this.showDrop = v.hrDrop > 0;
            this.dropText = '−' + v.hrDrop + ' уд';
        }
        const ex = v.exercises;
        this.countText = ex > 0
            ? ex + ' упр · ' + v.totalSets + ' ' + plural(v.totalSets, 'подход', 'подхода', 'подходов')
            : 'подходов нет';
        if (this.ctaTimer === null) {
            this.applyCta();
        }
        this.paint();
    },

    applyCta() {
        const v = this.v;
        if (v === null) {
            return;
        }
        if (v.paused) {
            this.setCta('cta-amber', '/common/icons/play.png', 'Продолжить', 'dark-amber');
        } else if (v.phase === 'set') {
            this.setCta('cta-white', '/common/icons/check_badge.png', 'Завершить подход', 'dark-ink');
        } else if (v.phase === 'rest' && v.restMarks < 2) {
            this.setCta('cta-blue', '/common/icons/dumbbell_blue.png', 'Начать подход', 'dark-ice');
        } else {
            this.setCta('cta-amber', '/common/icons/dumbbell_amber.png', 'Начать подход', 'dark-amber');
        }
    },

    setCta(cls, icon, label, textCls) {
        this.ctaClass = cls;
        this.ctaIcon = icon;
        this.ctaLabel = label;
        this.ctaTextClass = textCls;
    },

    paint() {
        const cv = this.$refs.bg;
        if (!cv || this.dim) {
            return;
        }
        const v = this.v;
        let scene = 'ready';
        if (this.vPage === V_PANEL) {
            scene = 'panel';
        } else if (v !== null) {
            if (v.paused) {
                scene = 'paused';
            } else if (v.phase === 'rest') {
                scene = v.restMarks >= 2 ? 'restLate' : 'rest';
            } else {
                scene = v.phase;
            }
        }
        drawScene(cv.getContext('2d', { antialias: true }), {
            scene: scene,
            hrFrac: v !== null ? hrFraction(v.hr) : 0,
            zone: v !== null ? v.zone : -1,
            restProgress: v !== null ? v.restProgress : 0,
            restMarks: v !== null ? v.restMarks : 0
        });
    },

    // ---------- главная кнопка: касание / удержание ----------

    ctaDown() {
        this.touched();
        const v = this.v;
        if (v === null || this.leaving) {
            return;
        }
        this.stopCta();
        this.ctaT0 = Date.now();
        this.ctaFired = false;
        // Удержание имеет смысл только для «Начать подход» после первого подхода.
        const canHold = !v.paused && v.phase === 'rest';
        this.ctaTimer = setInterval(() => {
            const el = Date.now() - this.ctaT0;
            if (!canHold || el < TAP_MAX_MS) {
                return;
            }
            const f = Math.min(1, (el - TAP_MAX_MS) / (HOLD_NEW_MS - TAP_MAX_MS));
            this.holdW = Math.round(CTA_H + (CTA_W - CTA_H) * f);
            this.setCta(this.ctaClass, '/common/icons/next_dark.png', 'Новое упражнение', 'dark-amber');
            if (el >= HOLD_NEW_MS) {
                this.ctaFired = true;
                this.stopCta();
                this.engine.startSet(true);
            }
        }, 30);
    },

    ctaUp() {
        if (this.ctaTimer === null && !this.ctaFired) {
            return;
        }
        const el = Date.now() - this.ctaT0;
        const fired = this.ctaFired;
        this.stopCta();
        if (fired) {
            return;
        }
        if (el < TAP_MAX_MS) {
            this.ctaTap();
        }
        // Отпустили между 0,4 и 1,5 с — передумали, ничего не делаем.
    },

    ctaCancel() {
        this.stopCta();
    },

    stopCta() {
        if (this.ctaTimer !== null) {
            clearInterval(this.ctaTimer);
            this.ctaTimer = null;
        }
        this.holdW = 0;
        this.applyCta();
    },

    ctaTap() {
        const v = this.v;
        if (v === null) {
            return;
        }
        if (v.paused) {
            this.engine.togglePause();
        } else if (v.phase === 'set') {
            this.engine.finishSet();
        } else {
            this.engine.startSet(false);
        }
    },

    // ---------- панель ----------

    togglePause() {
        this.engine.togglePause();
        this.vPage = V_MAIN;
        this.paint();
    },

    markNew() {
        this.touched();
        this.engine.markNewExercise();
    },

    finishDown() {
        this.touched();
        this.stopFinish();
        const t0 = Date.now();
        this.platform.vibrate('tick');
        this.finishTimer = setInterval(() => {
            const f = Math.min(1, (Date.now() - t0) / HOLD_FINISH_MS);
            this.finishHold = f;
            this.paintRing(f);
            if (f >= 1) {
                this.stopFinish();
                this.engine.finish();
                this.goSummary();
            }
        }, 30);
    },

    finishUp() {
        this.stopFinish();
    },

    stopFinish() {
        if (this.finishTimer !== null) {
            clearInterval(this.finishTimer);
            this.finishTimer = null;
        }
        this.finishHold = 0;
        this.paintRing(0);
    },

    paintRing(f) {
        const cv = this.$refs.ring;
        if (cv) {
            drawHoldRing(cv.getContext('2d', { antialias: true }), f);
        }
    },

    goSummary() {
        if (this.leaving) {
            return;
        }
        this.leaving = true;
        router.replace({ uri: 'pages/summary/summary' });
    }
};
