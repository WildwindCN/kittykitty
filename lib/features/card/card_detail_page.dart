import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../game/models/models.dart';
import 'collection_provider.dart';

/// 猫咪卡片详情页 — 游戏王风格正面，翻转留空背面
class CardDetailPage extends ConsumerStatefulWidget {
  const CardDetailPage({super.key, required this.catId});
  final String catId;

  @override
  ConsumerState<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends ConsumerState<CardDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnim;
  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flip() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() => _isFront = !_isFront);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(collectionProvider.notifier);
    final cat = notifier.getById(widget.catId);
    if (cat == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('猫咪详情')),
        body: const Center(child: Text('猫咪不存在')),
      );
    }

    final rarityColor = Color(cat.rarity.colorValue);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      appBar: AppBar(
        title: Text(cat.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip),
            onPressed: _flip,
            tooltip: '翻转',
          ),
          IconButton(
            icon: const Icon(Icons.sports_kabaddi),
            onPressed: () => context.push('/battle/${cat.id}'),
            tooltip: '对战',
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          if (d.primaryVelocity != null && d.primaryVelocity!.abs() > 100) _flip();
        },
        child: Center(
          child: AnimatedBuilder(
            animation: _flipAnim,
            builder: (context, child) {
              final showFront = _flipAnim.value <= 0.5;
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(_flipAnim.value * 3.14159),
                child: showFront
                    ? _buildFront(cat, rarityColor, theme)
                    : Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()..rotateY(3.14159),
                        child: _buildBack(rarityColor, theme),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ===== 正面：游戏王风格卡片 =====

  Widget _buildFront(Cat cat, Color rarityColor, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rarityColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withAlpha(50),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ===== 顶部名字栏 =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [rarityColor.withAlpha(80), rarityColor.withAlpha(20)],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                border: Border(
                  bottom: BorderSide(color: rarityColor.withAlpha(100), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      cat.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: rarityColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: rarityColor.withAlpha(40),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: rarityColor.withAlpha(120)),
                    ),
                    child: Text(
                      cat.rarity.label,
                      style: TextStyle(
                        color: rarityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ===== 猫咪图像区域 =====
            Container(
              height: 180,
              margin: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: rarityColor.withAlpha(50), width: 1),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Icon(
                      Icons.pets,
                      size: 80,
                      color: rarityColor.withAlpha(60),
                    ),
                  ),
                  // 四角装饰
                  ...['↖', '↗', '↙', '↘'].map((c) => Positioned(
                        top: c.contains('↗') || c.contains('↖') ? 6 : null,
                        bottom: c.contains('↙') || c.contains('↘') ? 6 : null,
                        left: c.contains('↖') || c.contains('↙') ? 10 : null,
                        right: c.contains('↗') || c.contains('↘') ? 10 : null,
                        child: Text(c,
                            style: TextStyle(
                                color: rarityColor.withAlpha(40), fontSize: 16)),
                      )),
                  // CP 大数字
                  Positioned(
                    right: 12,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('CP',
                            style: TextStyle(
                                color: rarityColor.withAlpha(120), fontSize: 10)),
                        Text('${cat.cp}',
                            style: TextStyle(
                                color: rarityColor,
                                fontSize: 26,
                                fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ===== 类型 + 等级行 =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _infoTag(cat.type.label, Colors.white38, Icons.category),
                  const SizedBox(width: 8),
                  _infoTag('Lv.${cat.level}', Colors.white38, Icons.trending_up),
                  const Spacer(),
                  _infoTag('${cat.battleSkills.length + cat.lifeSkills.length}技能',
                      rarityColor.withAlpha(150), Icons.auto_fix_high),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ===== 属性条 =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _compactStatRow('HP', cat.hp, cat.baseHp + 60, Colors.redAccent),
                  const SizedBox(height: 4),
                  _compactStatRow('ATK', cat.atk, cat.baseAtk + 50, Colors.orangeAccent),
                  const SizedBox(height: 4),
                  _compactStatRow('DEF', cat.def, cat.baseDef + 50, Colors.blueAccent),
                  const SizedBox(height: 4),
                  _compactStatRow('SPD', cat.spd, cat.baseSpd + 50, Colors.greenAccent),
                  const SizedBox(height: 4),
                  _compactStatRow('CRIT', (cat.crit * 100).round(), 20, Colors.purpleAccent,
                      suffix: '%'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ===== 分割线 =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Divider(color: rarityColor.withAlpha(60), height: 1),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text('技 能',
                        style: TextStyle(
                            color: rarityColor.withAlpha(120), fontSize: 11)),
                  ),
                  Expanded(
                    child: Divider(color: rarityColor.withAlpha(60), height: 1),
                  ),
                ],
              ),
            ),

            // ===== 战斗技能 =====
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Column(
                children: cat.battleSkills.map((s) {
                  final icon = switch (s.type) {
                    SkillType.attack => Icons.flash_on,
                    SkillType.defense => Icons.shield,
                    SkillType.control => Icons.visibility,
                  };
                  final typeColor = switch (s.type) {
                    SkillType.attack => Colors.orangeAccent,
                    SkillType.defense => Colors.blueAccent,
                    SkillType.control => Colors.purpleAccent,
                  };
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(icon, size: 14, color: typeColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s.name,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                        ),
                        Text(
                          '威力${s.power}',
                          style: TextStyle(
                              color: typeColor.withAlpha(150), fontSize: 11),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

            // ===== 生活技能 =====
            if (cat.lifeSkills.isNotEmpty) ...[
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, size: 12, color: Colors.pinkAccent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cat.lifeSkills.map((s) => s.name).join(' · '),
                        style: const TextStyle(
                            color: Colors.pinkAccent, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ===== 底部稀有度色条 =====
            Container(
              width: double.infinity,
              height: 6,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [rarityColor, rarityColor.withAlpha(40)],
                ),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== 背面：留空（仅卡背花纹）=====

  Widget _buildBack(Color rarityColor, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rarityColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: rarityColor.withAlpha(50),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.pets, size: 64, color: rarityColor.withAlpha(80)),
              const SizedBox(height: 12),
              Text(
                'KittyKitty',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: rarityColor.withAlpha(100),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 100,
                height: 1,
                color: rarityColor.withAlpha(60),
              ),
              const SizedBox(height: 20),
              Icon(Icons.touch_app, size: 28, color: Colors.white.withAlpha(30)),
              const SizedBox(height: 8),
              Text('点击或滑动返回正面',
                  style: TextStyle(
                      color: Colors.white.withAlpha(30), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // ===== 紧凑属性行 =====
  Widget _compactStatRow(
      String label, int value, int max, Color color,
      {String suffix = ''}) {
    final ratio = (value / max.clamp(1, 9999)).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: color,
              backgroundColor: color.withAlpha(25),
            ),
          ),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: Text('$value$suffix',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              textAlign: TextAlign.right),
        ),
      ],
    );
  }

  // ===== 信息标签 =====
  Widget _infoTag(String text, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(text,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
