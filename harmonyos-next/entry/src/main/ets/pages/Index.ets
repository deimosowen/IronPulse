import { Colors, Sizes } from '../common/Theme';
import { TEMPLATES } from '../model/Exercises';
import { Template } from '../model/Types';
import { Storage } from '../data/Storage';
import { WorkoutEngine } from '../service/WorkoutEngine';
import { Haptics } from '../service/Haptics';
import { requestRuntimePermissions } from '../service/Permissions';

/**
 * Экран 1: быстрый старт, шаблоны, история и настройки (прокрутка вниз / колесико).
 */
@Entry
@Component
struct Index {
  @State starting: boolean = false;
  private checked: boolean = false;
  private scroller: Scroller = new Scroller();

  onPageShow(): void {
    if (this.checked) {
      return;
    }
    this.checked = true;
    const router = this.getUIContext().getRouter();
    // Автовосстановление прерванной тренировки (закрытие приложения / перезагрузка).
    if (WorkoutEngine.restore(Storage.context())) {
      const pending = WorkoutEngine.pendingSummary();
      router.replaceUrl({ url: pending !== null ? 'pages/Summary' : 'pages/Workout' });
      return;
    }
    // Первый запуск — заполнить профиль (вес/возраст нужны для калорий).
    if (!Storage.loadProfile().configured) {
      router.pushUrl({ url: 'pages/Settings' });
    }
  }

  private async start(templateId: string): Promise<void> {
    if (this.starting) {
      return;
    }
    this.starting = true;
    const ctx = Storage.context();
    await requestRuntimePermissions(ctx); // без разрешения работаем по MET-оценке
    WorkoutEngine.start(ctx, templateId);
    this.starting = false;
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/Workout' });
  }

  @Builder
  row(title: string, color: string, onTap: () => void) {
    Row() {
      Text(title).fontSize(16).fontColor(color).maxLines(1)
    }
    .width('100%')
    .height(Sizes.BUTTON_H)
    .justifyContent(FlexAlign.Center)
    .borderRadius(Sizes.BUTTON_H / 2)
    .backgroundColor(Colors.SURFACE)
    .onClick(() => {
      Haptics.tap();
      onTap();
    })
  }

  build() {
    Column() {
      List({ space: 8, scroller: this.scroller }) {
        ListItem() {
          Text('IronPulse')
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.SET)
            .width('100%').textAlign(TextAlign.Center)
        }

        ListItem() {
          Button(this.starting ? '…' : 'Начать тренировку', { type: ButtonType.Capsule })
            .width('100%')
            .height(60)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Colors.ON_ACCENT)
            .backgroundColor(Colors.SET)
            .onClick(() => {
              Haptics.tap();
              this.start('free');
            })
        }

        ListItem() {
          Text('Шаблоны').fontSize(12).fontColor(Colors.MUTED)
            .width('100%').textAlign(TextAlign.Center).margin({ top: 6 })
        }

        ForEach(TEMPLATES.filter((t: Template) => t.id !== 'free'), (t: Template) => {
          ListItem() {
            this.row(t.name, Colors.TEXT, () => {
              this.start(t.id);
            })
          }
        }, (t: Template) => t.id)

        ListItem() {
          Divider().color(Colors.SURFACE_2).margin({ top: 4, bottom: 4 })
        }

        ListItem() {
          this.row('История', Colors.REST, () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/History' });
          })
        }

        ListItem() {
          this.row('Настройки', Colors.MUTED, () => {
            this.getUIContext().getRouter().pushUrl({ url: 'pages/Settings' });
          })
        }
      }
      .width('78%')
      .height('100%')
      .padding({ top: '22%', bottom: '24%' })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .alignListItem(ListItemAlign.Center)
      .focusable(true)
      .defaultFocus(true)
      .onDigitalCrown((e: CrownEvent) => {
        this.scroller.scrollBy(0, e.degree * 1.5);
      })
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(Colors.BG)
  }
}
