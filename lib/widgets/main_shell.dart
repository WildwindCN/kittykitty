import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 带底部导航的主页面壳
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.white12, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex(location),
          onTap: (index) => _onTap(context, index),
          backgroundColor: const Color(0xFF0F0F23),
          selectedItemColor: Theme.of(context).colorScheme.primary,
          unselectedItemColor: Colors.white38,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore),
              activeIcon: Icon(Icons.explore, size: 28),
              label: '探索',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt_outlined),
              activeIcon: Icon(Icons.camera_alt, size: 28),
              label: '拍摄',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.collections_bookmark_outlined),
              activeIcon: Icon(Icons.collections_bookmark, size: 28),
              label: '图鉴',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person, size: 28),
              label: '我的',
            ),
          ],
        ),
      ),
    );
  }

  int _currentIndex(String location) {
    if (location.startsWith('/explore')) return 0;
    if (location.startsWith('/capture')) return 1;
    if (location.startsWith('/collection')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/explore');
      case 1:
        context.go('/capture');
      case 2:
        context.go('/collection');
      case 3:
        context.go('/profile');
    }
  }
}
