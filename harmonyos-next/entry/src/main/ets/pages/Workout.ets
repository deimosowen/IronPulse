import { Colors, Sizes } from '../common/Theme';
import { formatHms, formatMs, formatTonnage, formatWeight } from '../common/Format';
import { EngineView, WorkoutEngine } from '../service/WorkoutEngine';
import { Haptics } from '../service/Haptics';
import { exercisesForTemplate } from '../model/Exercises';
import { ExerciseDef } from '../model/Types';
import { HeartRateRing } from '../components/HeartRateRing';
import { HoldButton, PillButton, StatCell } from '../components/Widgets';
import { EditTarget, ValueEditor } from '../components/ValueEditor';
import { CrownAccumulator } from '../components/Crown';

const PAGE_CONTROLS = 0;
const PAGE_MAIN = 1;
const V_SET_REST = 0;
const V_EXERCISES = 1;
const UNLOCK_CROWN_DEG = 180;

/**
 * Экран 2 (активная тренировка) + экран 3 (смена упражнения, свайп вверх)
 * + экран 4 (управление, свайп вправо).
 *
 *   Горизонтальный Swiper: [Управление] ← [Тренировка]
 *   Вертикальный Swiper внутри «Тренировки»: [Подход/Отдых] ↕ [Упражнения]
 *   Поверх всего — дуга пульса и статус-строка; при блокировке — оверлей.
 */
@Entry
@Component
struct Workout {
  @State view: EngineView = WorkoutEngine.view();
  @State hPage: number = PAGE_MAIN;
  @State vPage: number = V_SET_REST;
  @State target: EditTarget = 'weight';
  @State editingSet: boolean = false;
  @State locked: boolean = false;
  @State unlockProgress: number = 0;
  private listenerId: number = -1;
  private hController: SwiperController = new SwiperController();
  private vController: SwiperController = new SwiperController();
  private listScroller: Scroller = new Scroller();
  private crownValues: CrownAccumulator = new CrownAccumulator(15);
  private crownUnlock: CrownAccumulator = new CrownAccumulator(1);
  private commitTimer: number = -1;
  private exerciseList: ExerciseDef[] = [];

  aboutToAppear(): void {
    this.listenerId = WorkoutEngine.subscribe((v: EngineView) => {
      if (!v.active) {
        return;
      }
      if (this.view.phase !== v.phase) {
        this.editingSet = false;
        // При смене фазы возвращаемся на основной экран подхода/отдыха.
        if (this.vPage !== V_SET_REST) {
          this.vController.changeIndex(V_SET_REST, true);
        }
      }
      if (this.exerciseList.length === 0 || this.view.templateId !== v.templateId) {
        this.exerciseList = exercisesForTemplate(v.templateId);
      }
      this.view = v;
    });
  }

  aboutToDisappear(): void {
    WorkoutEngine.unsubscribe(this.listenerId);
    if (this.commitTimer >= 0) {
      clearTimeout(this.commitTimer);
      WorkoutEngine.commitEdits();
    }
  }

  /** Тренировку нельзя покинуть кнопкой «назад» — только через «Завершить». */
  onBackPress(): boolean {
    if (!this.locked && this.hPage !== PAGE_CONTROLS) {
      this.hController.changeIndex(PAGE_CONTROLS, true);
    }
    return true;
  }

  // ---------- Действия ----------

  private adjust(t: EditTarget, steps: number): void {
    if (t === 'weight') {
      WorkoutEngine.adjustWeight(steps);
    } else {
      WorkoutEngine.adjustReps(steps);
    }
    // Отложенное сохранение, чтобы не писать в хранилище на каждый щелчок колесика.
    if (this.commitTimer >= 0) {
      clearTimeout(this.commitTimer);
    }
    this.commitTimer = setTimeout(() => {
      this.commitTimer = -1;
      WorkoutEngine.commitEdits();
    }, 1500);
  }

