import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const USER_GRANT: Permissions[] = ['ohos.permission.READ_HEALTH_DATA'];

/** Запрос user_grant-разрешений (пульс). Возвращает true, если всё выдано. */
export async function requestRuntimePermissions(ctx: common.UIAbilityContext): Promise<boolean> {
  try {
    const atManager = abilityAccessCtrl.createAtManager();
    const res = await atManager.requestPermissionsFromUser(ctx, USER_GRANT);
    return res.authResults.every((r: number) => r === 0);
  } catch (e) {
    const err = e as BusinessError;
    hilog.error(0x0001, 'IronPulse.Perm', `request failed: ${err.code} ${err.message}`);
    return false;
  }
}
