# IronPulse v2 — Product spec

Platform: Huawei Watch 4 Pro, HarmonyOS 3 (API 8, JS FA model), 466×466 round AMOLED.
Project: `api8/`. Russian original: [SPEC.ru.md](SPEC.ru.md).

## 1. Concept

A minimal strength-training timer: **total workout clock + heart rate + a set ↔ rest loop**.
No exercise library, weights or reps. No history is stored — statistics are collected during
the workout and discarded after the summary screen.

Principles:
- one primary action per screen — a large button at the bottom you can hit without looking;
- colour = state: amber — set, ice blue — rest, green — warm-up / ready;
- AMOLED-first: true black background, only digits, arcs and the button glow;
- behaves like the stock Huawei *Workout* app: it can't be dismissed by accident, and raising the
  wrist always shows IronPulse, never the watch face.

## 2. Screens and flow

```
Menu ──Start──▶ Ready ──Start set──▶ Set ──Finish set──▶ Rest
                  ▲                    ▲                   │
                  │                    └──── Start set ────┘
        swipe down from any workout state ▼
                  Panel: Pause / New exercise / Finish (hold) ──▶ Summary ──Done──▶ Menu
```

| # | Screen | Content | Primary action |
|---|---|---|---|
| 1 | **Menu** | Clock, logo, live heart rate, large round **Start** button, settings | Start → 2 |
| 2 | **Ready** | Clock, total timer `HH:MM:SS`, heart rate, zone, kcal, HR arc | **Start set** |
| 3 | **Set** | Clock, total timer, HR and kcal; *EX 2 · SET 3* chip; large count-up **set timer**; HR arc | **Finish set** |
| 4 | **Rest** | Clock, total timer, HR and kcal; large count-up **rest timer**; ring up to signal 2 with a mark at signal 1; next-signal chip; HR drop | **Start set** |
| 5 | **Panel** (swipe down) | Pause / Resume, **New exercise**, **Finish** (hold 1.5 s) | — |
| 6 | **Summary** | Duration, sets · exercises, kcal, avg / max HR, time-in-zone ring. **Swipe up — details:** sets × average set time per exercise (up to 4 rows, the rest folded into “N more”), average set, average rest, average HR drop during rest, time in each zone | **Done** → menu, stats reset |
| 7 | **Settings** | Profile: weight, age, sex (for calories); rest signals 1 and 2 (30 s steps); vibration on/off | — |

First launch: a short profile (weight / age / sex) → menu.

### Exercises (groups of sets)
- Tap **Start set** — next set of the same exercise.
- **Hold Start set for 1.5 s** — new exercise: the set counter resets to 1, the exercise number increments.
  While holding, the button fills with amber left to right and reads *New exercise*; at 1.5 s the watch
  vibrates and **set 1 of the new exercise** starts. A tap shorter than 0.4 s is a normal set;
  releasing between 0.4 and 1.5 s cancels.
- The same from the panel: **New exercise** marks the next set as the first one of a new exercise
  (tap again to undo).
- Screens show *EX 2 · SET 3*; the summary shows *8 sets · 2 ex*.

### Rest timer — counts up, no target
- Counts up from 0:00; a set never starts by itself.
- Two signals, set in Settings (defaults **3:00** and **5:00**, 30 s steps, signal 1 always at least 30 s
  before signal 2; changing one pushes the other). Values are fixed per rest, so editing settings mid-rest
  affects the next rest.
- Haptics: **signal 1 — one short pulse (220 ms)**, **signal 2 — two short pulses (2 × 180 ms)**. Nothing after that.
- The rest ring fills up to signal 2 with a mark at signal 1; after signal 2 ring and timer turn amber
  (*past 5:00*).

## 3. Heart rate and zones

- Heart-rate sensor at 1 Hz; no data for > 5 s or the watch is off the wrist → `- -`.
- Zones: `< 110` recovery (green), `110–145` working (amber), `> 145` peak (red).
- The arc along the top and sides: length = heart rate (50–190 bpm), gradient green → amber → red.

## 4. Statistics (collected, not stored)

Kept in memory plus a crash cache; reset after **Done** on the summary.

- **Workout:** start / end, duration, paused time, kcal, avg / max HR, time in each zone.
- **Each set:** exercise number, set number within it, start, duration, avg / max HR.
- **Each rest:** start, duration, HR at start and end (recovery), number of signals reached.
- **Aggregates:** exercises, sets, total work time and rest time, average set / rest duration.

- **Details screen:** per exercise (consecutive sets with the same number) — sets and average set time;
  HR drop = average of `hrStart − hrEnd` over rests that have HR at both ends.

Calories: Keytel et al. (2005) from heart rate, weight, age and sex; MET-based fallback without HR.

### Language
Russian or English, from the watch system locale (`@system.configuration.getLocale()`): `ru*` → Russian,
anything else → English. Strings live in `common/i18n.js`; each page calls `useLang()` in `onInit`
because every FA page is a separate bundle with its own copy of the module.

## 5. Behaving like the stock Workout app (verified on the watch)

| Requirement | Solution | Status |
|---|---|---|
| Raising the wrist shows IronPulse | While the app is in the foreground the system wakes into it | ✅ |
| Timers never lose time | Wall-clock accounting with catch-up on wake | ✅ |
| Screen during a workout | Huawei freezes third-party apps while the display is off (and proxies `runningLock`), then shows the watch face instead. So **the screen stays on for the whole workout**: after 8 s without touches it switches to a near-black **dim mode** (clock, phase label and timer at exactly the same positions as on the normal screen); a tap or **raising the wrist** brings the full UI back, **lowering the wrist** dims it right away (accelerometer, `common/wrist.js`; while the wrist stays raised the timeout is 20 s); phase changes and the rest signals also wake it. After **Done** the display sleeps normally again | ✅ |
| Can't be dismissed by swipe-right or Back | A custom Android shell activity (`entry/shell/MainAbilityShellActivity.java`, injected by a hook in `entry/hvigorfile.ts`): while `files/session.json` exists (from **Start** to **Done**) `onBackPressed`, `onWindowDismissed` and `finish` are ignored | ✅ |
| Crown button (Home) | A system key that apps can't intercept; bringing the window back from the background is blocked by Android (`Background activity start`). The workout keeps running and resumes where it was | ⚠️ platform limit |
| Black screen instead of AOD | Third-party apps can't provide their own AOD; disable AOD in watch settings if needed | — |

## 6. Visual style (“Ember Pulse”)

- Background `#000` with a radial glow tinted by phase; arcs, rings and glows drawn on `<canvas>` with
  antialiasing. Soft glows are layered translucent strokes (no `shadowBlur`, no CSS `box-shadow` on the watch).
- Numbers: Barlow Condensed (bundled, OFL). Set / rest timers 124 px, clock 36 px, total timer 32 px.
- Primary button: 270 × 80 capsule with a vertical gradient in the phase colour.
- Heart-rate arc: 280° along the top and sides, gap at the bottom for the button.
- Rest ring: inside the HR arc, ice blue, scale up to signal 2, mark at signal 1, amber after signal 2.
- Palette: text `#FFF`, captions `#90A4AE`, set `#FFC94D → #FF8F00`, rest `#4FC3F7 → #1E88E5`,
  zones `#00E676 / #FFC400 / #FF3D00`.

## 7. Out of scope for v2

Exercise library, weights, reps, templates, history, phone sync.
