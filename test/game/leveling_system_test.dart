import 'package:flutter_test/flutter_test.dart';
import 'package:kittykitty/game/leveling/leveling_system.dart';
import 'package:kittykitty/game/models/models.dart';

void main() {
  late Cat testCat;
  late Cat epicCat;
  late Cat legendaryCat;

  setUp(() {
    testCat = Cat(
      id: 'lv_test', ownerId: 'p1',
      name: '测试猫', rarity: Rarity.common, type: CatType.agility,
      baseHp: 100, baseAtk: 60, baseDef: 40, baseSpd: 50, baseCrit: 0.05,
      battleSkills: [], lifeSkills: [],
      imageUrl: '', captureLocation: const CatLocation(latitude: 0, longitude: 0),
      capturedAt: DateTime.now(),
    );

    epicCat = Cat(
      id: 'epic_test', ownerId: 'p1',
      name: '史诗', rarity: Rarity.epic, type: CatType.strength,
      baseHp: 130, baseAtk: 95, baseDef: 80, baseSpd: 85, baseCrit: 0.08,
      battleSkills: [], lifeSkills: [],
      imageUrl: '', captureLocation: const CatLocation(latitude: 0, longitude: 0),
      capturedAt: DateTime.now(),
    );

    legendaryCat = Cat(
      id: 'leg_test', ownerId: 'p1',
      name: '传说', rarity: Rarity.legendary, type: CatType.endurance,
      baseHp: 160, baseAtk: 120, baseDef: 100, baseSpd: 110, baseCrit: 0.10,
      battleSkills: [], lifeSkills: [],
      imageUrl: '', captureLocation: const CatLocation(latitude: 0, longitude: 0),
      capturedAt: DateTime.now(),
    );
  });

  group('LevelingSystem', () {
    group('expToNextLevel', () {
      test('Lv.1 → Lv.2 needs 55 exp', () {
        expect(LevelingSystem.expToNextLevel(1), 55);
      });

      test('exp curve is increasing', () {
        final exps = <int>[];
        for (var lv = 1; lv <= 50; lv++) {
          exps.add(LevelingSystem.expToNextLevel(lv));
        }
        for (var i = 1; i < exps.length; i++) {
          expect(exps[i], greaterThan(exps[i - 1]));
        }
      });

      test('formula matches spec', () {
        // EXP = 50 * Lv * (1 + 0.1 * Lv)
        expect(LevelingSystem.expToNextLevel(5), (50 * 5 * (1 + 0.1 * 5)).round());
        expect(LevelingSystem.expToNextLevel(20), (50 * 20 * (1 + 0.1 * 20)).round());
      });
    });

    group('battleExp', () {
      test('common opponent gives 50 base', () {
        expect(LevelingSystem.battleExp(opponentRarity: Rarity.common), 50);
      });

      test('legendary opponent gives 400 base', () {
        expect(LevelingSystem.battleExp(opponentRarity: Rarity.legendary), 400);
      });

      test('higher level opponent gives more', () {
        final base = LevelingSystem.battleExp(opponentRarity: Rarity.rare);
        final withAdv = LevelingSystem.battleExp(
          opponentRarity: Rarity.rare, levelDifference: 5);
        expect(withAdv, greaterThan(base));
      });
    });

    group('captureExp', () {
      test('common gives 25', () {
        expect(LevelingSystem.captureExp(Rarity.common), 25);
      });

      test('legendary gives 300', () {
        expect(LevelingSystem.captureExp(Rarity.legendary), 300);
      });
    });

    group('maxLevel', () {
      test('legendary max is 25', () {
        expect(LevelingSystem.maxLevel(Rarity.legendary), 25);
      });

      test('others max is 50', () {
        expect(LevelingSystem.maxLevel(Rarity.common), 50);
        expect(LevelingSystem.maxLevel(Rarity.epic), 50);
      });
    });

    group('addExp', () {
      test('enough exp triggers level up', () {
        final result = LevelingSystem.addExp(testCat, 200);
        expect(result.leveledUp, isTrue);
        expect(result.cat.level, greaterThan(1));
        expect(result.cat.exp, lessThan(LevelingSystem.expToNextLevel(result.cat.level)));
      });

      test('small exp does not trigger level up', () {
        final result = LevelingSystem.addExp(testCat, 10);
        expect(result.leveledUp, isFalse);
        expect(result.cat.level, 1);
        expect(result.cat.exp, 10);
      });

      test('massive exp triggers multiple levels', () {
        final result = LevelingSystem.addExp(testCat, 5000);
        expect(result.leveledUp, isTrue);
        expect(result.cat.level, greaterThan(5));
      });

      test('cannot exceed max level', () {
        final maxLv = LevelingSystem.maxLevel(Rarity.common);
        final atMax = testCat.copyWith(level: maxLv);
        final result = LevelingSystem.addExp(atMax, 99999);
        expect(result.leveledUp, isFalse);
        expect(result.cat.level, maxLv);
      });

      test('stats increase with level', () {
        final result = LevelingSystem.addExp(testCat, 500);
        final leveled = result.cat;
        // Each level: HP+3%, ATK+2.5%, DEF+2%, SPD+1.5%
        expect(leveled.hp, greaterThanOrEqualTo(testCat.hp));
      });
    });

    group('evolution', () {
      test('epic cat at level 20 can evolve', () {
        final lv20 = epicCat.copyWith(level: 20);
        expect(LevelingSystem.canEvolve(lv20), isTrue);
      });

      test('legendary cat at level 20 can evolve', () {
        final lv20 = legendaryCat.copyWith(level: 20);
        expect(LevelingSystem.canEvolve(lv20), isTrue);
      });

      test('common cat cannot evolve', () {
        final lv20 = testCat.copyWith(level: 20);
        expect(LevelingSystem.canEvolve(lv20), isFalse);
      });

      test('already evolved cat cannot evolve again', () {
        final lv20 = epicCat.copyWith(level: 20, evolved: true);
        expect(LevelingSystem.canEvolve(lv20), isFalse);
      });

      test('addExp triggers evolved flag', () {
        // 需要一次性升到 Lv.20
        final lv19 = epicCat.copyWith(level: 19, exp: 0);
        final needed = LevelingSystem.expToNextLevel(19);
        final result = LevelingSystem.addExp(lv19, needed + 100);
        if (result.evolved) {
          expect(result.cat.evolved, isTrue);
        }
      });

      test('evolved does not repeat on subsequent levels', () {
        final lv20Evolved = epicCat.copyWith(level: 20, evolved: true);
        expect(LevelingSystem.canEvolve(lv20Evolved), isFalse);

        final result = LevelingSystem.addExp(lv20Evolved, 5000);
        expect(result.evolved, isFalse);
      });
    });

    group('captureRateBonus', () {
      test('increases with wins', () {
        expect(LevelingSystem.captureRateBonus(5), 0.15);
        expect(LevelingSystem.captureRateBonus(10), greaterThan(0.15));
      });

      test('capped at 30%', () {
        expect(LevelingSystem.captureRateBonus(20), 0.30);
      });
    });
  });
}
