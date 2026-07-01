import 'dart:math';
import '../models/models.dart';

/// 猫咪属性随机生成器
class CatGenerator {
  CatGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 基础属性范围（按稀有度 — 均为 int，crit 为千分比）
  static const _baseRanges = {
    Rarity.common: {'hp': (60, 90), 'atk': (40, 65), 'def': (30, 50), 'spd': (35, 60), 'crit': (0, 8)},
    Rarity.rare: {'hp': (80, 115), 'atk': (55, 85), 'def': (45, 70), 'spd': (50, 80), 'crit': (2, 10)},
    Rarity.epic: {'hp': (100, 145), 'atk': (75, 110), 'def': (60, 90), 'spd': (65, 100), 'crit': (4, 12)},
    Rarity.legendary: {'hp': (130, 180), 'atk': (100, 140), 'def': (80, 115), 'spd': (85, 125), 'crit': (6, 15)},
  };

  /// 随机生成稀有度
  Rarity rollRarity() {
    final roll = _random.nextDouble();
    double cumulative = 0;
    for (var i = 0; i < Rarity.values.length; i++) {
      cumulative += Rarity.captureWeights[i];
      if (roll <= cumulative) return Rarity.values[i];
    }
    return Rarity.common;
  }

  /// 随机生成属性类型
  CatType rollType() {
    return CatType.values[_random.nextInt(CatType.values.length)];
  }

  /// 在范围内正态分布采样
  int _rollStat(int min, int max) {
    final mid = (min + max) / 2;
    final stdDev = (max - min) / 6;
    final u1 = _random.nextDouble();
    final u2 = _random.nextDouble();
    final normal = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
    var result = (mid + normal * stdDev).round();
    if (result < min) result = min;
    if (result > max) result = max;
    return result;
  }

  /// 生成一只新猫咪的基础属性
  Cat generateBaseCat({
    required String catId,
    required String ownerId,
    String? name,
    Rarity? forcedRarity,
    CatType? forcedType,
    required String imageUrl,
    required double latitude,
    required double longitude,
    String? address,
  }) {
    final rarity = forcedRarity ?? rollRarity();
    final type = forcedType ?? rollType();
    final ranges = _baseRanges[rarity]!;

    final baseHp = _rollStat(ranges['hp']!.$1, ranges['hp']!.$2);
    final baseAtk = _rollStat(ranges['atk']!.$1, ranges['atk']!.$2);
    final baseDef = _rollStat(ranges['def']!.$1, ranges['def']!.$2);
    final baseSpd = _rollStat(ranges['spd']!.$1, ranges['spd']!.$2);
    final baseCrit = (_random.nextDouble() *
            (ranges['crit']!.$2 - ranges['crit']!.$1) +
        ranges['crit']!.$1) / 100;

    final skills = _rollSkills(rarity);
    final lifeSkills = skills.$2;
    final catName = name ?? _generateName(rarity);

    return Cat(
      id: catId,
      ownerId: ownerId,
      name: catName,
      rarity: rarity,
      type: type,
      baseHp: baseHp,
      baseAtk: baseAtk,
      baseDef: baseDef,
      baseSpd: baseSpd,
      baseCrit: baseCrit,
      battleSkills: skills.$1,
      lifeSkills: lifeSkills,
      imageUrl: imageUrl,
      captureLocation: CatLocation(
        latitude: latitude,
        longitude: longitude,
        address: address,
      ),
      capturedAt: DateTime.now(),
    );
  }

  /// 按稀有度随机抽取战斗技能
  (List<BattleSkill>, List<LifeSkill>) _rollSkills(Rarity rarity) {
    // 技能数量: 1 + (稀有及以上 +1) + (10% 概率额外 +1)
    int battleCount = 1;
    if (rarity == Rarity.rare || rarity == Rarity.epic) battleCount++;
    if (rarity == Rarity.legendary) battleCount += 2;
    if (_random.nextDouble() < 0.1) battleCount++;

    // 从技能池筛选符合稀有度要求的
    final available = skillPool.where((s) {
      return s.minRarity.index <= rarity.index;
    }).toList();

    available.shuffle(_random);
    final selected = available.take(battleCount).toList();

    // 生活技能 1~2 个
    int lifeCount = 1 + (_random.nextDouble() < 0.3 ? 1 : 0);
    final availableLife = lifeSkillPool.where((s) {
      return s.minRarity.index <= rarity.index;
    }).toList();
    availableLife.shuffle(_random);
    final selectedLife = availableLife.take(lifeCount).toList();

    return (selected, selectedLife);
  }

