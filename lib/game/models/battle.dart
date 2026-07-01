import 'cat.dart';
import 'skill.dart';

enum BattleState {
  pending,    // 等待开始
  active,     // 进行中
  finished,   // 已结束
}

class Battle {
  const Battle({
    required this.id,
    required this.attacker,
    required this.defender,
    this.state = BattleState.pending,
    this.rounds = const [],
    this.winnerId,
    this.seed = 0,
    this.startedAt,
    this.finishedAt,
  });

  final String id;
  final Cat attacker;
  final Cat defender;
  final BattleState state;
  final List<BattleRound> rounds;
  final String? winnerId;
  final int seed;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  int get currentRound => rounds.length;
  bool get isFinished => state == BattleState.finished;

  static const maxRounds = 10;
}

class BattleRound {
  const BattleRound({
    required this.roundNumber,
    required this.actions,
  });

  final int roundNumber;
  final List<BattleAction> actions;
}

class BattleAction {
  const BattleAction({
    required this.actorId,
    required this.skill,
    required this.damage,
    required this.targetHpAfter,
    this.isCrit = false,
    this.isDodged = false,
    this.isLifeSkill = false,
    this.lifeSkillFlavor = '',
    this.statEffects = const [],
  });

  final String actorId;
  final BattleSkill skill;
  final int damage;
  final int targetHpAfter;
  final bool isCrit;
  final bool isDodged;
  final bool isLifeSkill;
  final String lifeSkillFlavor; // 卖萌文字
  final List<StatEffect> statEffects;
}

class StatEffect {
  const StatEffect({
    required this.stat,
    required this.modifier,
    required this.remainingTurns,
    required this.sourceId,
  });

  final Stat stat;
  final double modifier;
  final int remainingTurns;
  final String sourceId;
}

enum Stat { atk, def, spd }
