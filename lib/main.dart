import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/home/home_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load API keys. Won't crash if .env is missing — features that need it
  // will surface a friendly message instead.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}

  // Pre-load the persisted theme so the very first frame is already correct.
  final initialMode = await ThemeController.loadInitial();

  runApp(
    ProviderScope(
      overrides: [
        themeModeProvider.overrideWith((ref) => ThemeController(initialMode)),
      ],
      child: const RnReadyApp(),
    ),
  );
}

class RnReadyApp extends ConsumerWidget {
  const RnReadyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'RN Ready',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      home: const HomeDashboard(),
    );
  }
}
