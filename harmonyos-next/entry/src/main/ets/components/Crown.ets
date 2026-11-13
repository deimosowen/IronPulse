/**
 * Накопитель вращения заводной головки (Digital Crown):
 * переводит градусы поворота в целые «шаги».
 */
export class CrownAccumulator {
  private acc: number = 0;
  private readonly degPerStep: number;

  constructor(degPerStep: number) {
    this.degPerStep = degPerStep;
  }

  /** Возвращает число шагов (со знаком), накопленных этим событием. */
  feed(event: CrownEvent): number {
    this.acc += event.degree;
    const steps = this.acc > 0 ? Math.floor(this.acc / this.degPerStep) : Math.ceil(this.acc / this.degPerStep);
    this.acc -= steps * this.degPerStep;
    if (event.action === CrownAction.END) {
      this.acc = 0;
    }
    return steps;
  }

  /** Суммарный модуль поворота (для разблокировки экрана). */
  total(event: CrownEvent): number {
    this.acc += Math.abs(event.degree);
    const t = this.acc;
    if (event.action === CrownAction.END) {
      this.acc = 0;
    }
    return t;
  }

  reset(): void {
    this.acc = 0;
  }
}
