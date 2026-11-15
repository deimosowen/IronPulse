// Юнит-тесты логики IronPulse v2. Запуск: node --test test   (из папки api8)
// common/*.js — ES-модули без package.json; копируем во временную папку с "type":"module".
import { test, beforeEach } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const srcDir = path.join(here, '..', 'entry', 'src', 'main', 'js', 'MainAbility', 'common');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'ironpulse-'));
for (const f of fs.readdirSync(srcDir)) {
  if (f.endsWith('.js')) {
    fs.copyFileSync(path.join(srcDir, f), path.join(tmp, f));
  }
}
fs.writeFileSync(path.join(tmp, 'package.json'), '{"type":"module"}');
const load = (f) => import(pathToFileURL(path.join(tmp, f)).href);

const fmt = await load('format.js');
const theme = await load('theme.js');
const cal = await load('calories.js');
const E = await load('engine.js');

let clock;
let timers;
let hr;
let vibes;
let saved;
let restAlarm;

function advance(ms) {
  const target = clock + ms;
  for (;;) {
    timers.sort((a, b) => a.at - b.at);
    const t = timers[0];
    if (!t || t.at > target) {
      break;
    }
    timers.shift();
    clock = t.at;
    t.fn();
  }
  clock = target;
}

beforeEach(() => {
  clock = 1_700_000_000_000;
  timers = [];
  hr = 0;
  vibes = [];
  saved = null;
  restAlarm = null;
  let nextId = 1;
  E._resetForTests();
  E.configure({
    now: () => clock,
    heartRate: () => hr,
    vibrate: (k) => vibes.push(k),
    saveSession: (s) => { saved = JSON.parse(JSON.stringify(s)); },
    clearSession: () => { saved = null; },
    setTimeout: (fn, ms) => { const id = nextId++; timers.push({ id, at: clock + ms, fn }); return id; },
    clearTimeout: (id) => { timers = timers.filter((t) => t.id !== id); },
    onActiveChange: () => {},
    onRestMark: (ms) => { restAlarm = ms; }
  });
  E.setProfile({ weightKg: 80, age: 30, sex: 'male', vibration: true, configured: true });
});

// ---------- Вспомогательное ----------
test('format', () => {
  assert.equal(fmt.formatHms(3723999), '01:02:03');
  assert.equal(fmt.formatClock(38_400), '0:38');
  assert.equal(fmt.formatClock(754_000), '12:34');
  assert.equal(fmt.formatClock(3_725_000), '1:02:05');
  assert.equal(fmt.formatClock(-5), '0:00');
  const w = (n) => fmt.plural(n, 'подход', 'подхода', 'подходов');
  assert.deepEqual([1, 2, 5, 11, 21, 22, 25].map(w), ['подход', 'подхода', 'подходов', 'подходов', 'подход', 'подхода', 'подходов']);
});

test('hr zones and gauge', () => {
  assert.equal(theme.zoneOf(0), -1);
  assert.equal(theme.zoneOf(109), 0);
  assert.equal(theme.zoneOf(110), 1);
  assert.equal(theme.zoneOf(145), 1);
  assert.equal(theme.zoneOf(146), 2);
  assert.equal(theme.hrFraction(50), 0);
  assert.equal(theme.hrFraction(190), 1);
  assert.equal(theme.hrFraction(0), 0);
});

test('calories', () => {
  const p = E.getProfile();
  assert.ok(Math.abs(cal.kcalPerMinute(0, p) - 7) < 1e-9);
  const keytel = (-55.0969 + 0.6309 * 130 + 0.1988 * 80 + 0.2017 * 30) / 4.184;
  assert.ok(Math.abs(cal.kcalPerMinute(130, p) - keytel) < 1e-9);
});

// ---------- Цикл подход ↔ отдых ----------
test('start → ready, no sets yet', () => {
  E.start();
  const v = E.view();
  assert.equal(v.phase, 'ready');
  assert.equal(v.totalSets, 0);
  assert.equal(v.nextExercise, 1);
  assert.equal(v.nextSet, 1);
});

test('set timer counts up, finish set → rest counts up', () => {
  E.start();
  advance(5_000);
  E.startSet();
  advance(38_000);
  let v = E.view();
  assert.equal(v.phase, 'set');
  assert.equal(v.phaseMs, 38_000);
  assert.equal(v.exercise, 1);
  assert.equal(v.setNumber, 1);
  E.finishSet();
  advance(12_000);
  v = E.view();
  assert.equal(v.phase, 'rest');
  assert.equal(v.phaseMs, 12_000);
  assert.equal(v.elapsedMs, 55_000);
  assert.equal(v.nextSet, 2);
});

