import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'config/app_config.dart';
import 'features/auth/auth.dart';
import 'features/map/explore_page.dart';
import 'features/camera/capture_page.dart';
import 'features/camera/detecting_page.dart';
import 'features/card/card_detail_page.dart';
import 'features/card/collection_page.dart';
import 'features/battle/battle_page.dart';
import 'features/battle/battle_result_page.dart';
import 'features/profile/profile_page.dart';
import 'features/recognition/recognition.dart';
import 'features/debug/debug_panel.dart';
import 'widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/explore',
    redirect: (context, state) {
      // 开发模式：跳过登录检查方便调试
      // 正式使用：
      // final isAuth = authState.status == AuthStatus.authenticated;
      // final isLoginRoute = state.matchedLocation == '/login';
      // if (!isAuth && !isLoginRoute) return '/login';
      // if (isAuth && isLoginRoute) return '/explore';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),

      // 主页面壳（底部导航）
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/explore',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExplorePage(),
            ),
          ),
          GoRoute(
            path: '/capture',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CapturePage(),
            ),
          ),
          GoRoute(
            path: '/collection',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CollectionPage(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfilePage(),
            ),
          ),
        ],
      ),

      // 全屏页面（不在底部导航内）
      GoRoute(
        path: '/capture/detecting/:imagePath',
        builder: (context, state) => DetectingPage(
          imagePath: state.pathParameters['imagePath']!,
        ),
      ),
      GoRoute(
        path: '/card/:catId',
        builder: (context, state) => CardDetailPage(
          catId: state.pathParameters['catId']!,
        ),
      ),
      GoRoute(
        path: '/battle/:catId',
        builder: (context, state) => BattlePage(
          catId: state.pathParameters['catId']!,
        ),
      ),
      GoRoute(
        path: '/battle/result/:catId',
        builder: (context, state) => BattleResultPage(
          catId: state.pathParameters['catId']!,
        ),
      ),
      GoRoute(
        path: '/recognition/:catFaceId',
        builder: (context, state) => CatVersionsPage(
          catFaceId: state.pathParameters['catFaceId']!,
        ),
      ),
      if (kDebugMode)
      GoRoute(
        path: '/debug',
        builder: (context, state) => const DebugPanel(),
      ),
    ],
  );
});

class KittyKittyApp extends ConsumerWidget {
  const KittyKittyApp({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'KittyKitty',
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: config.themeColor,
          secondary: config.themeColor,
          surface: const Color(0xFF1A1A2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F23),
        fontFamily: 'PingFang SC',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: const TextStyle(color: Colors.white54),
          hintStyle: TextStyle(color: Colors.white.withAlpha(40)),
        ),
      ),
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
