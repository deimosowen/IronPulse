import { Colors, Sizes } from '../common/Theme';
import { formatMs } from '../common/Format';
import { Profile } from '../model/Types';
import { Storage } from '../data/Storage';
import { Haptics } from '../service/Haptics';
import { WorkoutEngine } from '../service/WorkoutEngine';
import { CrownAccumulator } from '../components/Crown';

type Field = 'weight' | 'age' | 'rest';

/**
 * Настройки / профиль: вес и возраст (для калорий), пол, отдых по умолчанию, вибрация.
 * Выбранное поле (тап) регулируется кнопками ± или колесиком Crown.
 */
@Entry
@Component
struct Settings {
  @State p: Profile = Storage.loadProfile();
  @State field: Field = 'weight';
  private crown: CrownAccumulator = new CrownAccumulator(15);
  private scroller: Scroller = new Scroller();

  private change(f: Field, steps: number): void {
    const n: Profile = {
      weightKg: this.p.weightKg,
      age: this.p.age,
      sex: this.p.sex,
      defaultRestSec: this.p.defaultRestSec,
      vibration: this.p.vibration,
      configured: this.p.configured
    };
    if (f === 'weight') {
      n.weightKg = Math.min(250, Math.max(30, n.weightKg + steps));
    } else if (f === 'age') {
      n.age = Math.min(99, Math.max(12, n.age + steps));
    } else {
      n.defaultRestSec = Math.min(600, Math.max(15, n.defaultRestSec + steps * 15));
    }
    this.p = n;
  }

  private save(): void {
    const n: Profile = {
      weightKg: this.p.weightKg,
      age: this.p.age,
      sex: this.p.sex,
      defaultRestSec: this.p.defaultRestSec,
      vibration: this.p.vibration,
      configured: true
    };
    Storage.saveProfile(n);
    Haptics.enabled = n.vibration;
    WorkoutEngine.reloadProfile();
    Haptics.tap();
    this.getUIContext().getRouter().back();
  }

  @Builder
  stepper(f: Field, title: string, value: string) {
    Column({ space: 2 }) {
      Text(title).fontSize(11).fontColor(this.field === f ? Colors.SET : Colors.MUTED)
      Row() {
        Button('−', { type: ButtonType.Circle })
          .width(Sizes.SMALL_BTN).height(Sizes.SMALL_BTN).fontSize(18)
          .fontColor(Colors.TEXT).backgroundColor(Colors.SURFACE_2)
          .onClick(() => {
            Haptics.tick();
            this.field = f;
            this.change(f, -1);
          })
        Text(value)
          .fontSize(22).fontWeight(FontWeight.Bold)
          .fontColor(this.field === f ? Colors.SET : Colors.TEXT)
          .layoutWeight(1).textAlign(TextAlign.Center)
          .onClick(() => {
            this.field = f;
          })
        Button('+', { type: ButtonType.Circle })
          .width(Sizes.SMALL_BTN).height(Sizes.SMALL_BTN).fontSize(18)
          .fontColor(Colors.TEXT).backgroundColor(Colors.SURFACE_2)
          .onClick(() => {
            Haptics.tick();
            this.field = f;
            this.change(f, 1);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(8)
    .borderRadius(Sizes.RADIUS)
    .backgroundColor(Colors.SURFACE)
  }

  @Builder
  toggleRow(title: string, value: string, onTap: () => void) {
    Row() {
      Text(title).fontSize(14).fontColor(Colors.TEXT).layoutWeight(1)
      Text(value).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Colors.SET)
    }
    .width('100%')
    .height(Sizes.BUTTON_H)
    .padding({ left: 14, right: 14 })
    .borderRadius(Sizes.RADIUS)
    .backgroundColor(Colors.SURFACE)
    .onClick(() => {
      Haptics.tick();
      onTap();
    })
  }

  build() {
    Column() {
      List({ space: 8, scroller: this.scroller }) {
        ListItem() {
          Column() {
            Text(this.p.configured ? 'Настройки' : 'Профиль')
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(Colors.TEXT)
            if (!this.p.configured) {
              Text('нужен для расчёта калорий').fontSize(11).fontColor(Colors.MUTED)
            }
          }
          .width('100%')
        }
        ListItem() {
          this.stepper('weight', 'Ваш вес, кг', `${this.p.weightKg}`)
        }
        ListItem() {
          this.stepper('age', 'Возраст', `${this.p.age}`)
        }
        ListItem() {
          this.toggleRow('Пол', this.p.sex === 'male' ? 'Муж' : 'Жен', () => {
            const n: Profile = {
              weightKg: this.p.weightKg, age: this.p.age,
              sex: this.p.sex === 'male' ? 'female' : 'male',
              defaultRestSec: this.p.defaultRestSec, vibration: this.p.vibration, configured: this.p.configured
            };
            this.p = n;
          })
        }
        ListItem() {
          this.stepper('rest', 'Отдых по умолчанию', formatMs(this.p.defaultRestSec * 1000))
        }
        ListItem() {
          this.toggleRow('Вибрация', this.p.vibration ? 'Вкл' : 'Выкл', () => {
            const n: Profile = {
              weightKg: this.p.weightKg, age: this.p.age, sex: this.p.sex,
              defaultRestSec: this.p.defaultRestSec, vibration: !this.p.vibration, configured: this.p.configured
            };
            this.p = n;
          })
        }
        ListItem() {
          Button('Сохранить', { type: ButtonType.Capsule })
            .width('100%').height(Sizes.BUTTON_H)
            .fontSize(17).fontWeight(FontWeight.Bold)
            .fontColor(Colors.ON_ACCENT).backgroundColor(Colors.SET)
            .onClick(() => this.save())
        }
      }
      .width('80%')
      .height('100%')
      .padding({ top: '18%', bottom: '22%' })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .focusable(true)
      .defaultFocus(true)
      .onDigitalCrown((e: CrownEvent) => {
        // Колесико меняет выбранное значение (точная регулировка без касаний).
        const steps = this.crown.feed(e);
        if (steps !== 0) {
          Haptics.tick();
          this.change(this.field, steps);
        }
        e.stopPropagation();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
  }
}
