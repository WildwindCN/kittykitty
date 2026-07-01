import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../game/models/models.dart';
import '../../services/cat_service.dart';
import '../auth/auth_provider.dart';

/// 图鉴状态管理 — 云端同步
class CollectionState {
  final List<Cat> cats;
  final bool isLoading;
  final String? error;

  const CollectionState({this.cats = const [], this.isLoading = false, this.error});

  CollectionState copyWith({List<Cat>? cats, bool? isLoading, String? error}) {
    return CollectionState(
      cats: cats ?? this.cats,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class CollectionNotifier extends StateNotifier<CollectionState> {
  CollectionNotifier(this._catService) : super(const CollectionState(isLoading: true)) {
    _loadFromCloud();
  }

  final CatService _catService;

  Future<void> _loadFromCloud() async {
    final resp = await _catService.getMyCats();
    if (resp.isSuccess && resp.data != null) {
      final cats = resp.data!.map((json) => _catFromJson(json)).toList();
      state = CollectionState(cats: cats);
    } else {
      state = state.copyWith(isLoading: false, error: resp.message ?? '加载失败');
    }
  }

  /// 刷新
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadFromCloud();
  }

  /// 添加猫咪（本地 + 云端同步）
  Future<bool> addCat(Cat cat) async {
    // 先乐观更新本地
    state = state.copyWith(cats: [...state.cats, cat]);

    // 同步到云端
    final resp = await _catService.captureCat(_catToJson(cat));
    if (!resp.isSuccess) {
      // 云端同步失败，回滚
      state = state.copyWith(
        cats: state.cats.where((c) => c.id != cat.id).toList(),
        error: resp.message ?? '同步失败',
      );
      return false;
    }
    // 用服务器 ID 更新本地数据
    if (resp.data != null) {
      final serverCatId = resp.data;
      final updatedCat = cat.copyWith(id: serverCatId);
      state = state.copyWith(
        cats: state.cats.map((c) => c.id == cat.id ? updatedCat : c).toList(),
      );
    }
    return true;
  }

  /// 添加猫咪（带完整数据，包含 featureVector）
  Future<bool> addCatWithData(Map<String, dynamic> catJson) async {
    final resp = await _catService.captureCat(catJson);
    if (!resp.isSuccess) {
      state = state.copyWith(error: resp.message ?? '同步失败');
      return false;
    }
    // 从云端重新加载
    await refresh();
    return true;
  }

  Cat? getById(String id) {
    try {
      return state.cats.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearAll() {
    state = state.copyWith(cats: []);
  }

  // === JSON 转换 ===

  Cat _catFromJson(Map<String, dynamic> json) {
    return Cat(
      id: json['_id'] as String? ?? json['id'] as String,
      ownerId: json['userId'] as String? ?? json['ownerId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rarity: _parseRarity(json['rarity'] as String?),
      type: _parseType(json['type'] as String?),
      baseHp: (json['baseHp'] as num?)?.toInt() ?? (json['hp'] as num?)?.toInt() ?? 80,
      baseAtk: (json['baseAtk'] as num?)?.toInt() ?? (json['atk'] as num?)?.toInt() ?? 50,
      baseDef: (json['baseDef'] as num?)?.toInt() ?? (json['def'] as num?)?.toInt() ?? 40,
      baseSpd: (json['baseSpd'] as num?)?.toInt() ?? (json['spd'] as num?)?.toInt() ?? 50,
      baseCrit: (json['baseCrit'] as num?)?.toDouble() ?? (json['crit'] as num?)?.toDouble() ?? 0.05,
      battleSkills: _parseBattleSkills(json['battleSkills']),
      lifeSkills: _parseLifeSkills(json['lifeSkills']),
      level: (json['level'] as num?)?.toInt() ?? 1,
      exp: (json['exp'] as num?)?.toInt() ?? 0,
      imageUrl: json['imageUrl'] as String? ?? '',
      cardImageUrl: json['cardImageUrl'] as String?,
      captureLocation: _parseLocation(json['captureLocation']),
      capturedAt: json['capturedAt'] != null
          ? DateTime.tryParse(json['capturedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      totalBattles: (json['totalBattles'] as num?)?.toInt() ?? 0,
      totalWins: (json['totalWins'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> _catToJson(Cat cat) => {
        'name': cat.name,
        'rarity': cat.rarity.name,
        'type': cat.type.name,
        'baseHp': cat.baseHp,
        'baseAtk': cat.baseAtk,
        'baseDef': cat.baseDef,
        'baseSpd': cat.baseSpd,
        'baseCrit': cat.baseCrit,
        'battleSkills': cat.battleSkills.map((s) => {
              'id': s.id, 'name': s.name, 'type': s.type.name,
              'power': s.power, 'accuracy': s.accuracy, 'description': s.description,
        }).toList(),
        'lifeSkills': cat.lifeSkills.map((s) => {
              'id': s.id, 'name': s.name, 'effect': s.effect.name,
              'value': s.value, 'description': s.description,
        }).toList(),
        'level': cat.level, 'exp': cat.exp,
        'imageUrl': cat.imageUrl,
        'captureLocation': {
          'latitude': cat.captureLocation.latitude,
          'longitude': cat.captureLocation.longitude,
        },
  };

  Rarity _parseRarity(String? s) {
    return Rarity.values.firstWhere((r) => r.name == s, orElse: () => Rarity.common);
  }

  CatType _parseType(String? s) {
    return CatType.values.firstWhere((t) => t.name == s, orElse: () => CatType.agility);
  }

  CatLocation _parseLocation(dynamic loc) {
    if (loc == null) return const CatLocation(latitude: 0, longitude: 0);
    if (loc is Map) {
      final coords = loc['coordinates'] as List?;
      if (coords != null && coords.length == 2) {
        return CatLocation(
          longitude: (coords[0] as num).toDouble(),
          latitude: (coords[1] as num).toDouble(),
        );
      }
      return CatLocation(
        latitude: (loc['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (loc['longitude'] as num?)?.toDouble() ?? 0,
      );
    }
    return const CatLocation(latitude: 0, longitude: 0);
  }

  List<BattleSkill> _parseBattleSkills(dynamic skills) {
    if (skills == null || skills is! List) return [];
    return skills.map((s) => BattleSkill(
      id: s['id'] as String? ?? '',
      name: s['name'] as String? ?? '',
      type: SkillType.values.firstWhere((t) => t.name == (s['type'] as String?),
          orElse: () => SkillType.attack),
      power: (s['power'] as num?)?.toInt() ?? 0,
      accuracy: (s['accuracy'] as num?)?.toDouble() ?? 1.0,
      description: s['description'] as String? ?? '',
    )).toList();
  }

  List<LifeSkill> _parseLifeSkills(dynamic skills) {
    if (skills == null || skills is! List) return [];
    return skills.map((s) => LifeSkill(
      id: s['id'] as String? ?? '',
      name: s['name'] as String? ?? '',
      effect: LifeSkillEffect.values.firstWhere((e) => e.name == (s['effect'] as String?),
          orElse: () => LifeSkillEffect.goldBonus),
      value: (s['value'] as num?)?.toDouble() ?? 0,
      description: s['description'] as String? ?? '',
    )).toList();
  }
}

final collectionProvider =
    StateNotifierProvider<CollectionNotifier, CollectionState>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return CollectionNotifier(CatService(apiClient: apiClient));
});