  String _generateName(Rarity rarity) {
    final prefix = _namePrefixes[_random.nextInt(_namePrefixes.length)];
    final suffix = _nameSuffixes[_random.nextInt(_nameSuffixes.length)];
    return '$prefix$suffix';
  }

  static const _namePrefixes = [
    '咪', '喵', '团', '球', '胖', '奶', '糯', '糖',
    '雪', '墨', '橘', '灰', '花', '豆', '丸', '布',
    '绒', '桃', '芝', '芒', '芋', '栗', '泡', '沫',
  ];

  static const _nameSuffixes = [
    '咪', '喵', '崽', '仔', '酱', '球', '团', '圆',
    '饼', '包', '丁', '卷', '糕', '冻', '贝', '宝',
    '萌', '呆', '憨', '乖', '猛', '跳', '跑', '睡',
  ];

  // ===== 战斗技能池 (20个) =====

  static final List<BattleSkill> skillPool = [
    // 攻击技 (12)
    const BattleSkill(id: 'scratch', name: '猫爪连击', type: SkillType.attack, power: 40, accuracy: 0.95, description: '连续挥爪攻击，70%概率攻击2次'),
    const BattleSkill(id: 'bite', name: '利齿撕咬', type: SkillType.attack, power: 55, accuracy: 0.90, description: '锋利的牙齿造成较高伤害'),
    const BattleSkill(id: 'pounce', name: '猛扑', type: SkillType.attack, power: 65, accuracy: 0.80, description: '全力猛扑，威力大但命中率稍低'),
    const BattleSkill(id: 'tail_whip', name: '尾鞭', type: SkillType.attack, power: 30, accuracy: 1.0, description: '必定命中的尾鞭攻击'),
    const BattleSkill(id: 'shadow_strike', name: '暗影突袭', type: SkillType.attack, power: 70, accuracy: 0.75, description: '暗影中突袭，暴击率+20%', minRarity: Rarity.rare),
    const BattleSkill(id: 'fury_swipe', name: '狂暴乱抓', type: SkillType.attack, power: 50, accuracy: 0.85, description: '陷入狂暴连续攻击，自伤10%', selfDamageRatio: 0.1, minRarity: Rarity.rare),
    const BattleSkill(id: 'thunder_claw', name: '雷鸣爪', type: SkillType.attack, power: 85, accuracy: 0.70, description: '带有雷鸣之力的爪击，有15%概率麻痹对手', minRarity: Rarity.epic),
    const BattleSkill(id: 'moonlight_fang', name: '月光牙', type: SkillType.attack, power: 80, accuracy: 0.85, description: '月光加持的撕咬，回复造成伤害的20%', minRarity: Rarity.epic),
    const BattleSkill(id: 'starfall', name: '流星坠落', type: SkillType.attack, power: 95, accuracy: 0.65, description: '召唤流星之力，威力巨大但容易落空', minRarity: Rarity.legendary),
    const BattleSkill(id: 'void_slash', name: '虚空斩', type: SkillType.attack, power: 100, accuracy: 0.80, description: '无视20%防御的虚空斩击', minRarity: Rarity.legendary),
    const BattleSkill(id: 'quick_swipe', name: '快速爪击', type: SkillType.attack, power: 25, accuracy: 1.0, description: '快速出手，若速度高于对手则伤害翻倍'),
    const BattleSkill(id: 'sneak_attack', name: '偷袭', type: SkillType.attack, power: 45, accuracy: 0.95, description: '偷袭对手，暴击率+10%'),

    // 防御技 (4)
    const BattleSkill(id: 'curl_up', name: '蜷缩防御', type: SkillType.defense, power: 0, accuracy: 1.0, description: '蜷缩身体，本回合受伤-40%', statModifier: StatModifier(defMod: 0.4, duration: 1, targetSelf: true)),
    const BattleSkill(id: 'catnap', name: '打盹回血', type: SkillType.defense, power: 0, accuracy: 1.0, description: '打个盹恢复15%HP'),
    const BattleSkill(id: 'fur_shield', name: '毛皮护盾', type: SkillType.defense, power: 0, accuracy: 1.0, description: '竖起毛发形成护盾，2回合防御+30%', statModifier: StatModifier(defMod: 0.3, duration: 2, targetSelf: true), minRarity: Rarity.rare),
    const BattleSkill(id: 'nine_lives', name: '九命护体', type: SkillType.defense, power: 0, accuracy: 1.0, description: '本回合免疫一次致命伤害并回复1HP', minRarity: Rarity.legendary),

    // 控制技 (4)
    const BattleSkill(id: 'glare', name: '瞪视', type: SkillType.control, power: 0, accuracy: 0.85, description: '锐利的目光瞪视对手，使其下回合ATK-25%', statModifier: StatModifier(atkMod: -0.25, duration: 1)),
    const BattleSkill(id: 'hiss', name: '嘶吼威吓', type: SkillType.control, power: 0, accuracy: 0.80, description: '发出嘶嘶声威吓对手，SPD-30%持续2回合', statModifier: StatModifier(spdMod: -0.3, duration: 2), minRarity: Rarity.rare),
    const BattleSkill(id: 'charm', name: '魅惑', type: SkillType.control, power: 0, accuracy: 0.75, description: '卖萌魅惑对手，对方跳过下一回合', minRarity: Rarity.epic),
    const BattleSkill(id: 'hypnosis', name: '催眠凝视', type: SkillType.control, power: 0, accuracy: 0.60, description: '用深邃的眼神催眠对手，对方ATK-40%、DEF-20%', statModifier: StatModifier(atkMod: -0.4, defMod: -0.2, duration: 2), minRarity: Rarity.epic),
  ];

