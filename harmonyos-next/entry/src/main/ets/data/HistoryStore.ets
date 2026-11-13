import { common } from '@kit.AbilityKit';
import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { WorkoutSummary } from '../model/Types';

const TAG = 'IronPulse.History';
const TABLE = 'workouts';
const CREATE_SQL = `CREATE TABLE IF NOT EXISTS ${TABLE} (
  id TEXT PRIMARY KEY,
  start_ts INTEGER NOT NULL,
  duration_ms INTEGER NOT NULL,
  tonnage REAL NOT NULL,
  sets_count INTEGER NOT NULL,
  calories REAL NOT NULL,
  payload TEXT NOT NULL
)`;

/** История тренировок в RelationalStore (SQLite на часах). */
export class HistoryStore {
  private static store: relationalStore.RdbStore | null = null;

  static async init(ctx: common.UIAbilityContext): Promise<void> {
    if (HistoryStore.store !== null) {
      return;
    }
    const config: relationalStore.StoreConfig = {
      name: 'ironpulse.db',
      securityLevel: relationalStore.SecurityLevel.S1
    };
    HistoryStore.store = await relationalStore.getRdbStore(ctx, config);
    await HistoryStore.store.executeSql(CREATE_SQL);
  }

  static async save(s: WorkoutSummary): Promise<void> {
    if (HistoryStore.store === null) {
      hilog.error(0x0001, TAG, 'store not initialized');
      return;
    }
    const row: relationalStore.ValuesBucket = {
      'id': s.id,
      'start_ts': s.startTs,
      'duration_ms': s.durationMs,
      'tonnage': s.tonnage,
      'sets_count': s.setsCount,
      'calories': s.calories,
      'payload': JSON.stringify(s)
    };
    await HistoryStore.store.insert(TABLE, row, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);
  }

  static async list(limit: number): Promise<WorkoutSummary[]> {
    const out: WorkoutSummary[] = [];
    if (HistoryStore.store === null) {
      return out;
    }
    const pred = new relationalStore.RdbPredicates(TABLE);
    pred.orderByDesc('start_ts').limitAs(limit);
    const rs = await HistoryStore.store.query(pred, ['payload']);
    try {
      const col = rs.getColumnIndex('payload');
      while (rs.goToNextRow()) {
        try {
          out.push(JSON.parse(rs.getString(col)) as WorkoutSummary);
        } catch (e) {
          hilog.warn(0x0001, TAG, 'skip broken row');
        }
      }
    } finally {
      rs.close();
    }
    return out;
  }

  static async remove(id: string): Promise<void> {
    if (HistoryStore.store === null) {
      return;
    }
    const pred = new relationalStore.RdbPredicates(TABLE);
    pred.equalTo('id', id);
    await HistoryStore.store.delete(pred);
  }
}
