import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/auth_provider.dart';
import '../card/collection_provider.dart';

/// 个人主页
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  int _debugTapCount = 0;
  Future<void>? _debugResetTimer;

  void _onAvatarTap() {
    if (!kDebugMode) return;
    _debugTapCount++;
    if (_debugTapCount >= 5) {
      _debugTapCount = 0;
      context.push('/debug');
    }
    // 2秒内未连续点击则重置
    _debugResetTimer?.ignore();
    _debugResetTimer = Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _debugTapCount = 0;
    });
  }

  @override
  void dispose() {
    _debugResetTimer?.ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final cats = ref.watch(collectionProvider).cats;
    final theme = Theme.of(context);

    final user = auth.user;
    final totalBattles = cats.fold<int>(0, (s, c) => s + c.totalBattles);
    final totalWins = cats.fold<int>(0, (s, c) => s + c.totalWins);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            icon: const Icon(Icons.logout, size: 18, color: Colors.redAccent),
            label: const Text('退出', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _onAvatarTap,
              child: CircleAvatar(
                radius: 48,
                backgroundColor: theme.colorScheme.primary.withAlpha(40),
                child: Icon(Icons.person, size: 48,
                    color: theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user?.nickname ?? '猫友',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user?.phone ?? '',
              style: const TextStyle(color: Colors.white38),
            ),
            const SizedBox(height: 32),

            // 统计卡片
            Row(
              children: [
                Expanded(child: _statCard('猫咪收集', cats.length.toString(), Icons.pets, theme)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('对战次数', totalBattles.toString(), Icons.sports_kabaddi, theme)),
                const SizedBox(width: 12),
                Expanded(child: _statCard('胜场', totalWins.toString(), Icons.emoji_events, theme)),
              ],
            ),
            const SizedBox(height: 40),

            // 最强猫咪
            if (cats.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('最强猫咪',
                    style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white70)),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: Icon(Icons.pets, color: theme.colorScheme.primary),
                title: Text(cats.first.name,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text('CP ${cats.first.cp} · Lv.${cats.first.level}',
                    style: const TextStyle(color: Colors.white38)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ),
    );
  }
}
