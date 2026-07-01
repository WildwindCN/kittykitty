import 'dart:math';
import '../models/models.dart';

/// 自动对战引擎 — 纯 Dart，可离线单测
class BattleEngine {
  BattleEngine({int? seed}) : _random = Random(seed ?? DateTime.now().millisecondsSinceEpoch);

  final Random _random;
  final List<BattleRound> _rounds = [];
  final Map<String, List<StatEffect>> _activeEffects = {};

  static const double dodgeChance = 0.05;
  static const double critMultiplier = 1.6;
  static const double typeAdvantageMultiplier = 1.2;
  static const double typeDisadvantageMultiplier = 0.85;
  static const int maxRounds = 10;
  static const double lifeSkillChance = 0.20; // 20% 概率使用生活技能

  // 生活技能在战斗中的卖萌台词池
  static const _lifeSkillFlavors = [
    '翻了个身露出肚皮，什么都没发生…',
    '对着空气喵喵叫了两声…',
    '开始认真地舔毛，完全忘了在战斗…',
    '打了个大大的哈欠…',
    '追着自己的尾巴转圈…',
    '用头蹭了蹭地面，撒娇中…',
    '突然躺倒露出肚皮求摸…',
    '盯着远处的蝴蝶发呆…',
    '打了个喷嚏，把自己吓了一跳…',
    '开始踩奶，一脸陶醉…',
    '竖起尾巴慢悠悠地走过去蹭对手…',
    '趴下来打了个盹(3秒)…',
    '用爪子拨弄地上的小石子…',
    '对着对手眨了下眼睛:wink:…',
    '发出一声软糯的喵叫…',
  ];

