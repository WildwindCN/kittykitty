import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../game/battle_engine/battle_engine.dart';
import '../../game/generator/cat_generator.dart';
import '../../game/models/models.dart';
import '../card/collection_provider.dart';
import 'package:uuid/uuid.dart';

/// 对战动画页 — 逐步回合制展示
class BattlePage extends ConsumerStatefulWidget {
  const BattlePage({super.key, required this.catId});
  final String catId;

  @override
  ConsumerState<BattlePage> createState() => _BattlePageState();
}

class _BattlePageState extends ConsumerState<BattlePage>
    with TickerProviderStateMixin {
  late Battle _battle;
  late Cat _myCat;
  late Cat _opponent;

  // 当前播放到的 action 索引 (展开所有 action)
  late List<_ActionDisplay> _allActions;
  int _currentActionIndex = -1;
  bool _isFinished = false;

  // 飘字动画
  final List<_FloatingText> _floatingTexts = [];
  String? _activeActorId;

  // HP 动画值
  late AnimationController _hpAnimController;
  late Animation<double> _atkHpAnim;
  late Animation<double> _defHpAnim;

  int _displayAtkHp = 0;
  int _displayDefHp = 0;

  @override
  void initState() {
    super.initState();
    _hpAnimController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _startBattle();
  }

  @override
  void dispose() {
    _hpAnimController.dispose();
    super.dispose();
  }

  void _startBattle() {
    final notifier = ref.read(collectionProvider.notifier);
    final myCat = notifier.getById(widget.catId);
    if (myCat == null) return;
    _myCat = myCat;

    // 优先从图鉴中选对手（排除自己），否则生成野生猫
    final collection = ref.read(collectionProvider).cats;
    final candidates = collection.where((c) => c.id != widget.catId).toList();
    if (candidates.isNotEmpty) {
      _opponent = candidates[Random().nextInt(candidates.length)];
    } else {
      final generator = CatGenerator(random: Random());
      _opponent = generator.generateBaseCat(
        catId: const Uuid().v4(),
        ownerId: 'wild',
        imageUrl: 'https://placekitten.com/401/401',
        latitude: myCat.captureLocation.latitude,
        longitude: myCat.captureLocation.longitude,
      );
    }

    final engine = BattleEngine(seed: Random().nextInt(99999));
    _battle = engine.execute(myCat, _opponent);

    // 展开所有 actions 为平铺列表
    _allActions = [];
    for (final round in _battle.rounds) {
      for (final action in round.actions) {
        _allActions.add(_ActionDisplay(
          roundNumber: round.roundNumber,
          action: action,
          isAttacker: action.actorId == _battle.attacker.id,
        ));
      }
    }

    _displayAtkHp = _myCat.hp;
    _displayDefHp = _opponent.hp;

    _animateNextAction();
  }

  Future<void> _animateNextAction() async {
    if (_currentActionIndex >= _allActions.length - 1) {
      await Future.delayed(const Duration(milliseconds: 600));
      _finishBattle();
      return;
    }

    // 第一步无延迟，后续步骤间隔 1.5s
    if (_currentActionIndex >= 0) {
      await Future.delayed(const Duration(milliseconds: 1500));
    }
    if (!mounted) return;

    _currentActionIndex++;

    final display = _allActions[_currentActionIndex];
    final action = display.action;

    setState(() {
      _activeActorId = action.actorId;
    });

    // 飘字
    if (action.damage > 0) {
      _floatingTexts.add(_FloatingText(
        text: action.isCrit ? '-${action.damage}💥' : '-${action.damage}',
        color: action.isCrit ? Colors.amber : Colors.redAccent,
        isRight: !display.isAttacker,
      ));
    } else if (action.isDodged) {
      _floatingTexts.add(_FloatingText(
        text: 'MISS', color: Colors.white38, isRight: !display.isAttacker,
      ));
    } else if (action.isLifeSkill) {
      _floatingTexts.add(_FloatingText(
        text: '💕', color: Colors.pinkAccent, isRight: display.isAttacker,
      ));
    }

    // 清理飘字
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _floatingTexts.clear());
    });

    // 目标 HP
    final targetAtkHp = _getHpAfterAction(_myCat, _currentActionIndex, isAttacker: true);
    final targetDefHp = _getHpAfterAction(_opponent, _currentActionIndex, isAttacker: false);

    // HP 动画 — 先 await 动画完成再进入下一步
    _hpAnimController.reset();
    _atkHpAnim = Tween<double>(
      begin: _displayAtkHp.toDouble(),
      end: targetAtkHp.toDouble(),
    ).animate(CurvedAnimation(
      parent: _hpAnimController,
      curve: Curves.easeOut,
    ));
    _defHpAnim = Tween<double>(
      begin: _displayDefHp.toDouble(),
      end: targetDefHp.toDouble(),
    ).animate(CurvedAnimation(
      parent: _hpAnimController,
      curve: Curves.easeOut,
    ));

    final listener = () {
      if (mounted) {
        setState(() {
          _displayAtkHp = _atkHpAnim.value.round();
          _displayDefHp = _defHpAnim.value.round();
        });
      }
    };
    _hpAnimController.addListener(listener);

    try {
      await _hpAnimController.forward();
    } finally {
      _hpAnimController.removeListener(listener);
    }

    // 确保最终值精准
    if (mounted) {
      setState(() {
        _displayAtkHp = targetAtkHp;
        _displayDefHp = targetDefHp;
      });
    }

    // 继续下一步
    _animateNextAction();
  }

  void _finishBattle() async {
    setState(() {
      _isFinished = true;
      _activeActorId = null;
    });

    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    final won = _battle.winnerId == _myCat.id;
    context.pushReplacement('/battle/result/${widget.catId}', extra: {
      'won': won,
      'battle': _battle,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMyTurn = _activeActorId == _myCat.id;
    final isOppTurn = _activeActorId == _opponent.id;

    // 当前 action
    final currentDisplay = _currentActionIndex >= 0 &&
            _currentActionIndex < _allActions.length
        ? _allActions[_currentActionIndex]
        : null;
    final currentAction = currentDisplay?.action;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        title: const Text('⚔ 对战'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // === 对战双方 ===
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // 我方
                    Expanded(
                      child: _CatPanel(
                        cat: _myCat,
                        currentHp: _displayAtkHp,
                        isAlly: true,
                        isActive: isMyTurn,
                        floatingTexts: _floatingTexts.where((f) => !f.isRight).toList(),
                        theme: theme,
                      ),
                    ),
                    // VS 区域
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'VS',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (currentAction != null)
                          _SkillBadge(action: currentAction),
                      ],
                    ),
                    // 对手
                    Expanded(
                      child: _CatPanel(
                        cat: _opponent,
                        currentHp: _displayDefHp,
                        isAlly: false,
                        isActive: isOppTurn,
                        floatingTexts: _floatingTexts.where((f) => f.isRight).toList(),
                        theme: theme,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // === 回合信息 ===
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _StatBadge(
                    label: '回合',
                    value: currentDisplay != null
                        ? '${currentDisplay.roundNumber}/${_battle.rounds.length}'
                        : '--',
                    icon: Icons.timer,
                    theme: theme,
                  ),
                  const Spacer(),
                  _StatBadge(
                    label: '我方HP',
                    value: '$_displayAtkHp',
                    icon: Icons.favorite,
                    theme: theme,
                    color: Colors.redAccent,
                  ),
                  const Spacer(),
                  _StatBadge(
                    label: '敌方HP',
                    value: '$_displayDefHp',
                    icon: Icons.favorite_border,
                    theme: theme,
                    color: Colors.redAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // === 战斗日志 ===
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _currentActionIndex + 1,
                  itemBuilder: (context, i) {
                    if (i < 0 || i >= _allActions.length) return const SizedBox.shrink();
                    final d = _allActions[i];
                    final a = d.action;
                    final name =
                        d.isAttacker ? _myCat.name : _opponent.name;
                    final isCurrent = i == _currentActionIndex;

                    Color textColor;
                    if (a.isLifeSkill) {
                      textColor = Colors.pinkAccent;
                    } else if (a.isDodged) {
                      textColor = Colors.white38;
                    } else if (a.damage > 0) {
                      textColor = a.isCrit ? Colors.amber : Colors.orangeAccent;
                    } else {
                      textColor = Colors.white54;
                    }

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isCurrent
                            ? Colors.white.withAlpha(10)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'R${d.roundNumber}',
                            style: TextStyle(
                              color: Colors.white.withAlpha(30),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (a.isLifeSkill)
                            const Icon(Icons.favorite, size: 12, color: Colors.pinkAccent)
                          else if (a.skill.type == SkillType.attack)
                            const Icon(Icons.flash_on, size: 12, color: Colors.orangeAccent)
                          else if (a.skill.type == SkillType.defense)
                            const Icon(Icons.shield, size: 12, color: Colors.blueAccent)
                          else
                            const Icon(Icons.visibility, size: 12, color: Colors.purpleAccent),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: name,
                                    style: TextStyle(
                                      color: d.isAttacker
                                          ? theme.colorScheme.primary
                                          : Colors.white70,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: a.isLifeSkill
                                        ? ' ${a.lifeSkillFlavor}'
                                        : a.isDodged
                                            ? ' ${a.skill.name} → MISS'
                                            : a.damage > 0
                                                ? ' ${a.skill.name} → ${a.damage}${a.isCrit ? "💥" : ""}'
                                                : ' ${a.skill.name}',
                                    style: TextStyle(color: textColor, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),

            // 进度
            if (!_isFinished)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(
                    begin: 0,
                    end: (_currentActionIndex + 1) / _allActions.length,
                  ),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, value, child) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: value,
                        minHeight: 3,
                        color: theme.colorScheme.primary,
                        backgroundColor: theme.colorScheme.primary.withAlpha(30),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _getHpAfterAction(Cat cat, int actionIndex, {required bool isAttacker}) {
    var hp = cat.hp;
    for (var i = 0; i <= actionIndex; i++) {
      final d = _allActions[i];
      final hitsThis = (isAttacker && d.action.actorId != cat.id) ||
          (!isAttacker && d.action.actorId == cat.id);
      if (hitsThis) {
        hp = (hp - d.action.damage).clamp(0, 9999);
      }
    }
    return hp;
  }
}

// ===== 辅助类 =====

class _ActionDisplay {
  final int roundNumber;
  final BattleAction action;
  final bool isAttacker;
  const _ActionDisplay({
    required this.roundNumber,
    required this.action,
    required this.isAttacker,
  });
}

class _FloatingText {
  final String text;
  final Color color;
  final bool isRight;
  const _FloatingText({required this.text, required this.color, required this.isRight});
}

// ===== 猫咪面板 =====
class _CatPanel extends StatelessWidget {
  const _CatPanel({
    required this.cat,
    required this.currentHp,
    required this.isAlly,
    required this.isActive,
    required this.floatingTexts,
    required this.theme,
  });

  final Cat cat;
  final int currentHp;
  final bool isAlly;
  final bool isActive;
  final List<_FloatingText> floatingTexts;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final hpPercent = (currentHp / cat.hp.clamp(1, 9999)).clamp(0.0, 1.0);
    final hpColor = hpPercent > 0.5
        ? Colors.greenAccent
        : hpPercent > 0.25
            ? Colors.orangeAccent
            : Colors.redAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? theme.colorScheme.primary.withAlpha(150)
              : Colors.white.withAlpha(20),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withAlpha(40),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 图标
              AnimatedScale(
                duration: const Duration(milliseconds: 200),
                scale: isActive ? 1.15 : 1.0,
                child: Icon(
                  Icons.pets,
                  size: 52,
                  color: isAlly
                      ? theme.colorScheme.primary
                      : Colors.white.withAlpha(80),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                cat.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                'Lv.${cat.level} · ${cat.rarity.label}',
                style: TextStyle(
                  color: Color(cat.rarity.colorValue).withAlpha(180),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 8),
              // HP 条
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: hpPercent, end: hpPercent),
                    duration: const Duration(milliseconds: 400),
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 10,
                        color: hpColor,
                        backgroundColor: hpColor.withAlpha(30),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$currentHp / ${cat.hp}',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
              // 技能列表
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                alignment: WrapAlignment.center,
                children: [
                  ...cat.battleSkills.take(3).map((s) => _SkillChip(
                        name: s.name,
                        color: s.type == SkillType.attack
                            ? Colors.orangeAccent
                            : s.type == SkillType.defense
                                ? Colors.blueAccent
                                : Colors.purpleAccent,
                      )),
                  if (cat.lifeSkills.isNotEmpty)
                    _SkillChip(
                      name: cat.lifeSkills.first.name,
                      color: Colors.pinkAccent,
                    ),
                ],
              ),
            ],
          ),
          // 飘字层
          ...floatingTexts.map((ft) => Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: -30),
                  duration: const Duration(milliseconds: 1000),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: (1 - value.abs() / 30).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, value),
                        child: Text(
                          ft.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: ft.color,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              )),
        ],
      ),
    );
  }
}