  private onCrown(e: CrownEvent): void {
    if (this.locked) {
      const deg = this.crownUnlock.total(e);
      this.unlockProgress = Math.min(100, deg * 100 / UNLOCK_CROWN_DEG);
      if (deg >= UNLOCK_CROWN_DEG) {
        this.unlock();
      } else if (e.action === CrownAction.END) {
        this.unlockProgress = 0;
      }
      return;
    }
    if (this.hPage !== PAGE_MAIN) {
      return;
    }
    if (this.vPage === V_EXERCISES) {
      this.listScroller.scrollBy(0, e.degree * 1.5);
      return;
    }
    const steps = this.crownValues.feed(e);
    if (steps !== 0) {
      Haptics.tick();
      // Вращение по часовой (degree > 0) — увеличение.
      this.adjust(this.target, steps);
    }
  }

  private lock(): void {
    this.locked = true;
    this.unlockProgress = 0;
    this.crownUnlock.reset();
    this.hController.changeIndex(PAGE_MAIN, false);
  }

  private unlock(): void {
    this.locked = false;
    this.unlockProgress = 0;
    this.crownUnlock.reset();
    Haptics.tap();
  }

  private finishWorkout(): void {
    WorkoutEngine.finish();
    this.getUIContext().getRouter().replaceUrl({ url: 'pages/Summary' });
  }

  // ---------- Внешний контур ----------