test('hold → new exercise starts set 1; panel button marks next set as new', () => {
  E.start();
  E.startSet();
  E.finishSet();
  E.startSet();
  E.finishSet();
  E.startSet(true);
  let v = E.view();
  assert.equal(v.exercise, 2);
  assert.equal(v.setNumber, 1);
  E.finishSet();
  E.markNewExercise();
  v = E.view();
  assert.equal(v.pendingNewExercise, true);
  assert.equal(v.nextExercise, 3);
  assert.equal(v.nextSet, 1);
  E.markNewExercise();
  assert.equal(E.view().pendingNewExercise, false, 'second press cancels');
  E.markNewExercise();
  E.startSet();
  v = E.view();
  assert.equal(v.exercise, 3);
  assert.equal(v.setNumber, 1);
  assert.equal(v.totalSets, 4);
});

test('stats: per-set HR, rests, summary', () => {
  E.start();
  hr = 120;
  E.startSet();
  advance(30_000);
  hr = 150;
  advance(10_000);
  E.finishSet();
  hr = 140;
  advance(1_000);
  hr = 100;
  advance(59_000);
  E.startSet(true);
  advance(20_000);
  const s = E.finish();
  assert.equal(s.sets, 2);
  assert.equal(s.exercises, 2);
  assert.equal(s.workMs, 60_000);
  assert.equal(s.restMs, 60_000);
  assert.equal(s.avgSetMs, 30_000);
  assert.equal(s.hrMax, 150);
  assert.equal(saved.sets[0].hrAvg, 128);
  assert.equal(saved.sets[0].hrMax, 150);
  assert.equal(saved.rests[0].hrStart, 150, 'HR at the moment the set ended');
  assert.equal(saved.rests[0].hrEnd, 100);
  assert.equal(saved.rests[0].marks, 0);
  assert.ok(s.calories > 0);
});

test('close resets everything (no history)', () => {
  E.start();
  E.startSet();
  E.finish();
  E.close();
  assert.equal(E.isActive(), false);
  assert.equal(saved, null);
  assert.equal(E.view().active, false);
});

test('restore after restart; finished session goes to summary', () => {
  E.start();
  E.startSet();
  advance(20_000);
  E.finishSet();
  const cached = saved;
  E._resetForTests();
  clock += 5_000;
  assert.equal(E.restore(cached), true);
  const v = E.view();
  assert.equal(v.phase, 'rest');
  assert.equal(v.phaseMs, 5_000);
  assert.equal(v.totalSets, 1);
  E.finish();
  const fin = saved;
  E._resetForTests();
  assert.equal(E.restore(fin), true);
  assert.equal(E.pendingSummary().sets, 1);
  E._resetForTests();
  assert.equal(E.restore({ v: 2, exercises: [] }), false, 'older cache is ignored');
});

test('rest counts up with no target: 1 short at 3:00, 2 short at 5:00, then silence', () => {
  E.start();
  E.startSet();
  advance(30_000);
  E.finishSet();
  vibes = [];
  assert.equal(restAlarm, 180_000, 'platform armed for 3:00');
  advance(179_999);
  assert.deepEqual(vibes, []);
  assert.equal(E.view().restMarks, 0);
  advance(1);
  assert.deepEqual(vibes, ['short1']);
  assert.equal(E.view().restMarks, 1);
  assert.equal(restAlarm, 120_000, 'platform re-armed for 5:00');
  advance(120_000);
  assert.deepEqual(vibes, ['short1', 'short2']);
  assert.equal(restAlarm, -1);
  advance(600_000);
  assert.deepEqual(vibes, ['short1', 'short2'], 'nothing after 5:00');
  const v = E.view();
  assert.equal(v.phase, 'rest', 'never auto-starts a set');
  assert.equal(v.restProgress, 1);
  E.startSet();
  assert.equal(restAlarm, -1);
  E.finishSet();
  vibes = [];
  advance(180_000);
  assert.deepEqual(vibes, ['short1'], 'marks reset for the next rest');
});

test('pause freezes timers and disarms the mark alarm', () => {
  E.start();
  E.startSet();
  E.finishSet();
  advance(10_000);
  E.togglePause();
  assert.equal(restAlarm, -1);
  advance(60_000);
  let v = E.view();
  assert.equal(v.elapsedMs, 10_000);
  assert.equal(v.phaseMs, 10_000);
  E.togglePause();
  assert.equal(restAlarm, 170_000);
  advance(5_000);
  v = E.view();
  assert.equal(v.phaseMs, 15_000);
});

test('frozen process catches up; a stale mark stays silent', () => {
  E.start();
  E.startSet();
  E.finishSet();
  timers = [];
  clock += 182_000;      // проснулись через 2 с после 3:00 — сигнал ещё уместен
  vibes = [];
  E.tick();
  assert.deepEqual(vibes, ['short1']);
  timers = [];
  clock += 200_000;      // 6:22 — отметка 5:00 давно прошла
  E.tick();
  assert.deepEqual(vibes, ['short1'], 'stale 5:00 mark not buzzed');
  assert.equal(E.view().restMarks, 2);
});

