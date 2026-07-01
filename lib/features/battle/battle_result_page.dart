import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../card/collection_provider.dart';

/// 对战结果页 + 经验结算
class BattleResultPage extends ConsumerWidget {
  const BattleResultPage({super.key, required this.catId});

  final String catId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
    final won = extra?['won'] as bool? ?? false;

    final notifier = ref.read(collectionProvider.notifier);
    final cat = notifier.getById(catId);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F23),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won ? Icons.emoji_events : Icons.sentiment_dissatisfied,
                size: 100,
                color: won ? Colors.amber : Colors.white38,
              ),
              const SizedBox(height: 24),
              Text(
                won ? '胜利！' : '败北...',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: won ? Colors.amber : Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if (cat != null) ...[
                Text(
                  cat.name,
                  style: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text('Lv.${cat.level} · CP ${cat.cp}',
                    style: const TextStyle(color: Colors.white54)),
              ],
              const SizedBox(height: 40),
              if (won)
                FilledButton.icon(
                  onPressed: () => context.go('/collection'),
                  icon: const Icon(Icons.collections_bookmark),
                  label: const Text('返回图鉴'),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => context.go('/collection'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('再来一次'),
                ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/collection'),
                child: const Text('返回图鉴', style: TextStyle(color: Colors.white38)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
