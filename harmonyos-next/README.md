# IronPulse — HarmonyOS 5+ prototype (ArkTS, API 18)

The first concept of IronPulse, written for HarmonyOS NEXT / HarmonyOS 5+ wearables with ArkTS and
the Stage model: exercises with weights and reps, inline editing of the last set during rest, history
in RelationalStore, Digital Crown input.

**Not maintained.** The target device (Huawei Watch 4 Pro) turned out to run HarmonyOS 3 (API 8),
so the app was rebuilt as a JS FA project in [`../api8`](../api8) with a different, simpler concept
(set ↔ rest timer). This folder is kept for reference and for future HarmonyOS 5+ watches.

## Build

DevEco Studio 5.1+ with HarmonyOS SDK API 18:

```bash
export JAVA_HOME="<DevEco>/jbr" DEVECO_SDK_HOME="<DevEco>/sdk"
hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon
hvigorw test -p module=entry@default -p product=default --no-daemon
```

## Structure

```
entry/src/main/ets/
├─ entryability/   EntryAbility — storage init, catch-up on foreground
├─ service/        WorkoutEngine, HeartRateService, Haptics, BackgroundRunner, Calories
├─ data/           Preferences (profile, last weights, session cache), RDB history
├─ components/     HeartRateRing (Gauge), ValueEditor, Crown accumulator, widgets
└─ pages/          Index, Workout, Summary, History, Settings
```
