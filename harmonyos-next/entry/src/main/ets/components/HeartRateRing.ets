import { HrZones } from '../common/Theme';

/**
 * Внешний контур: дуга пульса по верхнему и боковым краям экрана (Gauge).
 * Длина дуги = текущий ЧСС в диапазоне 50–190, цвет — пульсовая зона.
 * Внизу оставлен разрыв 80° под главную кнопку.
 */
@Component
export struct HeartRateRing {
  @Prop hr: number = 0;

  build() {
    Gauge({
      value: this.hr > 0 ? Math.min(HrZones.GAUGE_MAX, Math.max(HrZones.GAUGE_MIN, this.hr)) : HrZones.GAUGE_MIN,
      min: HrZones.GAUGE_MIN,
      max: HrZones.GAUGE_MAX
    })
      .startAngle(220)
      .endAngle(140)
      .colors(HrZones.colorOf(this.hr))
      .strokeWidth(7)
      .indicator(null)
      .trackShadow({ radius: 0, offsetX: 0, offsetY: 0 })
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
      .animation({ duration: 400, curve: Curve.EaseOut })
  }
}