  /// 执行完整对战，返回战斗记录
  Battle execute(Cat attacker, Cat defender) {
    _rounds.clear();
    _activeEffects.clear();
    _activeEffects[attacker.id] = [];
    _activeEffects[defender.id] = [];

    // 按 SPD 降序决定每回合出手顺序
    final order = [attacker, defender];
    order.sort((a, b) => _effectiveSpd(b).compareTo(_effectiveSpd(a)));

    String? winnerId;
    int atkHp = attacker.hp;
    int defHp = defender.hp;
    final atkSkills = List<BattleSkill>.from(attacker.battleSkills);
    final defSkills = List<BattleSkill>.from(defender.battleSkills);
    final atkLifeSkills = List<LifeSkill>.from(attacker.lifeSkills);
    final defLifeSkills = List<LifeSkill>.from(defender.lifeSkills);

    for (int roundNum = 1; roundNum <= maxRounds; roundNum++) {
      final actions = <BattleAction>[];

      for (final actor in order) {
        if (atkHp <= 0 || defHp <= 0) break;

        final isAttacker = actor.id == attacker.id;
        final skills = isAttacker ? atkSkills : defSkills;
        final lifeSkills = isAttacker ? atkLifeSkills : defLifeSkills;
        final targetId = isAttacker ? defender.id : attacker.id;
        final targetCurrentHp = isAttacker ? defHp : atkHp;

        // 80% 使用战斗技能，20% 使用生活技能（卖萌无伤害）
        final rollLifeSkill = _random.nextDouble() < lifeSkillChance &&
            lifeSkills.isNotEmpty;

        if (rollLifeSkill) {
          final lifeSkill = lifeSkills[_random.nextInt(lifeSkills.length)];
          final flavor = _lifeSkillFlavors[_random.nextInt(_lifeSkillFlavors.length)];
          actions.add(BattleAction(
            actorId: actor.id,
            skill: BattleSkill(
              id: 'life_${lifeSkill.id}',
              name: lifeSkill.name,
              type: SkillType.attack,
              power: 0, accuracy: 1.0,
              description: flavor,
            ),
            damage: 0,
            targetHpAfter: targetCurrentHp,
            isLifeSkill: true,
            lifeSkillFlavor: flavor,
          ));
          continue;
        }

        if (skills.isEmpty) {
          actions.add(BattleAction(
            actorId: actor.id,
            skill: const BattleSkill(id: 'none', name: '无技能', type: SkillType.attack, power: 0, accuracy: 0, description: '无可用战斗技能'),
            damage: 0,
            targetHpAfter: targetCurrentHp,
          ));
          continue;
        }

        // 随机选择一个战斗技能
        final skill = skills[_random.nextInt(skills.length)];

        // 命中判定
        if (_random.nextDouble() > skill.accuracy) {
          actions.add(BattleAction(
            actorId: actor.id,
            skill: skill,
            damage: 0,
            targetHpAfter: targetCurrentHp,
            isDodged: true,
          ));
          continue;
        }

        // 闪避判定
        if (_random.nextDouble() < dodgeChance) {
          actions.add(BattleAction(
            actorId: actor.id,
            skill: skill,
            damage: 0,
            targetHpAfter: targetCurrentHp,
            isDodged: true,
          ));
          continue;
        }

        // 伤害计算
        int damage = 0;
        bool isCrit = false;
        final statEffects = <StatEffect>[];

        if (skill.type == SkillType.attack) {
          final effectiveAtk = _effectiveAtk(actor);
          final opponent = isAttacker ? defender : attacker;
          final effectiveDef = _effectiveDef(opponent);

          double rawDamage = effectiveAtk *
              skill.multiplier *
              (1 - effectiveDef / (effectiveDef + 200));

          // 属性克制
          if (actor.type.isStrongAgainst(opponent.type)) {
            rawDamage *= typeAdvantageMultiplier;
          } else if (opponent.type.isStrongAgainst(actor.type)) {
            rawDamage *= typeDisadvantageMultiplier;
          }

          // 随机浮动 ±10%
          rawDamage *= 0.9 + _random.nextDouble() * 0.2;

          // 暴击判定
          final effectiveCrit = _effectiveCrit(actor);
          if (_random.nextDouble() < effectiveCrit) {
            rawDamage *= critMultiplier;
            isCrit = true;
          }

          damage = rawDamage.round().clamp(1, 9999);

          // 自伤
          if (skill.selfDamageRatio > 0) {
            final selfDamage = (damage * skill.selfDamageRatio).round();
            if (isAttacker) {
              atkHp = (atkHp - selfDamage).clamp(0, 9999);
            } else {
              defHp = (defHp - selfDamage).clamp(0, 9999);
            }
          }
        }

        // 应用伤害
        if (isAttacker) {
          defHp = (defHp - damage).clamp(0, 9999);
        } else {
          atkHp = (atkHp - damage).clamp(0, 9999);
        }

        // 属性修正效果
        if (skill.statModifier != null) {
          final mod = skill.statModifier!;
          final affectedId = mod.targetSelf ? actor.id : targetId;

          if (mod.atkMod != 0) {
            statEffects.add(StatEffect(
              stat: Stat.atk, modifier: mod.atkMod,
              remainingTurns: mod.duration, sourceId: actor.id,
            ));
          }
          if (mod.defMod != 0) {
            statEffects.add(StatEffect(
              stat: Stat.def, modifier: mod.defMod,
              remainingTurns: mod.duration, sourceId: actor.id,
            ));
          }
          if (mod.spdMod != 0) {
            statEffects.add(StatEffect(
              stat: Stat.spd, modifier: mod.spdMod,
              remainingTurns: mod.duration, sourceId: actor.id,
            ));
          }
          for (final eff in statEffects) {
            _activeEffects[affectedId]!.add(eff);
          }
        }

        actions.add(BattleAction(
          actorId: actor.id,
          skill: skill,
          damage: damage,
          targetHpAfter: isAttacker ? defHp : atkHp,
          isCrit: isCrit,
          statEffects: statEffects,
        ));
      }

      _rounds.add(BattleRound(roundNumber: roundNum, actions: actions));

      // 减少效果剩余回合
      for (final id in _activeEffects.keys) {
        _activeEffects[id] = _activeEffects[id]!
            .map((e) => StatEffect(
                  stat: e.stat, modifier: e.modifier,
                  remainingTurns: e.remainingTurns - 1, sourceId: e.sourceId,
                ))
            .where((e) => e.remainingTurns > 0)
            .toList();
      }

      // 胜负判定
      if (atkHp <= 0) { winnerId = defender.id; break; }
      if (defHp <= 0) { winnerId = attacker.id; break; }
    }

    // 超时判定：HP 百分比高者胜
    if (winnerId == null) {
      final atkPct = atkHp / (attacker.hp.clamp(1, 9999));
      final defPct = defHp / (defender.hp.clamp(1, 9999));
      winnerId = atkPct >= defPct ? attacker.id : defender.id;
    }

    return Battle(
      id: 'battle_${DateTime.now().millisecondsSinceEpoch}',
      attacker: attacker,
      defender: defender,
      state: BattleState.finished,
      rounds: List.unmodifiable(_rounds),
      winnerId: winnerId,
      seed: _random.hashCode,
      startedAt: DateTime.now(),
      finishedAt: DateTime.now(),
    );
  }

  int _effectiveAtk(Cat cat) {
    final mod = _totalMod(cat.id, Stat.atk);
    return (cat.atk * (1 + mod)).round();
  }

  int _effectiveDef(Cat cat) {
    final mod = _totalMod(cat.id, Stat.def);
    return (cat.def * (1 + mod)).round();
  }

  int _effectiveSpd(Cat cat) {
    final mod = _totalMod(cat.id, Stat.spd);
    return (cat.spd * (1 + mod)).round();
  }

  double _effectiveCrit(Cat cat) {
    // 计算生活技能中的暴击加成
    double bonus = 0;
    for (final skill in cat.lifeSkills) {
      if (skill.effect == LifeSkillEffect.critBoost) {
        bonus += skill.value;
      }
    }
    return cat.crit + bonus;
  }

  double _totalMod(String catId, Stat stat) {
    return _activeEffects[catId]
            ?.where((e) => e.stat == stat)
            .fold<double>(0, (sum, e) => sum + e.modifier) ??
        0;
  }
}
