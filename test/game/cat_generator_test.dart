import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:kittykitty/game/generator/cat_generator.dart';
import 'package:kittykitty/game/models/models.dart';

void main() {
  late CatGenerator generator;

  setUp(() {
    generator = CatGenerator(random: Random(42));
  });

  group('CatGenerator', () {
    group('rarity distribution', () {
      test('rolls correct distribution over large sample', () {
        final counts = <Rarity, int>{};
        const n = 10000;

        for (var i = 0; i < n; i++) {
          final r = generator.rollRarity();
          counts[r] = (counts[r] ?? 0) + 1;
        }

        // 期望: 普通 60%, 稀有 25%, 史诗 12%, 传说 3%
        expect(counts[Rarity.common]! / n, closeTo(0.60, 0.04));
        expect(counts[Rarity.rare]! / n, closeTo(0.25, 0.04));
        expect(counts[Rarity.epic]! / n, closeTo(0.12, 0.03));
        expect(counts[Rarity.legendary]! / n, closeTo(0.03, 0.02));
      });
    });

    group('cat generation', () {
      test('generates valid cat with all required fields', () {
        final cat = generator.generateBaseCat(
          catId: 'test_1', ownerId: 'player_1',
          imageUrl: 'http://example.com/cat.png',
          latitude: 31.2, longitude: 121.4,
        );

        expect(cat.id, 'test_1');
        expect(cat.name, isNotEmpty);
        expect(cat.rarity, isNotNull);
        expect(cat.type, isNotNull);
        expect(cat.baseHp, greaterThanOrEqualTo(60));
        expect(cat.baseAtk, greaterThanOrEqualTo(40));
        expect(cat.baseDef, greaterThanOrEqualTo(30));
        expect(cat.baseSpd, greaterThanOrEqualTo(35));
        expect(cat.baseCrit, greaterThanOrEqualTo(0));
        expect(cat.baseCrit, lessThanOrEqualTo(0.15));
        expect(cat.level, 1);
        expect(cat.exp, 0);
        expect(cat.battleSkills, isNotEmpty);
        expect(cat.lifeSkills, isNotEmpty);
      });

      test('forced rarity works', () {
        final cat = generator.generateBaseCat(
          catId: 't', ownerId: 'p',
          imageUrl: '', latitude: 0, longitude: 0,
          forcedRarity: Rarity.legendary,
        );
        expect(cat.rarity, Rarity.legendary);
      });

      test('forced type works', () {
        final cat = generator.generateBaseCat(
          catId: 't', ownerId: 'p',
          imageUrl: '', latitude: 0, longitude: 0,
          forcedType: CatType.endurance,
        );
        expect(cat.type, CatType.endurance);
      });

      test('stats scale with rarity', () {
        final common = generator.generateBaseCat(
          catId: 'c', ownerId: 'p', imageUrl: '', latitude: 0, longitude: 0,
          forcedRarity: Rarity.common,
        );
        final legendary = generator.generateBaseCat(
          catId: 'l', ownerId: 'p', imageUrl: '', latitude: 0, longitude: 0,
          forcedRarity: Rarity.legendary,
        );

        // 传说猫的基础属性应高于普通猫
        expect(legendary.baseHp, greaterThan(common.baseHp));
        expect(legendary.baseAtk, greaterThan(common.baseAtk));
        expect(legendary.cp, greaterThan(common.cp));
      });

      test('generated names are Chinese', () {
        final names = <String>{};
        for (var i = 0; i < 50; i++) {
          final cat = generator.generateBaseCat(
            catId: 'n$i', ownerId: 'p',
            imageUrl: '', latitude: 0, longitude: 0,
          );
          names.add(cat.name);
        }
        // 名字应该有一定多样性
        expect(names.length, greaterThan(10));
        // 名字应为 2 个汉字
        for (final name in names) {
          expect(name.length, 2);
          expect(name.runes.every((r) => r >= 0x4E00 && r <= 0x9FFF), isTrue);
        }
      });

      test('skills respect min rarity', () {
        // 普通猫不应有传说技能
        for (var i = 0; i < 20; i++) {
          final cat = generator.generateBaseCat(
            catId: 's$i', ownerId: 'p',
            imageUrl: '', latitude: 0, longitude: 0,
            forcedRarity: Rarity.common,
          );
          for (final skill in cat.battleSkills) {
            expect(skill.minRarity.index, lessThanOrEqualTo(Rarity.common.index));
          }
        }
      });

      test('legendary cats get more skills', () {
        var totalSkills = 0;
        for (var i = 0; i < 20; i++) {
          final cat = generator.generateBaseCat(
            catId: 'ls$i', ownerId: 'p',
            imageUrl: '', latitude: 0, longitude: 0,
            forcedRarity: Rarity.legendary,
          );
          totalSkills += cat.battleSkills.length + cat.lifeSkills.length;
        }
        final avg = totalSkills / 20;
        expect(avg, greaterThan(3));
      });
    });

    group('CP calculation', () {
      test('CP formula matches spec', () {
        final cat = Cat(
          id: 'cp_test', ownerId: 'p',
          name: 'CP猫', rarity: Rarity.common, type: CatType.agility,
          baseHp: 100, baseAtk: 60, baseDef: 40, baseSpd: 50, baseCrit: 0.05,
          battleSkills: [], lifeSkills: [],
          imageUrl: '', captureLocation: const CatLocation(latitude: 0, longitude: 0),
          capturedAt: DateTime.now(),
        );

        final expectedCp = ((100 * 0.4 + 60 * 1.2 + 40 * 0.8 + 50 * 0.6) * 1.0).round();
        expect(cat.cp, expectedCp);
      });

      test('CP increases with level', () {
        final cat = generator.generateBaseCat(
          catId: 'lvl', ownerId: 'p',
          imageUrl: '', latitude: 0, longitude: 0,
        );
        final lv1Cp = cat.cp;
        final lv10Cat = cat.copyWith(level: 10);
        expect(lv10Cat.cp, greaterThan(lv1Cp));
      });
    });
  });
}
