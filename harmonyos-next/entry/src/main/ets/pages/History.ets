import { Colors, Sizes } from '../common/Theme';
import { formatDate, formatMinutes, formatTonnage } from '../common/Format';
import { WorkoutSummary } from '../model/Types';
import { findTemplate } from '../model/Exercises';
import { HistoryStore } from '../data/HistoryStore';
import { Haptics } from '../service/Haptics';
import { SummaryParams } from './Summary';

/** История тренировок (из RelationalStore). */
@Entry
@Component
struct History {
  @State items: WorkoutSummary[] = [];
  @State loaded: boolean = false;
  private scroller: Scroller = new Scroller();

  onPageShow(): void {
    HistoryStore.list(100).then((list: WorkoutSummary[]) => {
      this.items = list;
      this.loaded = true;
    });
  }

  build() {
    Column() {
      List({ space: 8, scroller: this.scroller }) {
        ListItem() {
          Text('История').fontSize(16).fontWeight(FontWeight.Bold).fontColor(Colors.REST)
            .width('100%').textAlign(TextAlign.Center)
        }
        if (this.loaded && this.items.length === 0) {
          ListItem() {
            Text('Пока нет тренировок').fontSize(13).fontColor(Colors.MUTED)
              .width('100%').textAlign(TextAlign.Center).margin({ top: 20 })
          }
        }
        ForEach(this.items, (w: WorkoutSummary) => {
          ListItem() {
            Column({ space: 2 }) {
              Row() {
                Text(formatDate(w.startTs)).fontSize(12).fontColor(Colors.MUTED).layoutWeight(1)
                Text(formatMinutes(w.durationMs)).fontSize(12).fontColor(Colors.MUTED)
              }
              .width('100%')
              Text(findTemplate(w.templateId).name).fontSize(15).fontColor(Colors.TEXT).maxLines(1)
              Text(`${formatTonnage(w.tonnage)} кг • ${w.setsCount} подх. • ${w.calories} ккал`)
                .fontSize(12).fontColor(Colors.SET).maxLines(1)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(Sizes.RADIUS)
            .backgroundColor(Colors.SURFACE)
            .onClick(() => {
              Haptics.tap();
              const params: SummaryParams = { summary: w };
              this.getUIContext().getRouter().pushUrl({ url: 'pages/Summary', params: params });
            })
          }
        }, (w: WorkoutSummary) => w.id)
      }
      .width('80%')
      .height('100%')
      .padding({ top: '18%', bottom: '22%' })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .focusable(true)
      .defaultFocus(true)
      .onDigitalCrown((e: CrownEvent) => {
        this.scroller.scrollBy(0, e.degree * 1.5);
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }
}
