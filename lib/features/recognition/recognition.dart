import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../card/collection_provider.dart';

/// 猫脸识别 — 查看同一只猫的不同版本
class CatVersionsPage extends ConsumerWidget {
  const CatVersionsPage({super.key, required this.catFaceId});

  final String catFaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Mock: 从图鉴中按 catFaceId 筛选
    final allCats = ref.watch(collectionProvider).cats;
    final versions = allCats.where((c) => c.catFaceId == catFaceId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('同一只猫的不同版本'),
      ),
      body: versions.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.pets, size: 64, color: Colors.white.withAlpha(60)),
                  const SizedBox(height: 12),
                  Text('暂无其他玩家拍到这只猫',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: versions.length,
              itemBuilder: (context, index) {
                final cat = versions[index];
                return Card(
                  color: Colors.white.withAlpha(8),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withAlpha(40),
                      child: Icon(Icons.pets, color: theme.colorScheme.primary),
                    ),
                    title: Text(cat.name,
                        style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      'CP ${cat.cp} · ${cat.rarity.label} · ${cat.battleSkills.length}个技能',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                    onTap: () => context.push('/card/${cat.id}'),
                  ),
                );
              },
            ),
    );
  }
}

/// 猫脸识别结果提示 — 拍照后弹出
class RecognitionResultSheet extends StatelessWidget {
  const RecognitionResultSheet({
    super.key,
    required this.matchedCount,
    this.onViewVersions,
    this.onDismiss,
  });

  final int matchedCount;
  final VoidCallback? onViewVersions;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isFirstDiscovery = matchedCount == 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(
          color: isFirstDiscovery ? Colors.amber : theme.colorScheme.primary,
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            isFirstDiscovery ? Icons.stars : Icons.people,
            size: 48,
            color: isFirstDiscovery ? Colors.amber : theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            isFirstDiscovery ? '首次发现！' : '已被发现过',
            style: theme.textTheme.titleLarge?.copyWith(
              color: isFirstDiscovery ? Colors.amber : Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFirstDiscovery
                ? '恭喜！你是第一个拍到这只猫的玩家！'
                : '这只猫已被 $matchedCount 位玩家拍到过',
            style: const TextStyle(color: Colors.white54, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (!isFirstDiscovery)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onViewVersions,
                icon: const Icon(Icons.collections),
                label: const Text('查看所有版本'),
              ),
            ),
          if (!isFirstDiscovery) const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onDismiss ?? () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withAlpha(40)),
              ),
              child: const Text('知道了', style: TextStyle(color: Colors.white54)),
            ),
          ),
        ],
      ),
    );
  }
}
