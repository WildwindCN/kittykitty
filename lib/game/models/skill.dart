import 'rarity.dart';

class BattleSkill {
  const BattleSkill({
    required this.id,
    required this.name,
    required this.type,
    required this.power,
    required this.accuracy,
    required this.description,
    this.selfDamageRatio = 0,
    this.statModifier,
    this.minRarity = Rarity.common,
  });

  final String id;
  final String name;
  final SkillType type;
  final int power; // 技能威力 (0-100)
  final double accuracy; // 命中率 (0.0-1.0)
  final String description;
  final double selfDamageRatio; // 自伤比例 (如 0.1 = 10% 反伤)
  final StatModifier? statModifier; // 属性修正效果
  final Rarity minRarity; // 最低稀有度要求

  /// 技能倍率 = power / 70，使普通攻击约在 0.5~1.4 范围
  double get multiplier => power / 70.0;
}

enum SkillType {
  attack('攻击'),
  defense('防御'),
  control('控制');

  const SkillType(this.label);
  final String label;
}

class StatModifier {
  const StatModifier({
    this.atkMod = 0,
    this.defMod = 0,
    this.spdMod = 0,
    this.duration = 1,
    this.targetSelf = false,
  });

  final double atkMod; // 攻击修正 (如 -0.25 = 降低25%)
  final double defMod;
  final double spdMod;
  final int duration; // 持续回合数
  final bool targetSelf; // true = 对自己施放
}

class LifeSkill {
  const LifeSkill({
    required this.id,
    required this.name,
    required this.effect,
    required this.description,
    this.value = 0,
    this.minRarity = Rarity.common,
  });

  final String id;
  final String name;
  final LifeSkillEffect effect;
  final double value;
  final String description;
  final Rarity minRarity;
}

enum LifeSkillEffect {
  goldBonus('寻宝嗅觉', '探索时额外获得金币'),
  itemDrop('幸运之星', '触发路人赠送道具概率增加'),
  expBoost('聪慧过人', '战斗获得经验增加'),
  encounterRate('猫缘深厚', '遇到稀有猫咪概率提升'),
  healAfterBattle('快速恢复', '战斗结束后恢复部分HP'),
  staminaBoost('精力充沛', '每日可对战次数增加'),
  nearbyRadar('敏锐感知', '地图上猫咪探测范围扩大'),
  charmBoost('魅力四射', '捕捉成功率提升'),
  hpRegen('生命恢复', '随时间自动恢复HP'),
  critBoost('致命一击', '暴击率额外增加');

  const LifeSkillEffect(this.label, this.description);
  final String label;
  final String description;
}