// ===== 技能标签 =====
class _SkillChip extends StatelessWidget {
  const _SkillChip({required this.name, required this.color});
  final String name;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80), width: 0.5),
      ),
      child: Text(name, style: TextStyle(color: color, fontSize: 9)),
    );
  }
}

// ===== 回合统计 =====
class _StatBadge extends StatelessWidget {
  const _StatBadge({
    required this.label, required this.value,
    required this.icon, required this.theme, this.color,
  });
  final String label, value;
  final IconData icon;
  final ThemeData theme;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? theme.colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(width: 4),
        Text(value,
            style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 14)),
      ],
    );
  }
}

// ===== 当前技能展示 =====
class _SkillBadge extends StatelessWidget {
  const _SkillBadge({required this.action});
  final BattleAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.isLifeSkill
        ? Colors.pinkAccent
        : action.skill.type == SkillType.attack
            ? Colors.orangeAccent
            : action.skill.type == SkillType.defense
                ? Colors.blueAccent
                : Colors.purpleAccent;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: ValueKey('${action.actorId}_${action.skill.name}'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (action.isLifeSkill)
              const Icon(Icons.favorite, size: 20, color: Colors.pinkAccent)
            else if (action.skill.type == SkillType.attack)
              const Icon(Icons.flash_on, size: 20, color: Colors.orangeAccent)
            else if (action.skill.type == SkillType.defense)
              const Icon(Icons.shield, size: 20, color: Colors.blueAccent)
            else
              const Icon(Icons.visibility, size: 20, color: Colors.purpleAccent),
            const SizedBox(height: 2),
            Text(
              action.skill.name,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
