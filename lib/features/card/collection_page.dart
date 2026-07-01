import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../game/models/models.dart';
import 'collection_provider.dart';

/// 图鉴页 — 已收集猫咪的网格列表
class CollectionPage extends ConsumerWidget {
  const CollectionPage({super.key});

  Color _rarityColor(Rarity rarity) {
    return switch (rarity) {
      Rarity.common => Colors.grey,
      Rarity.rare => const Color(0xFF4FC3F7),
      Rarity.epic => const Color(0xFFCE93D8),
      Rarity.legendary => const Color(0xFFFFD700),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cats = ref.watch(collectionProvider).cats;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('猫咪图鉴 (${cats.length})'),
      ),
      body: cats.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.collections_bookmark,
                      size: 80, color: Colors.white.withAlpha(60)),
                  const SizedBox(height: 16),
                  Text(
                    '还没有收集到猫咪',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white54),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '出门拍摄你的第一只猫咪吧！',
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white30),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.75,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: cats.length,
              itemBuilder: (context, index) {
                final cat = cats[index];
                final color = _rarityColor(cat.rarity);

                return GestureDetector(
                  onTap: () => context.push('/card/${cat.id}'),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          color.withAlpha(40),
                          const Color(0xFF1A1A2E),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withAlpha(100), width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pets, size: 56, color: color.withAlpha(150)),
                        const SizedBox(height: 8),
                        Text(
                          cat.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'CP ${cat.cp}',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Lv.${cat.level} · ${cat.rarity.label}',
                          style: TextStyle(
                            color: Colors.white.withAlpha(100),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
