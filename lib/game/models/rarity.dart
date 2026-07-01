enum Rarity {
  common('普通', 1.0),
  rare('稀有', 1.3),
  epic('史诗', 1.7),
  legendary('传说', 2.2);

  const Rarity(this.label, this.cpMultiplier);

  final String label;
  final double cpMultiplier;

  /// 捕捉概率分布: 普通 60% / 稀有 25% / 史诗 12% / 传说 3%
  static const captureWeights = [0.60, 0.25, 0.12, 0.03];
}

/// Rarity 扩展 — 颜色等 UI 属性
extension RarityColor on Rarity? {
  int get colorValue {
    return switch (this) {
      Rarity.common => 0xFF9E9E9E,
      Rarity.rare => 0xFF4FC3F7,
      Rarity.epic => 0xFFCE93D8,
      Rarity.legendary => 0xFFFFD700,
      _ => 0xFF9E9E9E,
    };
  }
}

enum CatType {
  agility('敏捷'),
  strength('力量'),
  endurance('耐力');

  const CatType(this.label);
  final String label;

  /// 属性克制: 敏捷→力量→耐力→敏捷
  bool isStrongAgainst(CatType other) {
    return (this == agility && other == strength) ||
        (this == strength && other == endurance) ||
        (this == endurance && other == agility);
  }
}
