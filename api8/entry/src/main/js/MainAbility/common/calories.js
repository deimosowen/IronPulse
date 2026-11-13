const STRENGTH_MET = 5.0;

/**
 * Расход энергии, ккал/мин.
 * С пульсом — формула Keytel et al. (2005): ЧСС, вес, возраст, пол.
 * Без пульса — по MET силовой тренировки: MET × 3.5 × вес / 200.
 */
export function kcalPerMinute(hr, profile) {
  const w = profile.weightKg;
  if (!(hr > 0)) {
    return STRENGTH_MET * 3.5 * w / 200;
  }
  let kj;
  if (profile.sex === 'female') {
    kj = -20.4022 + 0.4472 * hr - 0.1263 * w + 0.074 * profile.age;
  } else {
    kj = -55.0969 + 0.6309 * hr + 0.1988 * w + 0.2017 * profile.age;
  }
  const resting = 1.0 * 3.5 * w / 200; // не ниже расхода покоя (Keytel занижает при низком пульсе)
  return Math.max(resting, kj / 4.184);
}
