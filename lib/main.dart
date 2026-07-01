import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 通过 --dart-define 选择环境: flutter run --dart-define=ENVIRONMENT=prod
  // 可选值: dev | staging | prod，默认为 dev
  const env = String.fromEnvironment('ENVIRONMENT', defaultValue: 'dev');
  final config = switch (env) {
    'prod' => AppConfig.prod(),
    'staging' => AppConfig.staging(),
    _ => AppConfig.dev(),
  };

  runApp(
    ProviderScope(
      child: KittyKittyApp(config: config),
    ),
  );
}
