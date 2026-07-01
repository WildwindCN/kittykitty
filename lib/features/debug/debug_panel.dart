import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../game/models/models.dart';
import '../../game/generator/cat_generator.dart';
import '../../game/battle_engine/battle_engine.dart';
import '../card/collection_provider.dart';
import '../auth/auth_provider.dart';

/// 开发者功能测试面板
///
/// 入口：个人主页 → 连续点击头像 5 次，或直接访问 /debug
class DebugPanel extends ConsumerStatefulWidget {
  const DebugPanel({super.key});

  @override
  ConsumerState<DebugPanel> createState() => _DebugPanelState();
}

class _DebugPanelState extends ConsumerState<DebugPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _log = <String>[];
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addLog(String msg) {
    setState(() {
      _log.add('[${DateTime.now().toString().substring(11, 19)}] $msg');
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cats = ref.watch(collectionProvider).cats;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 功能测试面板'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: '猫咪生成'),
            Tab(text: '对战测试'),
            Tab(text: '卡片预览'),
            Tab(text: '图鉴管理'),
            Tab(text: '日志'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _GeneratorTab(onGenerate: _onGenerate, addLog: _addLog),
                _BattleTab(cats: cats, addLog: _addLog, ref: ref),
                _CardTab(cats: cats, addLog: _addLog),
                _CollectionTab(cats: cats, addLog: _addLog, ref: ref),
                _LogTab(log: _log, scrollController: _scrollController),
              ],
            ),
          ),
          // 状态栏
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white.withAlpha(8),
            child: Row(
              children: [
                _StatusChip('图鉴', '${cats.length}只', Colors.greenAccent),
                const SizedBox(width: 8),
                _StatusChip('认证', ref.watch(authProvider).status.name, Colors.orangeAccent),
                const SizedBox(width: 8),
                _StatusChip('日志', '${_log.length}条', Colors.white38),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onGenerate(Cat cat) {
    // 不await——批量生成时不阻塞UI
    ref.read(collectionProvider.notifier).addCat(cat);
    _addLog('生成: ${cat.name} (${cat.rarity.label} / ${cat.type.label}) CP=${cat.cp}');
  }
}

// ===== 状态标签 =====
class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('$label $value',
          style: TextStyle(color: color, fontSize: 12)),
    );
  }
}

// ===== Tab 1: 猫咪生成器测试 =====
class _GeneratorTab extends StatefulWidget {
  const _GeneratorTab({required this.onGenerate, required this.addLog});
  final void Function(Cat) onGenerate;
  final void Function(String) addLog;

  @override
  State<_GeneratorTab> createState() => _GeneratorTabState();
}

class _GeneratorTabState extends State<_GeneratorTab> {
  Rarity? _selectedRarity;
  CatType? _selectedType;
  int _batchCount = 1;

  final _gen = CatGenerator(random: Random());

