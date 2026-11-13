import { describe, expect, it } from '@ohos/hypium';
import { formatHms, formatMs, formatTonnage, formatWeight } from '../main/ets/common/Format';
import { HrZones } from '../main/ets/common/Theme';
import { kcalPerMinute } from '../main/ets/service/Calories';
import { exercisesForTemplate, findTemplate, weightStep, EXERCISES, TEMPLATES } from '../main/ets/model/Exercises';
import { ExerciseDef, Profile, Template } from '../main/ets/model/Types';

function profile(sex: 'male' | 'female'): Profile {
  const p: Profile = { weightKg: 80, age: 30, sex: sex, defaultRestSec: 90, vibration: true, configured: true };
  return p;
}

export default function logicTest() {
  describe('Format', () => {
    it('hms', 0, () => {
      expect(formatHms(0)).assertEqual('00:00:00');
      expect(formatHms(3723999)).assertEqual('01:02:03');
    });
    it('rest countdown rounds up', 0, () => {
      expect(formatMs(90000)).assertEqual('01:30');
      expect(formatMs(4001)).assertEqual('00:05');
      expect(formatMs(0)).assertEqual('00:00');
      expect(formatMs(-500)).assertEqual('00:00');
    });
    it('weight', 0, () => {
      expect(formatWeight(80)).assertEqual('80');
      expect(formatWeight(82.5)).assertEqual('82.5');
    });
    it('tonnage groups thousands', 0, () => {
      expect(formatTonnage(950)).assertEqual('950');
      expect(formatTonnage(12450)).assertEqual('12 450');
      expect(formatTonnage(1234567)).assertEqual('1 234 567');
    });
  });

  describe('HrZones', () => {
    it('zone boundaries', 0, () => {
      expect(HrZones.zoneOf(0)).assertEqual(-1);
      expect(HrZones.zoneOf(109)).assertEqual(0);
      expect(HrZones.zoneOf(110)).assertEqual(1);
      expect(HrZones.zoneOf(145)).assertEqual(1);
      expect(HrZones.zoneOf(146)).assertEqual(2);
    });
  });

  describe('Calories', () => {
    it('no HR falls back to MET 5', 0, () => {
      // 5 * 3.5 * 80 / 200 = 7 ккал/мин
      expect(kcalPerMinute(0, profile('male'))).assertClose(7, 0.001);
    });
    it('Keytel male at 130 bpm', 0, () => {
      const expected = (-55.0969 + 0.6309 * 130 + 0.1988 * 80 + 0.2017 * 30) / 4.184;
      expect(kcalPerMinute(130, profile('male'))).assertClose(expected, 0.001);
    });
    it('low HR never below resting', 0, () => {
      expect(kcalPerMinute(50, profile('female')) >= 1.4).assertTrue();
    });
    it('higher HR burns more', 0, () => {
      expect(kcalPerMinute(150, profile('male')) > kcalPerMinute(110, profile('male'))).assertTrue();
    });
  });

  describe('Exercises', () => {
    it('template ids exist in database', 0, () => {
      TEMPLATES.forEach((t: Template) => {
        t.exerciseIds.forEach((id: string) => {
          expect(EXERCISES.some((e: ExerciseDef) => e.id === id)).assertTrue();
        });
      });
    });
    it('template exercises come first, no duplicates', 0, () => {
      const list = exercisesForTemplate('chest_tri');
      expect(list[0].id).assertEqual('bench');
      expect(list.length).assertEqual(EXERCISES.length);
    });
    it('unknown template falls back to free', 0, () => {
      expect(findTemplate('nope').id).assertEqual('free');
    });
    it('weight step', 0, () => {
      expect(weightStep('squat')).assertEqual(5);
      expect(weightStep('custom-1')).assertEqual(2.5);
    });
  });
}
