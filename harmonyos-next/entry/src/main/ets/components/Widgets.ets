import { Colors, Sizes } from '../common/Theme';
import { Haptics } from '../service/Haptics';

/** Крупная кнопка-«пилюля» (мин. высота 48 vp). */
@Component
export struct PillButton {
  @Prop label: string = '';
  @Prop color: string = Colors.SET;
  @Prop textColor: string = Colors.ON_ACCENT;
  @Prop btnWidth: string = '70%';
  onTap: () => void = () => {
  };

  build() {
    Button(this.label, { type: ButtonType.Capsule, stateEffect: true })
      .width(this.btnWidth)
      .height(Sizes.BUTTON_H)
      .fontSize(17)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.textColor)
      .backgroundColor(this.color)
      .onClick(() => {
        Haptics.tap();
        this.onTap();
      })
  }
}

/** Круглая кнопка ± для инлайн-корректировки. */
@Component
export struct RoundButton {
  @Prop label: string = '';
  @Prop color: string = Colors.SURFACE_2;
  @Prop textColor: string = Colors.TEXT;
  onTap: () => void = () => {
  };

  build() {
    Button(this.label, { type: ButtonType.Circle, stateEffect: true })
      .width(Sizes.SMALL_BTN)
      .height(Sizes.SMALL_BTN)
      .fontSize(15)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.textColor)
      .backgroundColor(this.color)
      .onClick(() => {
        Haptics.tick();
        this.onTap();
      })
  }
}

/**
 * Кнопка подтверждения долгим удержанием (защита от случайного нажатия).
 * Заполняется по кругу в течение holdMs, затем вызывает onConfirm.
 */
@Component
export struct HoldButton {
  @Prop label: string = '';
  @Prop color: string = Colors.DANGER;
  @Prop holdMs: number = 1200;
  @State private progress: number = 0;
  private timerId: number = -1;
  private startTs: number = 0;
  onConfirm: () => void = () => {
  };

  private begin(): void {
    this.cancel();
    this.startTs = Date.now();
    Haptics.tick();
    this.timerId = setInterval(() => {
      this.progress = Math.min(100, (Date.now() - this.startTs) * 100 / this.holdMs);
      if (this.progress >= 100) {
        this.cancel();
        Haptics.tap();
        this.onConfirm();
      }
    }, 30);
  }

  private cancel(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.progress = 0;
  }

  aboutToDisappear(): void {
    this.cancel();
  }

  build() {
    Stack() {
      Progress({ value: this.progress, total: 100, type: ProgressType.Capsule })
        .width('100%')
        .height('100%')
        .color(this.color)
        .backgroundColor(Colors.SURFACE_2)
        .style({ borderWidth: 0 })
      Text(this.progress > 0 ? 'Удерживайте…' : this.label)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Colors.TEXT)
    }
    .width('78%')
    .height(Sizes.BUTTON_H)
    .borderRadius(Sizes.BUTTON_H / 2)
    .clip(true)
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.begin();
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.cancel();
      }
    })
  }
}

/** Ячейка статистики «значение / подпись». */
@Component
export struct StatCell {
  @Prop value: string = '';
  @Prop caption: string = '';
  @Prop valueColor: string = Colors.TEXT;

  build() {
    Column() {
      Text(this.value).fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.valueColor)
        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.caption).fontSize(11).fontColor(Colors.MUTED).margin({ top: 1 })
    }
    .alignItems(HorizontalAlign.Center)
    .layoutWeight(1)
  }
}