test('vibration off silences engine', () => {
  E.setProfile({ vibration: false });
  E.start();
  E.startSet();
  E.finishSet();
  advance(400_000);
  assert.deepEqual(vibes, []);
});

test('rest marks come from the profile; ring scale follows the second mark', () => {
  E.setProfile({ restMark1Sec: 90, restMark2Sec: 150 });
  E.start();
  E.startSet();
  E.finishSet();
  vibes = [];
  assert.equal(restAlarm, 90_000);
  let v = E.view();
  assert.equal(v.restLastMarkMs, 150_000);
  assert.equal(v.restMarkFrac, 0.6);
  advance(75_000);
  assert.equal(E.view().restProgress, 0.5);
  advance(15_000);
  assert.deepEqual(vibes, ['short1']);
  // смена настроек во время отдыха не сдвигает текущие отметки
  E.setProfile({ restMark1Sec: 300, restMark2Sec: 600 });
  advance(60_000);
  assert.deepEqual(vibes, ['short1', 'short2']);
  // а в следующем отдыхе — уже новые
  E.startSet();
  E.finishSet();
  assert.equal(restAlarm, 300_000);
  // некорректные значения нормализуются
  assert.deepEqual(E.markMsFromProfile({ restMark1Sec: 10, restMark2Sec: 20 }), [30_000, 60_000]);
});

test('summary details: per exercise, avg rest, HR recovery', () => {
  E.start();
  hr = 140;
  E.startSet();
  advance(30_000);
  E.finishSet();
  hr = 100;
  advance(60_000);
  E.startSet();
  advance(50_000);
  hr = 150;
  E.finishSet();
  hr = 120;
  advance(120_000);
  E.startSet(true);
  advance(20_000);
  const s = E.finish();
  assert.equal(s.perExercise.length, 2);
  assert.deepEqual(s.perExercise.map((e) => [e.exercise, e.sets, e.avgSetMs]), [[1, 2, 40_000], [2, 1, 20_000]]);
  assert.equal(s.rests, 2);
  assert.equal(s.avgRestMs, 90_000);
  assert.equal(s.avgRecovery, 35, '(140-100 + 150-120) / 2');
});

test('i18n: ru/en picked from locale, plural forms', async () => {
  const I = await load('i18n.js');
  I.useLang('ru-RU');
  assert.equal(I.t('startSet'), 'Начать подход');
  assert.deepEqual([1, 3, 5, 11, 21].map((n) => I.tp('sets', n)), ['подход', 'подхода', 'подходов', 'подходов', 'подход']);
  I.useLang('en');
  assert.equal(I.t('startSet'), 'Start set');
  assert.deepEqual([1, 2, 0].map((n) => I.tp('sets', n)), ['set', 'sets', 'sets']);
  I.useLang('de');
  assert.equal(I.getLang(), 'en', 'anything but Russian → English');
  const ru = Object.keys((I.useLang('ru'), I.strings())).sort();
  const en = Object.keys((I.useLang('en'), I.strings())).sort();
  assert.deepEqual(en, ru, 'both dictionaries have the same keys');
});

test('wrist: raise and lower are detected with hold time, jerks are ignored', async () => {
  const { createWrist, G } = await load('wrist.js');
  const w = createWrist(1);
  const feed = (x, y, z, from, to) => {
    const ev = [];
    for (let t = from; t <= to; t += 60) {
      const e = w.feed(x, y, z, t);
      if (e !== null) {
        ev.push(e);
      }
    }
    return ev;
  };
  // рука опущена: сила тяжести вдоль руки
  assert.deepEqual(feed(G, 0, 0.5, 0, 1000), ['lower']);
  // рывок во время подхода — ничего
  assert.deepEqual(feed(0, 0, 2.5 * G, 1060, 1600), []);
  // поднял посмотреть
  assert.deepEqual(feed(0.3 * G, 0.2 * G, 0.9 * G, 1660, 2500), ['raise']);
  assert.equal(w.state(), 'up');
  // короткий наклон меньше времени удержания — без события
  assert.deepEqual(feed(G, 0, 0, 2560, 2800), []);
  assert.deepEqual(feed(0.3 * G, 0.2 * G, 0.9 * G, 2860, 3200), []);
  // перевёрнутый знак: экран вверх даёт z < 0
  const m = createWrist(-1);
  let ev = null;
  for (let t = 0; t < 600 && ev === null; t += 60) {
    ev = m.feed(0, 0, -G, t);
  }
  assert.equal(ev, 'raise');
});
