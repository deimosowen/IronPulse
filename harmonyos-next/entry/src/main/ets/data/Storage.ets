import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { LastWeight, Profile, WorkoutSession } from '../model/Types';

const TAG = 'IronPulse.Storage';
const PREF_NAME = 'ironpulse';
const KEY_PROFILE = 'profile';
const KEY_LAST_WEIGHTS = 'lastWeights';
const KEY_ACTIVE = 'activeSession';

export function defaultProfile(): Profile {
  const p: Profile = {
    weightKg: 80,
    age: 30,
    sex: 'male',
    defaultRestSec: 90,
    vibration: true,
    configured: false
  };
  return p;
}

/**
 * Лёгкое key-value хранилище (Preferences): профиль, последние веса,
 * кэш активной сессии для автовосстановления.
 */
export class Storage {
  private static prefs: preferences.Preferences | null = null;
  private static ctx: common.UIAbilityContext | null = null;

  static init(ctx: common.UIAbilityContext): void {
    Storage.ctx = ctx;
    if (Storage.prefs === null) {
      Storage.prefs = preferences.getPreferencesSync(ctx, { name: PREF_NAME });
    }
  }

  static context(): common.UIAbilityContext {
    return Storage.ctx as common.UIAbilityContext;
  }

  private static getStr(key: string): string {
    if (Storage.prefs === null) {
      return '';
    }
    return Storage.prefs.getSync(key, '') as string;
  }

  private static putStr(key: string, value: string): void {
    if (Storage.prefs === null) {
      return;
    }
    Storage.prefs.putSync(key, value);
    Storage.prefs.flush().catch((e: Error) => hilog.error(0x0001, TAG, `flush: ${e.message}`));
  }

  // ---------- Профиль ----------
  static loadProfile(): Profile {
    const s = Storage.getStr(KEY_PROFILE);
    if (s.length === 0) {
      return defaultProfile();
    }
    try {
      return JSON.parse(s) as Profile;
    } catch (e) {
      return defaultProfile();
    }
  }

  static saveProfile(p: Profile): void {
    Storage.putStr(KEY_PROFILE, JSON.stringify(p));
  }

  // ---------- Последние рабочие веса ----------
  static loadLastWeights(): Record<string, LastWeight> {
    const s = Storage.getStr(KEY_LAST_WEIGHTS);
    if (s.length === 0) {
      const empty: Record<string, LastWeight> = {};
      return empty;
    }
    try {
      return JSON.parse(s) as Record<string, LastWeight>;
    } catch (e) {
      const empty: Record<string, LastWeight> = {};
      return empty;
    }
  }

  static lastWeight(exerciseId: string): LastWeight | undefined {
    const all = Storage.loadLastWeights();
    return all[exerciseId];
  }

  static saveLastWeights(map: Record<string, LastWeight>): void {
    Storage.putStr(KEY_LAST_WEIGHTS, JSON.stringify(map));
  }

  // ---------- Кэш активной сессии ----------
  static loadActiveSession(): WorkoutSession | null {
    const s = Storage.getStr(KEY_ACTIVE);
    if (s.length === 0) {
      return null;
    }
    try {
      return JSON.parse(s) as WorkoutSession;
    } catch (e) {
      return null;
    }
  }

  static saveActiveSession(session: WorkoutSession): void {
    Storage.putStr(KEY_ACTIVE, JSON.stringify(session));
  }

  static clearActiveSession(): void {
    if (Storage.prefs === null) {
      return;
    }
    Storage.prefs.deleteSync(KEY_ACTIVE);
    Storage.prefs.flush().catch((e: Error) => hilog.error(0x0001, TAG, `flush: ${e.message}`));
  }
}
