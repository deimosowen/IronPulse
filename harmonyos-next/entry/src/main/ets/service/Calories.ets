import { Profile } from '../model/Types';

/** MET для силовой тренировки средней интенсивности — запасной вариант без пульса. */
const STRENGTH_MET = 5.0;

/**
 * Расход энергии, ккал/мин.
 * С пульсом — формула Keytel et al. (2005), учитывает ЧСС, вес, возраст, пол.
 * Без пульса (нет контакта) — по MET: ккал/мин = MET × 3.5 × вес / 200.
 */
export function kcalPerMinute(hr: number, p: Profile): number {
  const met = STRENGTH_MET * 3.5 * p.weightKg / 200;
  if (hr <= 0) {
    return met;
  }
  let kj: number;
  if (p.sex === 'female') {
    kj = -20.4022 + 0.4472 * hr - 0.1263 * p.weightKg + 0.074 * p.age;
  } else {
    kj = -55.0969 + 0.6309 * hr + 0.1988 * p.weightKg + 0.2017 * p.age;
  }
  const kcal = kj / 4.184;
  // При низком пульсе формула Keytel занижает расход (вплоть до отрицательного) — не опускаемся ниже покоя.
  const resting = 1.0 * 3.5 * p.weightKg / 200;
  return Math.max(resting, kcal);
}
