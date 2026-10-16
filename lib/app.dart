import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanpro/core/constants/app_constants.dart';
import 'package:scanpro/core/router/app_router.dart';
import 'package:scanpro/core/theme/app_theme.dart';
import 'package:scanpro/core/theme/theme_provider.dart';

/// Root application widget wiring Material 3 themes, Riverpod state, and GoRouter.
class ScanProApp extends ConsumerWidget {
  const ScanProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}