  @Builder
  statusBar() {
    Row() {
      Text(formatHms(this.view.elapsedMs))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.view.paused ? Colors.MUTED : Colors.TEXT)
        .fontFeature('"tnum" on')
      Text(this.view.hr > 0 ? `  ♥ ${this.view.hr}` : '  ♥ --')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.view.hr > 0 ? Colors.TEXT : Colors.MUTED)
        .fontFeature('"tnum" on')
    }
    .margin({ top: '9%' })
    .hitTestBehavior(HitTestMode.Transparent)
  }

  // ---------- Состояние А: подход ----------

  @Builder
  setView() {
    Column() {
      Text(this.view.exerciseName)
        .fontSize(14)
        .fontColor(Colors.SET)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('70%')
        .textAlign(TextAlign.Center)
      Text(`Подход ${this.view.setNumber}`)
        .fontSize(12)
        .fontColor(Colors.MUTED)
        .margin({ top: 1 })

      // Крупно: «80 кг × 10». Тап — показать инлайн-редактор.
      Row() {
        Text(formatWeight(this.view.plannedWeight))
          .fontSize(42).fontWeight(FontWeight.Bold)
          .fontColor(this.editingSet && this.target === 'weight' ? Colors.SET : Colors.TEXT)
          .onClick(() => this.toggleSetEdit('weight'))
        Text('кг').fontSize(14).fontColor(Colors.MUTED).margin({ left: 2, top: 14 })
        Text('×').fontSize(26).fontColor(Colors.SET).margin({ left: 6, right: 6 })
        Text(`${this.view.plannedReps}`)
          .fontSize(42).fontWeight(FontWeight.Bold)
          .fontColor(this.editingSet && this.target === 'reps' ? Colors.SET : Colors.TEXT)
          .onClick(() => this.toggleSetEdit('reps'))
      }
      .alignItems(VerticalAlign.Center)
      .margin({ top: 2 })

      if (this.editingSet) {
        ValueEditor({
          weight: this.view.plannedWeight,
          reps: this.view.plannedReps,
          step: this.view.weightStep,
          accent: Colors.SET,
          target: this.target,
          onSelect: (t: EditTarget) => {
            this.target = t;
          },
          onAdjust: (t: EditTarget, steps: number) => this.adjust(t, steps)
        })
          .margin({ top: 2, bottom: 6 })
      } else {
        Row() {
          StatCell({ value: formatTonnage(this.view.tonnage), caption: 'кг' })
          StatCell({ value: `${Math.round(this.view.calories)}`, caption: 'ккал' })
        }
        .width('56%')
        .margin({ top: 2, bottom: 8 })
      }

      PillButton({
        label: 'Завершить подход',
        color: Colors.SET,
        btnWidth: '72%',
        onTap: () => {
          this.editingSet = false;
          WorkoutEngine.finishSet();
        }
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .padding({ bottom: '7%' })
  }

  private toggleSetEdit(t: EditTarget): void {
    Haptics.tick();
    if (this.editingSet && this.target === t) {
      this.editingSet = false;
    } else {
      this.editingSet = true;
      this.target = t;
    }
  }

  // ---------- Состояние Б: отдых ----------

  @Builder
  restView() {
    Column() {
      Text(`Отдых • подход ${this.view.setNumber} выполнен`)
        .fontSize(12)
        .fontColor(Colors.REST)
        .maxLines(1)
        .width('72%')
        .textAlign(TextAlign.Center)

      Text(formatMs(this.view.restRemainingMs))
        .fontSize(46)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.view.restRemainingMs <= 5000 ? Colors.REST : Colors.TEXT)
        .fontFeature('"tnum" on')
        .gesture(LongPressGesture({ duration: 600 }).onAction(() => {
          Haptics.tap();
          WorkoutEngine.addRest(30000);
        }))

      Progress({
        value: this.view.restTotalMs > 0 ? this.view.restTotalMs - this.view.restRemainingMs : 0,
        total: Math.max(1, this.view.restTotalMs),
        type: ProgressType.Linear
      })
        .width('48%')
        .height(4)
        .color(Colors.REST)
        .backgroundColor(Colors.SURFACE_2)
        .margin({ bottom: 6 })

      // Факт выполненного подхода — правка прямо во время отдыха.
      ValueEditor({
        weight: this.view.plannedWeight,
        reps: this.view.plannedReps,
        step: this.view.weightStep,
        accent: Colors.REST,
        target: this.target,
        onSelect: (t: EditTarget) => {
          this.target = t;
        },
        onAdjust: (t: EditTarget, steps: number) => this.adjust(t, steps)
      })
        .margin({ bottom: 6 })

      PillButton({
        label: 'Начать подход',
        color: Colors.REST,
        btnWidth: '66%',
        onTap: () => WorkoutEngine.startSet()
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .padding({ bottom: '7%' })
  }

  // ---------- Экран 3: упражнения ----------

  @Builder
  exerciseRow(title: string, subtitle: string, current: boolean, done: boolean, onTap: () => void) {
    Row() {
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor(current ? Colors.SET : Colors.TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (subtitle.length > 0) {
          Text(subtitle).fontSize(11).fontColor(Colors.MUTED)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (done) {
        Text('✓').fontSize(16).fontColor(Colors.ZONE_LOW)
      }
    }
    .width('100%')
    .constraintSize({ minHeight: Sizes.BUTTON_H })
    .padding({ left: 14, right: 14 })
    .borderRadius(Sizes.RADIUS)
    .backgroundColor(current ? Colors.SURFACE_2 : Colors.SURFACE)
    .onClick(() => onTap())
  }

  @Builder
  exercisesView() {
    List({ space: 6, scroller: this.listScroller }) {
      ListItem() {
        Column() {
          Text(this.view.exerciseName)
            .fontSize(15).fontWeight(FontWeight.Bold).fontColor(Colors.SET)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.view.exerciseSetsDone > 0
            ? `${this.view.exerciseSetsDone} подх. • макс ${formatWeight(this.view.exerciseMaxWeight)} кг`
            : 'подходов ещё нет')
            .fontSize(12).fontColor(Colors.MUTED).margin({ top: 2 })
        }
        .width('100%')
        .padding({ top: 4, bottom: 4 })
      }

      ListItem() {
        PillButton({
          label: 'Следующее упражнение',
          color: Colors.SET,
          btnWidth: '100%',
          onTap: () => {
            WorkoutEngine.nextExercise();
            this.vController.changeIndex(V_SET_REST, true);
          }
        })
      }

      ListItem() {
        this.exerciseRow('+ Новое упражнение', 'без названия', false, false, () => {
          WorkoutEngine.newCustomExercise();
          this.vController.changeIndex(V_SET_REST, true);
        })
      }

      ForEach(this.exerciseList, (e: ExerciseDef) => {
        ListItem() {
          this.exerciseRow(
            e.name,
            '',
            e.id === this.view.exerciseId,
            this.view.doneExerciseIds.indexOf(e.id) >= 0,
            () => {
              WorkoutEngine.selectExercise(e.id);
              this.vController.changeIndex(V_SET_REST, true);
            })
        }
      }, (e: ExerciseDef) => e.id)
    }
    .width('76%')
    .height('100%')
    .padding({ top: '24%', bottom: '20%' })
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .nestedScroll({ scrollForward: NestedScrollMode.SELF_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST })
  }

  // ---------- Экран 4: управление ----------

  @Builder
  controlsView() {
    Column({ space: 10 }) {
      Text(this.view.paused ? 'На паузе' : 'Управление')
        .fontSize(13)
        .fontColor(this.view.paused ? Colors.SET : Colors.MUTED)
      PillButton({
        label: this.view.paused ? 'Продолжить' : 'Пауза',
        color: this.view.paused ? Colors.SET : Colors.SURFACE_2,
        textColor: this.view.paused ? Colors.ON_ACCENT : Colors.TEXT,
        btnWidth: '78%',
        onTap: () => WorkoutEngine.togglePause()
      })
      PillButton({
        label: 'Блокировка',
        color: Colors.SURFACE_2,
        textColor: Colors.TEXT,
        btnWidth: '78%',
        onTap: () => this.lock()
      })
      HoldButton({
        label: 'Завершить',
        color: Colors.DANGER,
        holdMs: 1200,
        onConfirm: () => this.finishWorkout()
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: '12%' })
  }

  // ---------- Блокировка ----------

  @Builder
  lockOverlay() {
    Column({ space: 8 }) {
      Stack() {
        Progress({ value: this.unlockProgress, total: 100, type: ProgressType.Ring })
          .width(88).height(88)
          .color(Colors.REST)
          .backgroundColor(Colors.SURFACE_2)
          .style({ strokeWidth: 5 })
        Text('🔒').fontSize(30)
      }
      Text('Экран заблокирован').fontSize(14).fontColor(Colors.TEXT)
      Text('Удерживайте экран\nили поверните колесико')
        .fontSize(11).fontColor(Colors.MUTED).textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#E6000000')
    .hitTestBehavior(HitTestMode.Block)
    .gesture(
      LongPressGesture({ duration: 1500 })
        .onAction(() => this.unlock())
    )
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Swiper(this.hController) {
        // Экран 4 — слева: открывается свайпом вправо.
        Stack() {
          this.controlsView()
        }
        .width('100%')
        .height('100%')

        Swiper(this.vController) {
          Stack() {
            if (this.view.phase === 'set') {
              this.setView()
            } else {
              this.restView()
            }
          }
          .width('100%')
          .height('100%')

          Stack() {
            this.exercisesView()
          }
          .width('100%')
          .height('100%')
        }
        .vertical(true)
        .loop(false)
        .index(this.vPage)
        .indicator(
          Indicator.dot()
            .right(6)
            .itemWidth(4).itemHeight(4)
            .selectedItemWidth(4).selectedItemHeight(10)
            .color(Colors.SURFACE_2)
            .selectedColor(Colors.MUTED)
        )
        .onChange((i: number) => {
          this.vPage = i;
        })
      }
      .loop(false)
      .index(this.hPage)
      .indicator(false)
      .disableSwipe(this.locked)
      .onChange((i: number) => {
        this.hPage = i;
      })
      .width('100%')
      .height('100%')

      HeartRateRing({ hr: this.view.hr })

      this.statusBar()

      if (this.locked) {
        this.lockOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Colors.BG)
    .focusable(true)
    .defaultFocus(true)
    .focusOnTouch(true)
    .onDigitalCrown((e: CrownEvent) => this.onCrown(e))
  }
}
