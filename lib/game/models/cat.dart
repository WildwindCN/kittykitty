import 'rarity.dart';
import 'skill.dart';

class Cat {
  const Cat({
    required this.id,
    required this.ownerId,
    this.catFaceId,
    required this.name,
    required this.rarity,
    required this.type,
    required this.baseHp,
    required this.baseAtk,
    required this.baseDef,
    required this.baseSpd,
    required this.baseCrit,
    this.battleSkills = const [],
    this.lifeSkills = const [],
    this.level = 1,
    this.exp = 0,
    required this.imageUrl,
    this.cardImageUrl,
    required this.captureLocation,
    required this.capturedAt,
    this.totalBattles = 0,
    this.totalWins = 0,
    this.evolved = false,
    this.featureVector,
  });

  final String id;
  final String ownerId;
  final String? catFaceId; // 猫脸识别 ID，关联同一只真实猫咪
  final String name;
  final Rarity rarity;
  final CatType type;
  final int baseHp;
  final int baseAtk;
  final int baseDef;
  final int baseSpd;
  final double baseCrit;
  final List<BattleSkill> battleSkills;
  final List<LifeSkill> lifeSkills;
  final int level;
  final int exp;
  final String imageUrl;
  final String? cardImageUrl;
  final CatLocation captureLocation;
  final DateTime capturedAt;
  final int totalBattles;
  final int totalWins;
  final bool evolved;
  final List<double>? featureVector; // DINOv2 特征向量 (384维)

  /// 当前等级的实际属性
  int get hp => _scaledStat(baseHp, 0.03);
  int get atk => _scaledStat(baseAtk, 0.025);
  int get def => _scaledStat(baseDef, 0.02);
  int get spd => _scaledStat(baseSpd, 0.015);
  double get crit => (baseCrit * (1 + 0.01 * (level - 1))).clamp(0, 0.35);

  int _scaledStat(int base, double growthRate) {
    return (base * (1 + growthRate * (level - 1))).round();
  }

  /// 综合战力
  int get cp {
    final raw =
        hp * 0.4 + atk * 1.2 + def * 0.8 + spd * 0.6;
    return (raw * rarity.cpMultiplier).round();
  }

  /// 升级所需经验
  int get expToNextLevel => (50 * level * (1 + 0.1 * level)).round();

  /// 最大等级，传说稀有度限制更低
  int get maxLevel {
    switch (rarity) {
      case Rarity.legendary:
        return 25;
      default:
        return 50;
    }
  }

  /// 是否可以进化 (未进化 + 史诗/传说 + Lv.20)
  bool get canEvolve =>
      !evolved && level >= 20 && (rarity == Rarity.epic || rarity == Rarity.legendary);

  /// 战斗技能数量上限
  int get maxBattleSkillSlots {
    if (canEvolve) return 4;
    return switch (rarity) {
      Rarity.legendary => 3,
      Rarity.epic => 3,
      _ => 2,
    };
  }

  Cat copyWith({
    String? id,
    int? level,
    int? exp,
    int? totalBattles,
    int? totalWins,
    bool? evolved,
    String? cardImageUrl,
    List<BattleSkill>? battleSkills,
    List<double>? featureVector,
  }) {
    return Cat(
      id: id ?? this.id,
      ownerId: ownerId,
      catFaceId: catFaceId,
      name: name,
      rarity: rarity,
      type: type,
      baseHp: baseHp,
      baseAtk: baseAtk,
      baseDef: baseDef,
      baseSpd: baseSpd,
      baseCrit: baseCrit,
      battleSkills: battleSkills ?? this.battleSkills,
      lifeSkills: lifeSkills,
      level: level ?? this.level,
      exp: exp ?? this.exp,
      imageUrl: imageUrl,
      cardImageUrl: cardImageUrl ?? this.cardImageUrl,
      captureLocation: captureLocation,
      capturedAt: capturedAt,
      totalBattles: totalBattles ?? this.totalBattles,
      totalWins: totalWins ?? this.totalWins,
      evolved: evolved ?? this.evolved,
      featureVector: featureVector ?? this.featureVector,
    );
  }
}

class CatLocation {
  const CatLocation({
    required this.latitude,
    required this.longitude,
    this.address,
  });

  final double latitude;
  final double longitude;
  final String? address;
}
