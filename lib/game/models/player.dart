import '../models/cat.dart'; // ignore: unused_import

class Player {
  const Player({
    required this.id,
    this.nickname = '',
    this.avatarUrl,
    this.phone,
    this.wechatOpenId,
    required this.createdAt,
    this.totalCatches = 0,
    this.totalBattles = 0,
    this.totalWins = 0,
    this.rank = 0,
  });

  final String id;
  final String nickname;
  final String? avatarUrl;
  final String? phone;
  final String? wechatOpenId;
  final DateTime createdAt;
  final int totalCatches;
  final int totalBattles;
  final int totalWins;
  final int rank;

  Player copyWith({
    String? nickname,
    String? avatarUrl,
    int? totalCatches,
    int? totalBattles,
    int? totalWins,
    int? rank,
  }) {
    return Player(
      id: id,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      wechatOpenId: wechatOpenId ?? this.wechatOpenId,
      createdAt: createdAt,
      totalCatches: totalCatches ?? this.totalCatches,
      totalBattles: totalBattles ?? this.totalBattles,
      totalWins: totalWins ?? this.totalWins,
      rank: rank ?? this.rank,
    );
  }
}
