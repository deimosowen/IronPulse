# IronPulse — HarmonyOS 3 watch app (API 8, JS FA)

The working IronPulse app for Huawei Watch 4 Pro (HarmonyOS 3.x, `apiversion 8`, device type `wearable`, 466×466).
Spec: [docs/SPEC.md](docs/SPEC.md).

## Toolchain

| Component | Notes |
|---|---|
| DevEco Studio **3.1** | IDE, device manager, automatic debug signing. Its bundled `jbr` is used as `JAVA_HOME` |
| OpenHarmony SDK **API 8** (JS, Toolchains, Previewer) | Installed from DevEco 3.1 → Settings → SDK → HarmonyOS → 3.0.0 (API 8) |
| HarmonyOS **Toolchains API 8** (`3.1.1.4`) | Needed for the HarmonyOS shell APK. Not listed in DevEco 3.1 any more; the build expects it at `<hwsdk>/hmscore/3.0.0_8/toolchains` |
| Node.js **18** | Must live in a path **without spaces** (the SDK downloader doesn't quote it) |

`local.properties` (not committed):

```properties
sdk.dir=<SDK>/openharmony
hwsdk.dir=<SDK>
nodejs.dir=<Node.js 18>
```

## Build and test

```bash
cd api8
npm install                       # hvigor 2.4.2 + plugin (needs @ohos registry, see below)
export JAVA_HOME="<DevEco 3.1>/jbr"
export PATH="<Node.js 18>:$JAVA_HOME/bin:$PATH"
env 'npm_config_@ohos:registry=https://repo.harmonyos.com/npm/' \
  node node_modules/@ohos/hvigor/bin/hvigor.js --mode module -p module=entry@default -p product=default \
  assembleHap --no-daemon
node --test test                  # engine unit tests (pure JS, Node.js); also run by GitHub Actions
```

Output: `entry/build/default/outputs/default/entry-default-signed.hap` (or `-unsigned` without a signing config).

## Signing

Open `api8/` in DevEco Studio 3.1, sign in with a Huawei ID, connect the watch and use
**File → Project Structure → Signing Configs → Automatically generate signature**. DevEco writes the
signing config into `build-profile.json5` and the keys into `~/.ohos/config`.
The committed `build-profile.json5` intentionally has **no** signing config — never commit yours.

## Install on the watch

On the watch: **Settings → About → tap *Version* 7×**, then enable **HDC debugging** and
**Debug over Wi-Fi**. Use `hdc` from the HarmonyOS toolchains (it speaks the ADB-based protocol of
HarmonyOS 3 devices):

```bash
HDC=<hwsdk>/hmscore/3.0.0_8/toolchains/hdc.exe
$HDC tconn <watch-ip>:5555
$HDC app install -r entry/build/default/outputs/default/entry-default-signed.hap
$HDC shell "am start -n com.ironpulse.watch/.MainAbilityShellActivity"
$HDC shell "hilogcat -d" | grep IronPulse     # console.* output from JS lives in hilog, not logcat
```

(On Git Bash for Windows prefix commands with `MSYS_NO_PATHCONV=1` so device paths aren't rewritten.)

## Structure

```
entry/src/main/js/MainAbility/
├─ app.js                 shared engine + store (each FA page is a separate bundle)
├─ common/engine.js       workout core: phases, exercises, rest signals, statistics (pure JS, unit-tested)
├─ common/draw.js         canvas: phase glows, HR arc, rest ring, hold ring
├─ common/platform.js     heart rate, haptics, keep-screen-on, backup reminder
├─ common/store.js        profile + current-session cache (@system.file)
├─ common/i18n.js         Russian / English strings, picked from the watch locale
├─ common/icons, fonts    96 px PNG icons, Barlow Condensed (OFL)
└─ pages/                 index (menu) | workout | summary | settings
entry/shell/              custom Android shell activity (blocks dismissing during a workout)
entry/hvigorfile.ts       build hook that injects the shell activity
test/logic.test.mjs       engine tests
docs/SPEC.md              product spec
```

## Watch quirks worth knowing

- Horizontal swipe is the system *back / dismiss* gesture — all in-app navigation is vertical.
- With the display off the app is frozen and `runningLock` is proxied (`ProxyWLProcess`), so the
  workout keeps the screen on in a dim mode (see the spec, §5).
- No CSS `box-shadow`; canvas `shadowBlur` fills closed paths — glows are drawn as layered translucent strokes.
- `<text>` with `<span>` children renders only the spans — wrap all text in spans.
- In Barlow Condensed `--` merges into one bar; “no heart rate” is shown as `- -`.
- Accent CSS classes must come after base classes — later rules win.
- **Don't kill the app while it holds the heart-rate sensor** (`app install -r`, `am force-stop`): the
  watch's SensorService fails to clean up the dead client (`ProcessDeathObserver pid is -1`), the
  subscription leaks and the green HR LED stays on until the watch is rebooted. Close the app normally
  (finish the workout → *Done* → swipe out of the menu) before reinstalling.
- **Testing on the charger is misleading**: on a (wireless) charger the system's charging screen
  (`com.huawei.watch.charge`) pops over the app on wake and then falls back to the watch face, so the
  workout screen seems to "turn off". Off the charger the keep-screen-on flag works as intended.
