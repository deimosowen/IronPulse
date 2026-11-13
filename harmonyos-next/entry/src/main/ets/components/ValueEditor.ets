import { Colors, Sizes } from '../common/Theme';
import { formatWeight } from '../common/Format';
import { Haptics } from '../service/Haptics';

export type EditTarget = 'weight' | 'reps';

/**
 * Компактная строка инлайн-корректировки: [−] [80 кг] [×10] [+].
 * Тап по значению выбирает, что меняют кнопки ± и колесико Crown.
 */
@Component
export struct ValueEditor {
  @Prop weight: number = 0;
  @Prop reps: number = 0;
  @Prop step: number = 2.5;
  @Prop accent: string = Colors.REST;
  @Prop target: EditTarget = 'weight';
  onSelect: (t: EditTarget) => void = () => {
  };
  onAdjust: (t: EditTarget, steps: number) => void = () => {
  };

  @Builder
  chip(t: EditTarget, value: string, unit: string) {
    Row() {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.target === t ? this.accent : Colors.TEXT)
      Text(unit)
        .fontSize(11)
        .fontColor(Colors.MUTED)
        .margin({ left: 2, top: 6 })
    }
    .padding({ left: 6, right: 6 })
    .height(Sizes.SMALL_BTN)
    .borderRadius(10)
    .backgroundColor(this.target === t ? Colors.SURFACE_2 : Colors.BG)
    .onClick(() => {
      Haptics.tick();
      this.onSelect(t);
    })
  }

  private stepLabel(sign: string): string {
    return this.target === 'weight' ? `${sign}${formatWeight(this.step)}` : `${sign}1`;
  }

  build() {
    Row() {
      Button(this.stepLabel('−'), { type: ButtonType.Circle })
        .width(Sizes.SMALL_BTN).height(Sizes.SMALL_BTN)
        .fontSize(this.target === 'weight' ? 12 : 15).fontColor(Colors.TEXT)
        .backgroundColor(Colors.SURFACE_2)
        .onClick(() => {
          Haptics.tick();
          this.onAdjust(this.target, -1);
        })
      Row() {
        this.chip('weight', formatWeight(this.weight), 'кг')
        this.chip('reps', `×${this.reps}`, 'повт')
      }
      .margin({ left: 2, right: 2 })
      Button(this.stepLabel('+'), { type: ButtonType.Circle })
        .width(Sizes.SMALL_BTN).height(Sizes.SMALL_BTN)
        .fontSize(this.target === 'weight' ? 12 : 15).fontColor(Colors.ON_ACCENT)
        .backgroundColor(this.accent)
        .onClick(() => {
          Haptics.tick();
          this.onAdjust(this.target, 1);
        })
    }
    .justifyContent(FlexAlign.Center)
  }
}
