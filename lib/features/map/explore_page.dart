import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/cat_service.dart';
import '../auth/auth_provider.dart';

/// 探索页 — 附近猫咪列表（使用真实 GPS 定位）
class ExplorePage extends ConsumerStatefulWidget {
  const ExplorePage({super.key});

  @override
  ConsumerState<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<ExplorePage> {
  List<Map<String, dynamic>> _nearbyCats = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNearby();
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final hasPermission = await Geolocator.checkPermission();
      if (hasPermission == LocationPermission.denied ||
          hasPermission == LocationPermission.deniedForever) {
        final result = await Geolocator.requestPermission();
        if (result != LocationPermission.whileInUse &&
            result != LocationPermission.always) {
          return null;
        }
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadNearby() async {
    setState(() { _loading = true; _error = null; });
    try {
      final position = await _getCurrentPosition();
      final lat = position?.latitude ?? 31.23;  // 默认上海（权限拒绝时）
      final lng = position?.longitude ?? 121.47;

      final apiClient = ref.read(apiClientProvider);
      final service = CatService(apiClient: apiClient);
      final resp = await service.getNearbyCats(
        latitude: lat, longitude: lng, radius: 10000,
      );
      if (mounted) {
        setState(() {
          _nearbyCats = resp.data ?? [];
          _loading = false;
          _error = resp.isSuccess ? null : (resp.message ?? '加载失败');
        });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('探索'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNearby,
            tooltip: '刷新',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off, size: 48, color: Colors.white38),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadNearby,
                        icon: const Icon(Icons.refresh),
                        label: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNearby,
                  child: _nearbyCats.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Center(
                              child: Column(
                                children: [
                                  Icon(Icons.pets, size: 64,
                                      color: Colors.white.withAlpha(50)),
                                  const SizedBox(height: 12),
                                  Text('附近暂无猫咪',
                                      style: TextStyle(
                                          color: Colors.white.withAlpha(80),
                                          fontSize: 16)),
                                  const SizedBox(height: 8),
                                  Text('出门探索发现更多猫咪吧！',
                                      style: TextStyle(
                                          color: Colors.white.withAlpha(40),
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _nearbyCats.length,
                          itemBuilder: (context, i) {
                            final c = _nearbyCats[i];
                            final rarity = c['rarity'] as String? ?? 'common';
                            final color = _rarityColor(rarity);

                            return Card(
                              color: Colors.white.withAlpha(6),
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: color.withAlpha(60)),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: color.withAlpha(30),
                                  child: Icon(Icons.pets, color: color, size: 22),
                                ),
                                title: Text(c['name'] as String? ?? '???',
                                    style: const TextStyle(
                                        color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  '${_rarityLabel(rarity)} · CP ${c['cp'] ?? '?'}',
                                  style: TextStyle(color: color.withAlpha(200), fontSize: 12),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: Colors.white24),
                                onTap: () {
                                  final id = c['id'] as String? ?? c['_id'] as String?;
                                  if (id != null) context.push('/card/$id');
                                },
                              ),
                            );
                          },
                        ),
                ),
    );
  }

  Color _rarityColor(String rarity) {
    return switch (rarity) {
      'legendary' => const Color(0xFFFFD700),
      'epic' => const Color(0xFFCE93D8),
      'rare' => const Color(0xFF4FC3F7),
      _ => Colors.grey,
    };
  }

  String _rarityLabel(String rarity) {
    return switch (rarity) {
      'legendary' => '传说',
      'epic' => '史诗',
      'rare' => '稀有',
      _ => '普通',
    };
  }
}
