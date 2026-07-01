import '../models/models.dart';

/// 等级与经验系统
class LevelingSystem {
  const LevelingSystem();

  /// 升到下一级所需经验
  static int expToNextLevel(int currentLevel) {
    return (50 * currentLevel * (1 + 0.1 * currentLevel)).round();
  }

  /// 战斗胜利获得的基础经验
  static int battleExp({
    required Rarity opponentRarity,
    int levelDifference = 0,
  }) {
    // 基础经验按对手稀有度
    final baseExp = switch (opponentRarity) {
      Rarity.common => 50,
      Rarity.rare => 100,
      Rarity.epic => 200,
      Rarity.legendary => 400,
    };

    // 等级差修正 (打高级猫给更多经验)
    final levelModifier = 1 + (levelDifference * 0.1).clamp(-0.5, 1.0);

    return (baseExp * levelModifier).round();
  }

  /// 捕捉成功额外经验
  static int captureExp(Rarity rarity) {
    return switch (rarity) {
      Rarity.common => 25,
      Rarity.rare => 60,
      Rarity.epic => 150,
      Rarity.legendary => 300,
    };
  }

  /// 最大等级
  static int maxLevel(Rarity rarity) {
    return switch (rarity) {
      Rarity.legendary => 25,
      _ => 50,
    };
  }

  /// 是否可以进化（仅当从未进化过 + Lv.20 + 史诗/传说）
  static bool canEvolve(Cat cat) {
    return !cat.evolved && cat.level >= 20 &&
        (cat.rarity == Rarity.epic || cat.rarity == Rarity.legendary);
  }

  /// 应用经验值，返回是否升级以及新的 Cat 状态
  static ({Cat cat, bool leveledUp, bool evolved}) addExp(Cat cat, int exp) {
    if (cat.level >= maxLevel(cat.rarity)) {
      return (cat: cat, leveledUp: false, evolved: false);
    }

    int newExp = cat.exp + exp;
    int newLevel = cat.level;
    bool leveledUp = false;

    while (newExp >= expToNextLevel(newLevel) &&
        newLevel < maxLevel(cat.rarity)) {
      newExp -= expToNextLevel(newLevel);
      newLevel++;
      leveledUp = true;
    }

    // 进化检测（仅触发一次，通过 evolved 标记防止重复）
    final evolved = leveledUp && canEvolve(cat.copyWith(level: newLevel));

    return (
      cat: cat.copyWith(level: newLevel, exp: newExp, evolved: cat.evolved || evolved),
      leveledUp: leveledUp,
      evolved: evolved,
    );
  }

  /// 战斗胜利后提高的捕捉率加成
  static double captureRateBonus(int battlesWon) {
    return (battlesWon * 0.03).clamp(0, 0.30);
  }
}
