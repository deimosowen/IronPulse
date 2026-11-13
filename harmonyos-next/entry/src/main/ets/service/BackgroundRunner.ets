import { backgroundTaskManager, reminderAgentManager } from '@kit.BackgroundTasksKit';
import { common, wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'IronPulse.Bg';

/**
 * Тип непрерывной задачи. Должен совпадать с "backgroundModes" в module.json5.
 * ВНИМАНИЕ: перечень типов, разрешённых сторонним приложениям на часах, нужно
 * проверить на реальном Huawei Watch 4 Pro. Даже если задача будет отклонена,
 * таймеры не «теряют» время: учёт идёт по wall-clock (см. WorkoutEngine.tick).
 */
const CONTINUOUS_TASK_MODE = backgroundTaskManager.BackgroundMode.LOCATION;

/**
 * Фоновая работа во время тренировки:
 *  - непрерывная задача (Continuous Task), чтобы таймеры/пульс шли при погасшем экране;
 *  - резервное напоминание (reminderAgent) на конец отдыха — сработает, даже если
 *    процесс приостановлен системой.
 */
export class BackgroundRunner {
  private static active: boolean = false;
  private static restReminderId: number = -1;

  static async start(ctx: common.UIAbilityContext): Promise<void> {
    if (BackgroundRunner.active) {
      return;
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{ bundleName: ctx.abilityInfo.bundleName, abilityName: ctx.abilityInfo.name }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent: WantAgent = await wantAgent.getWantAgent(info);
      await backgroundTaskManager.startBackgroundRunning(ctx, CONTINUOUS_TASK_MODE, agent);
      BackgroundRunner.active = true;
      hilog.info(0x0001, TAG, 'continuous task started');
    } catch (e) {
      const err = e as BusinessError;
      hilog.error(0x0001, TAG, `continuous task failed: ${err.code} ${err.message}`);
    }
  }

  static async stop(ctx: common.UIAbilityContext): Promise<void> {
    BackgroundRunner.cancelRestReminder();
    if (!BackgroundRunner.active) {
      return;
    }
    try {
      await backgroundTaskManager.stopBackgroundRunning(ctx);
    } catch (e) {
      const err = e as BusinessError;
      hilog.warn(0x0001, TAG, `stop failed: ${err.code}`);
    }
    BackgroundRunner.active = false;
  }

  /** Резервный будильник конца отдыха (на случай, если процесс заморожен). */
  static scheduleRestReminder(seconds: number): void {
    BackgroundRunner.cancelRestReminder();
    if (seconds < 1) {
      return;
    }
    const req: reminderAgentManager.ReminderRequestTimer = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
      triggerTimeInSeconds: Math.ceil(seconds),
      title: 'IronPulse',
      content: 'Отдых окончен — следующий подход',
      ringDuration: 2
    };
    reminderAgentManager.publishReminder(req)
      .then((id: number) => {
        BackgroundRunner.restReminderId = id;
      })
      .catch((e: BusinessError) => hilog.warn(0x0001, TAG, `reminder failed: ${e.code}`));
  }

  static cancelRestReminder(): void {
    if (BackgroundRunner.restReminderId < 0) {
      return;
    }
    const id = BackgroundRunner.restReminderId;
    BackgroundRunner.restReminderId = -1;
    reminderAgentManager.cancelReminder(id)
      .catch((e: BusinessError) => hilog.warn(0x0001, TAG, `cancel reminder: ${e.code}`));
  }
}