  // ===== 生活技能池 (10个) =====

  static final List<LifeSkill> lifeSkillPool = [
    const LifeSkill(id: 'gold_nose', name: '寻宝嗅觉', effect: LifeSkillEffect.goldBonus, value: 0.15, description: '探索时额外获得15%金币'),
    const LifeSkill(id: 'lucky_star', name: '幸运之星', effect: LifeSkillEffect.itemDrop, value: 0.10, description: '触发路人赠送道具概率+10%'),
    const LifeSkill(id: 'smart_brain', name: '聪慧过人', effect: LifeSkillEffect.expBoost, value: 0.10, description: '战斗获得经验+10%'),
    const LifeSkill(id: 'cat_magnet', name: '猫缘深厚', effect: LifeSkillEffect.encounterRate, value: 0.05, description: '遇到稀有及以上猫咪概率+5%', minRarity: Rarity.rare),
    const LifeSkill(id: 'quick_heal', name: '快速恢复', effect: LifeSkillEffect.healAfterBattle, value: 0.20, description: '战斗结束后恢复20%HP', minRarity: Rarity.rare),
    const LifeSkill(id: 'energetic', name: '精力充沛', effect: LifeSkillEffect.staminaBoost, value: 2, description: '每日可对战次数+2'),
    const LifeSkill(id: 'radar_sense', name: '敏锐感知', effect: LifeSkillEffect.nearbyRadar, value: 0.30, description: '地图上猫咪探测范围扩大30%', minRarity: Rarity.epic),
    const LifeSkill(id: 'charm_boost', name: '魅力四射', effect: LifeSkillEffect.charmBoost, value: 0.08, description: '捕捉成功率+8%', minRarity: Rarity.rare),
    const LifeSkill(id: 'regen', name: '生命恢复', effect: LifeSkillEffect.hpRegen, value: 0.02, description: '每30秒自动恢复2%HP', minRarity: Rarity.epic),
    const LifeSkill(id: 'crit_master', name: '致命一击', effect: LifeSkillEffect.critBoost, value: 0.05, description: '暴击率额外+5%', minRarity: Rarity.legendary),
  ];
}
