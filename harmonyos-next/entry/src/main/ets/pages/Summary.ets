import { Colors, Sizes } from '../common/Theme';
import { formatHms, formatMinutes, formatTonnage, formatWeight } from '../common/Format';
import { BestSet, WorkoutSummary } from '../model/Types';
import { findTemplate } from '../model/Exercises';
import { WorkoutEngine } from '../service/WorkoutEngine';
import { HistoryStore } from '../data/HistoryStore';
import { HoldButton, PillButton, StatCell } from '../components/Widgets';

/** Параметры при открытии из истории. */
export interface SummaryParams {
  summary: WorkoutSummary;
}

interface ZoneRow {
  name: string;
  color: string;
  ms: number;
}

/**
 * Экран 5: итоги тренировки (вертикальная прокрутка карточек).
 * Открывается после «Завершить» (с кнопкой «Сохранить и закрыть») или из истории.
 */
@Entry
@Component
struct Summary {
  @State data: WorkoutSummary | null = null;
  @State fromHistory: boolean = false;
  @State saving: boolean = false;
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    const params = this.getUIContext().getRouter().getParams() as SummaryParams | undefined;
    if (params !== undefined && params !== null && params.summary !== undefined) {
      this.data = params.summary;
      this.fromHistory = true;
    } else {
      this.data = WorkoutEngine.pendingSummary();
    }
  }

  /** Несохранённые итоги нельзя потерять кнопкой «назад». */
  onBackPress(): boolean {
    return !this.fromHistory;
  }

  private async saveAndClose(): Promise<void> {
    if (this.saving) {
      return;
    }
    this.saving = true;
    try {
      await WorkoutEngine.saveAndClose();
    } finally {
      this.saving = false;
    }
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' });
  }

  private async remove(): Promise<void> {
    if (this.data !== null) {
      await HistoryStore.remove(this.data.id);
    }
    this.getUIContext().getRouter().back();
  }

  private zones(d: WorkoutSummary): ZoneRow[] {
    const rows: ZoneRow[] = [
      { name: '> 145', color: Colors.ZONE_HIGH, ms: d.zoneMs[2] },
      { name: '110–145', color: Colors.ZONE_MID, ms: d.zoneMs[1] },
      { name: '< 110', color: Colors.ZONE_LOW, ms: d.zoneMs[0] }
    ];
    return rows;
  }

  private zoneTotal(d: WorkoutSummary): number {
    return Math.max(1, d.zoneMs[0] + d.zoneMs[1] + d.zoneMs[2]);
  }

  @Styles
  cardStyle() {
    .width('100%')
    .padding(12)
    .borderRadius(Sizes.RADIUS)
    .backgroundColor(Colors.SURFACE)
  }

  @Builder
  mainCard(d: WorkoutSummary) {
    Column({ space: 10 }) {
      Row() {
        StatCell({ value: formatHms(d.durationMs), caption: 'время' })
      }
      Row() {
        StatCell({ value: formatTonnage(d.tonnage), caption: 'тоннаж, кг', valueColor: Colors.SET })
        StatCell({ value: `${d.setsCount}`, caption: 'подходов' })
      }
      .width('100%')
      Row() {
        StatCell({ value: `${d.calories}`, caption: 'ккал' })
      }
    }
    .width('100%')
  }

  @Builder
  hrCard(d: WorkoutSummary) {
    Column({ space: 6 }) {
      Row() {
        StatCell({ value: d.hrAvg > 0 ? `${d.hrAvg}` : '--', caption: 'средний' })
        StatCell({ value: d.hrMax > 0 ? `${d.hrMax}` : '--', caption: 'макс', valueColor: Colors.ZONE_HIGH })
      }
      .width('100%')
      ForEach(this.zones(d), (z: ZoneRow) => {
        Column({ space: 2 }) {
          Row() {
            Text(z.name).fontSize(11).fontColor(Colors.MUTED).layoutWeight(1)
            Text(`${formatMinutes(z.ms)} • ${Math.round(z.ms * 100 / this.zoneTotal(d))}%`)
              .fontSize(11).fontColor(Colors.TEXT)
          }
          .width('100%')
          Progress({ value: z.ms, total: this.zoneTotal(d), type: ProgressType.Linear })
            .width('100%').height(5).color(z.color).backgroundColor(Colors.SURFACE_2)
        }
        .width('100%')
      }, (z: ZoneRow) => z.name)
    }
    .width('100%')
  }

  @Builder
  exercisesCard(d: WorkoutSummary) {
    Column({ space: 8 }) {
      if (d.exercises.length === 0) {
        Text('Подходов не было').fontSize(13).fontColor(Colors.MUTED)
      }
      ForEach(d.exercises, (e: BestSet, i: number) => {
        Column() {
          Text(e.name).fontSize(13).fontColor(Colors.TEXT).maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${formatWeight(e.bestWeight)} кг × ${e.bestReps} • ${e.sets} подх.`)
            .fontSize(12).fontColor(Colors.SET)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }, (e: BestSet, i: number) => `${i}-${e.name}`)
    }
    .width('100%')
  }

  build() {
    Column() {
      if (this.data !== null) {
        List({ space: 10, scroller: this.scroller }) {
          ListItem() {
            Column() {
              Text('Итоги').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT)
              Text(findTemplate((this.data as WorkoutSummary).templateId).name)
                .fontSize(11).fontColor(Colors.MUTED)
            }
            .width('100%')
          }
          ListItem() {
            Column({ space: 8 }) {
              Text('Главное').fontSize(12).fontColor(Colors.SET).fontWeight(FontWeight.Medium)
              this.mainCard(this.data as WorkoutSummary)
            }
            .cardStyle()
          }
          ListItem() {
            Column({ space: 8 }) {
              Text('Пульс и нагрузка').fontSize(12).fontColor(Colors.ZONE_HIGH).fontWeight(FontWeight.Medium)
              this.hrCard(this.data as WorkoutSummary)
            }
            .cardStyle()
          }
          ListItem() {
            Column({ space: 8 }) {
              Text('Упражнения').fontSize(12).fontColor(Colors.REST).fontWeight(FontWeight.Medium)
              this.exercisesCard(this.data as WorkoutSummary)
            }
            .cardStyle()
          }
          ListItem() {
            Column({ space: 8 }) {
              if (this.fromHistory) {
                PillButton({
                  label: 'Закрыть',
                  color: Colors.SURFACE_2,
                  textColor: Colors.TEXT,
                  btnWidth: '100%',
                  onTap: () => this.getUIContext().getRouter().back()
                })
                HoldButton({ label: 'Удалить', color: Colors.DANGER, onConfirm: () => {
                  this.remove();
                } })
              } else {
                PillButton({
                  label: this.saving ? 'Сохранение…' : 'Сохранить и закрыть',
                  color: Colors.SET,
                  btnWidth: '100%',
                  onTap: () => {
                    this.saveAndClose();
                  }
                })
              }
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('80%')
        .height('100%')
        .padding({ top: '16%', bottom: '22%' })
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .focusable(true)
        .defaultFocus(true)
        .onDigitalCrown((e: CrownEvent) => {
          this.scroller.scrollBy(0, e.degree * 1.5);
        })
      } else {
        Text('Нет данных').fontColor(Colors.MUTED)
          .onClick(() => this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' }))
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Colors.BG)
  }
}
