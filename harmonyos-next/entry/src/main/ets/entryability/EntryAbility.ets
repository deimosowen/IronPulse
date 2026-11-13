import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Storage } from '../data/Storage';
import { HistoryStore } from '../data/HistoryStore';
import { WorkoutEngine } from '../service/WorkoutEngine';

const TAG = 'IronPulse.Ability';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    Storage.init(this.context);
    WorkoutEngine.reloadProfile();
    HistoryStore.init(this.context).catch((e: BusinessError) => {
      hilog.error(0x0001, TAG, `history init failed: ${e.code} ${e.message}`);
    });
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(0x0001, TAG, `loadContent failed: ${err.code} ${err.message}`);
        return;
      }
      try {
        const win = windowStage.getMainWindowSync();
        win.setWindowBackgroundColor('#000000');
      } catch (e) {
        hilog.warn(0x0001, TAG, 'window setup failed');
      }
    });
  }

  onForeground(): void {
    // Догоняем время, прошедшее, пока процесс мог быть заморожен.
    WorkoutEngine.tick();
  }

  onBackground(): void {
    // Тренировка продолжается в фоне (Continuous Task); состояние уже в кэше.
  }

  onDestroy(): void {
    hilog.info(0x0001, TAG, 'destroy');
  }
}