  void _generate() {
    final start = DateTime.now();
    for (var i = 0; i < _batchCount; i++) {
      final forcedRarity = _selectedRarity ?? _gen.rollRarity();
      final forcedType = _selectedType ?? _gen.rollType();
      final cat = _gen.generateBaseCat(
        catId: const Uuid().v4(),
        ownerId: 'test',
        imageUrl: 'https://placekitten.com/${200 + i}/${200 + i}',
        latitude: 31.2 + Random().nextDouble() * 0.1,
        longitude: 121.4 + Random().nextDouble() * 0.1,
        forcedRarity: forcedRarity,
        forcedType: forcedType,
      );
      widget.onGenerate(cat);
    }
    final elapsed = DateTime.now().difference(start).inMilliseconds;
    widget.addLog('批量生成 $_batchCount 只猫, 耗时 ${elapsed}ms');
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('稀有度（留空=随机概率）'),
          Wrap(
            spacing: 8,
            children: [
              null,
              ...Rarity.values,
            ].map((r) {
              final selected = _selectedRarity == r;
              return ChoiceChip(
                label: Text(r?.label ?? '随机'),
                selected: selected,
                selectedColor: _rarityColor(r).withAlpha(80),
                onSelected: (_) => setState(() => _selectedRarity = r),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _sectionTitle('属性类型（留空=随机）'),
          Wrap(
            spacing: 8,
            children: [
              null,
              ...CatType.values,
            ].map((t) {
              final selected = _selectedType == t;
              return ChoiceChip(
                label: Text(t?.label ?? '随机'),
                selected: selected,
                selectedColor: Colors.blueAccent.withAlpha(80),
                onSelected: (_) => setState(() => _selectedType = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          _sectionTitle('批量数量'),
          Row(
            children: [
              IconButton.filled(
                onPressed: _batchCount > 1
                    ? () => setState(() => _batchCount--)
                    : null,
                icon: const Icon(Icons.remove, size: 18),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$_batchCount',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              IconButton.filled(
                onPressed: _batchCount < 50
                    ? () => setState(() => _batchCount++)
                    : null,
                icon: const Icon(Icons.add, size: 18),
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () => setState(() => _batchCount = 1),
                child: const Text('重置'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome),
              label: Text('生成 ${_batchCount > 1 ? '$_batchCount只' : ''}猫咪'),
            ),
          ),
          const SizedBox(height: 16),

          // 快速预设
          _sectionTitle('快速预设'),
          ...['普通敏捷猫', '稀有力量猫', '史诗耐力猫', '传说随机猫'].map((preset) {
            Rarity r;
            CatType? t;
            switch (preset) {
              case '普通敏捷猫': r = Rarity.common; t = CatType.agility; break;
              case '稀有力量猫': r = Rarity.rare; t = CatType.strength; break;
              case '史诗耐力猫': r = Rarity.epic; t = CatType.endurance; break;
              default: r = Rarity.legendary; t = null;
            }
            return ListTile(
              dense: true,
              leading: Icon(Icons.pets, color: _rarityColor(r), size: 20),
              title: Text(preset, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              trailing: const Icon(Icons.add_circle_outline, color: Colors.white38, size: 18),
              onTap: () {
                setState(() {
                  _selectedRarity = r;
                  _selectedType = t;
                });
                _generate();
              },
            );
          }),
        ],
      ),
    );
  }

  Color _rarityColor(Rarity? r) {
    return switch (r) {
      Rarity.common => Colors.grey,
      Rarity.rare => const Color(0xFF4FC3F7),
      Rarity.epic => const Color(0xFFCE93D8),
      Rarity.legendary => const Color(0xFFFFD700),
      _ => Colors.white38,
    };
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}

// ===== Tab 2: 对战测试 =====
class _BattleTab extends StatelessWidget {
  const _BattleTab({required this.cats, required this.addLog, required this.ref});
  final List<Cat> cats;
  final void Function(String) addLog;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    if (cats.length < 2) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sports_kabaddi, size: 48, color: Colors.white24),
            const SizedBox(height: 12),
            Text('至少需要 2 只猫才能对战',
                style: TextStyle(color: Colors.white.withAlpha(80))),
            const SizedBox(height: 8),
            Text('先去「猫咪生成」tab 生成一些猫咪吧',
                style: TextStyle(color: Colors.white.withAlpha(40), fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cats.length,
      itemBuilder: (context, i) {
        final a = cats[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _rc(a.rarity).withAlpha(40),
            child: Icon(Icons.pets, color: _rc(a.rarity), size: 20),
          ),
          title: Text(a.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
          subtitle: Text('CP ${a.cp} · Lv.${a.level} · ${a.rarity.label}',
              style: const TextStyle(color: Colors.white38, fontSize: 12)),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.sports_kabaddi, color: Colors.white38, size: 20),
            onSelected: (action) {
              if (action == 'battle_random') {
                _battle(context, a);
              } else if (action == 'vs') {
                final others = cats.where((c) => c.id != a.id).toList();
                if (others.isNotEmpty) {
                  _battle(context, a, opponent: others[Random().nextInt(others.length)]);
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'battle_random', child: Text('对战随机对手')),
              const PopupMenuItem(value: 'vs', child: Text('对战图鉴内另一只猫')),
            ],
          ),
        );
      },
    );
  }

  void _battle(BuildContext context, Cat attacker, {Cat? opponent}) {
    opponent ??= CatGenerator(random: Random()).generateBaseCat(
      catId: const Uuid().v4(),
      ownerId: 'test_opponent',
      imageUrl: 'https://placekitten.com/500/500',
      latitude: 0, longitude: 0,
    );
    final opp = opponent;

    final engine = BattleEngine(seed: Random().nextInt(99999));
    final battle = engine.execute(attacker, opp);

    final won = battle.winnerId == attacker.id;
    final rounds = battle.rounds.length;
    addLog('对战: ${attacker.name}(${attacker.rarity.label}) vs ${opp.name}(${opp.rarity.label}) → '
        '${won ? "胜利" : "败北"} ($rounds回合)');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(
          children: [
            Icon(won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                color: won ? Colors.amber : Colors.white38),
            const SizedBox(width: 8),
            Text(won ? '胜利！' : '败北...',
                style: TextStyle(color: won ? Colors.amber : Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${attacker.name} (CP ${attacker.cp})',
                style: const TextStyle(color: Colors.white70)),
            Text('vs',
                style: TextStyle(color: Colors.white.withAlpha(60), fontSize: 12)),
            Text('${opp.name} (CP ${opp.cp})',
                style: const TextStyle(color: Colors.white70)),
            const Divider(color: Colors.white12),
            Text('$rounds 回合', style: const TextStyle(color: Colors.white38)),
            ...battle.rounds.map((r) {
              final damage = r.actions.fold<int>(0, (s, a) => s + a.damage);
              return Text('  回合${r.roundNumber}: 伤害 $damage',
                  style: TextStyle(color: Colors.white.withAlpha(50), fontSize: 11));
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Color _rc(Rarity r) {
    return switch (r) {
      Rarity.common => Colors.grey,
      Rarity.rare => const Color(0xFF4FC3F7),
      Rarity.epic => const Color(0xFFCE93D8),
      Rarity.legendary => const Color(0xFFFFD700),
    };
  }
}

// ===== Tab 3: 卡片预览 =====
class _CardTab extends StatelessWidget {
  const _CardTab({required this.cats, required this.addLog});
  final List<Cat> cats;
  final void Function(String) addLog;

  @override
  Widget build(BuildContext context) {
    if (cats.isEmpty) {
      return Center(
        child: Text('还没有猫咪，先生成一些吧',
            style: TextStyle(color: Colors.white.withAlpha(60))),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: cats.length,
      itemBuilder: (context, i) {
        final cat = cats[i];
        final color = _rc(cat.rarity);
        return GestureDetector(
          onTap: () {
            addLog('查看卡片: ${cat.name}');
            context.push('/card/${cat.id}');
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withAlpha(50), const Color(0xFF1A1A2E)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withAlpha(100)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.pets, size: 48, color: color.withAlpha(180)),
                const SizedBox(height: 8),
                Text(cat.name,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text('CP ${cat.cp}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 16)),
                Text('${cat.rarity.label} · ${cat.type.label}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _rc(Rarity r) {
    return switch (r) {
      Rarity.common => Colors.grey,
      Rarity.rare => const Color(0xFF4FC3F7),
      Rarity.epic => const Color(0xFFCE93D8),
      Rarity.legendary => const Color(0xFFFFD700),
    };
  }
}

// ===== Tab 4: 图鉴管理 =====
class _CollectionTab extends StatelessWidget {
  const _CollectionTab({required this.cats, required this.addLog, required this.ref});
  final List<Cat> cats;
  final void Function(String) addLog;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计概览
          _sectionTitle('图鉴统计'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _countBadge('总计', cats.length, Colors.white),
                _countBadge('普通', cats.where((c) => c.rarity == Rarity.common).length, Colors.grey),
                _countBadge('稀有', cats.where((c) => c.rarity == Rarity.rare).length, const Color(0xFF4FC3F7)),
                _countBadge('史诗', cats.where((c) => c.rarity == Rarity.epic).length, const Color(0xFFCE93D8)),
                _countBadge('传说', cats.where((c) => c.rarity == Rarity.legendary).length, const Color(0xFFFFD700)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _sectionTitle('稀有度分布'),
          ...Rarity.values.map((r) {
            final count = cats.where((c) => c.rarity == r).length;
            final pct = cats.isEmpty ? 0.0 : count / cats.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  SizedBox(
                      width: 40,
                      child: Text(r.label,
                          style: TextStyle(
                              color: _rc(r), fontSize: 12, fontWeight: FontWeight.w600))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 12,
                        color: _rc(r),
                        backgroundColor: _rc(r).withAlpha(30),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                      width: 50,
                      child: Text('$count只 (${(pct * 100).round()}%)',
                          style: const TextStyle(color: Colors.white38, fontSize: 11))),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),
          _sectionTitle('最高 CP 排名'),
          if (cats.isNotEmpty) ...[
            for (final c in (cats.toList()..sort((a, b) => b.cp.compareTo(a.cp))).take(5))
              ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: _rc(c.rarity).withAlpha(40),
                  child: Icon(Icons.pets, color: _rc(c.rarity), size: 16),
                ),
                title: Text(c.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                trailing: Text('CP ${c.cp}',
                    style: TextStyle(color: _rc(c.rarity), fontWeight: FontWeight.bold)),
              ),
          ],

          const SizedBox(height: 16),
          _sectionTitle('操作'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: cats.isEmpty ? null : () {
                    final count = cats.length;
                    ref.read(collectionProvider.notifier).clearAll();
                    addLog('清空图鉴: 移除 $count 只猫');
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('清空图鉴', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _countBadge(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }

  Color _rc(Rarity r) {
    return switch (r) {
      Rarity.common => Colors.grey,
      Rarity.rare => const Color(0xFF4FC3F7),
      Rarity.epic => const Color(0xFFCE93D8),
      Rarity.legendary => const Color(0xFFFFD700),
    };
  }
}

// ===== Tab 5: 日志 =====
class _LogTab extends StatelessWidget {
  const _LogTab({required this.log, required this.scrollController});
  final List<String> log;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    if (log.isEmpty) {
      return Center(
        child: Text('操作日志将显示在这里',
            style: TextStyle(color: Colors.white.withAlpha(40))),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: log.length,
      itemBuilder: (context, i) {
        final msg = log[i];
        Color color = Colors.white54;
        if (msg.contains('胜利')) color = Colors.amber;
        if (msg.contains('败北')) color = Colors.redAccent;
        if (msg.contains('传说')) color = const Color(0xFFFFD700);
        if (msg.contains('史诗')) color = const Color(0xFFCE93D8);
        if (msg.contains('生成:')) color = Colors.greenAccent;
        if (msg.contains('批量')) color = Colors.cyanAccent;

        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            msg,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        );
      },
    );
  }
}
