<p align="center">
  <img src="docs/screenshots/icon.png" width="120" alt="IronPulse icon">
</p>

<h1 align="center">IronPulse</h1>

<p align="center">
  A strength-training timer for Huawei smartwatches — set ↔ rest loop, live heart rate and zones,<br>
  a dim always-on workout screen and haptic rest signals. Built for the round 466×466 AMOLED of the Watch 4 Pro.
</p>

<p align="center">
  <a href="https://github.com/deimosowen/IronPulse/actions/workflows/test.yml"><img src="https://github.com/deimosowen/IronPulse/actions/workflows/test.yml/badge.svg" alt="tests"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT license"></a>
</p>

<table align="center">
  <tr>
    <td align="center"><img src="docs/screenshots/01-menu.png" width="190" alt="Menu"><br><sub>Menu</sub></td>
    <td align="center"><img src="docs/screenshots/02-ready.png" width="190" alt="Ready"><br><sub>Ready</sub></td>
    <td align="center"><img src="docs/screenshots/03-set.png" width="190" alt="Set"><br><sub>Set</sub></td>
    <td align="center"><img src="docs/screenshots/04-set-dim.png" width="190" alt="Set, dim mode"><br><sub>Set — dim mode</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/05-rest.png" width="190" alt="Rest"><br><sub>Rest</sub></td>
    <td align="center"><img src="docs/screenshots/06-rest-dim.png" width="190" alt="Rest, dim mode"><br><sub>Rest — dim mode</sub></td>
    <td align="center"><img src="docs/screenshots/07-rest-over-5min.png" width="190" alt="Rest over 5 minutes"><br><sub>Rest over 5 min</sub></td>
    <td align="center"><img src="docs/screenshots/08-panel.png" width="190" alt="Workout panel"><br><sub>Panel (swipe down)</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/screenshots/09-summary.png" width="190" alt="Summary"><br><sub>Summary</sub></td>
    <td align="center"><img src="docs/screenshots/11-summary-details.png" width="190" alt="Summary details"><br><sub>Summary details (swipe up)</sub></td>
    <td align="center"><img src="docs/screenshots/10-settings.png" width="190" alt="Settings"><br><sub>Settings</sub></td>
    <td align="center"><img src="docs/screenshots/12-settings-signals.png" width="190" alt="Rest signal settings"><br><sub>Rest signal settings</sub></td>
  </tr>
  <tr>
    <td></td>
    <td align="center"><img src="docs/screenshots/13-english-rest.png" width="190" alt="English UI, rest"><br><sub>English UI — rest</sub></td>
    <td align="center"><img src="docs/screenshots/14-english-summary.png" width="190" alt="English UI, summary"><br><sub>English UI — summary</sub></td>
    <td></td>
  </tr>
</table>

> Screenshots are taken from a real Huawei Watch 4 Pro. Most were shot off-wrist, hence no heart rate;
> the two summary screens come from a workout on the wrist.
> The UI follows the watch language: Russian, or English for any other locale.

## Why

The stock *Workout* app on Huawei watches treats strength training as a plain stopwatch with a heart-rate
readout. IronPulse focuses on the rhythm of a gym session: work, rest, repeat — with the information you
actually glance at between sets.

## Features

- **Set ↔ rest loop** — one big button: *Start set* → set timer → *Finish set* → rest timer → …
- **Exercises** — hold *Start set* for 1.5 s (or use the panel) to start a new exercise; screens show *EX 2 · SET 3*.
- **Rest signals** — counts up with no target; one short pulse at the first signal, two at the second
  (3:00 and 5:00 by default, adjustable in 30 s steps in Settings). The rest ring scales to the second signal.
- **Heart rate** — 1 Hz sensor, a gradient arc whose length is your HR and colour is your zone
  (`<110` recovery, `110–145` working, `>145` peak), plus calories (Keytel formula) next to it.
- **Always-on dim mode** — the screen never drops to the watch face during a workout; after 8 s it dims to
  near-black with the clock and timer in exactly the same place. Raise the wrist to wake it, lower it to dim
  (like the built-in workout app); a tap or a rest signal wakes it too.
- **Can't be dismissed by accident** — swipe-right and Back are blocked from *Start* until *Done*.
- **Crash-safe** — the session is cached; after an app or watch restart the workout resumes where it was.
- **Summary details** — swipe up on the summary: sets and average set time per exercise, average set and rest,
  average heart-rate drop during rest, time in each HR zone.
- **Russian and English** — picked from the watch system language.
- **No history by design** — statistics (per set, per rest, zones) are collected for the summary and then discarded.

## Repository layout

| Path | What |
|---|---|
| [`api8/`](api8/) | **The app.** HarmonyOS 3 / API 8, JS FA model (HML/CSS/JS) — runs on Watch 4 Pro |
| [`api8/docs/SPEC.md`](api8/docs/SPEC.md) | Product spec and platform findings ([Russian original](api8/docs/SPEC.ru.md)) |
| [`harmonyos-next/`](harmonyos-next/) | Early prototype for HarmonyOS 5+ (ArkTS, API 18) — first concept, not maintained |
| [`docs/screenshots/`](docs/screenshots/) | Screenshots from the device |

## Getting started

See [api8/README.md](api8/README.md) for the toolchain (DevEco Studio 3.1, HarmonyOS SDK API 8),
build, unit tests, signing and installing on the watch over Wi-Fi debugging.

## Platform notes (learned the hard way)

Huawei Watch 4 Pro runs HarmonyOS 3 on an AOSP base, so a few things behave differently from the docs:

- Third-party apps are frozen when the display is off and `runningLock` is proxied by the system —
  timers and vibrations stop until the screen wakes. IronPulse keeps the display on (dimmed) during a workout.
- `reminderAgent` notifications fire on time, but their vibration may be routed to the paired phone.
- Swipe-right is a window *swipe-to-dismiss* on the Android shell activity — blocked by a custom shell
  activity injected at build time. The crown (Home) can't be intercepted.
- CSS `box-shadow` is not supported, canvas `shadowBlur` fills closed shapes — glows are layered strokes.
- In `<text>` with `<span>` children only the spans are rendered.

## License

[MIT](LICENSE) © 2026 Denis Ushanev. Third-party components keep their own licenses — see [NOTICE](NOTICE) and below.

## Credits

- Font: [Barlow Condensed](https://github.com/jpt/barlow) — SIL Open Font License 1.1
  ([license](api8/entry/src/main/js/MainAbility/common/fonts/OFL.txt)).
- Icons: drawn after [Lucide](https://lucide.dev) outlines (ISC License).
