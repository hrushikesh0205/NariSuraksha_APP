import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nari_suraksha/core/constants/app_constants.dart';
import 'package:nari_suraksha/core/routes/app_router.dart';
import 'package:nari_suraksha/core/routes/app_routes.dart';
import 'package:nari_suraksha/core/theme/app_theme.dart';
import 'package:nari_suraksha/providers/settings_provider.dart';

class NarisurakshaApp extends StatelessWidget {
  const NarisurakshaApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeMode themeMode = ThemeMode.system;
    try {
      final settings = Provider.of<SettingsProvider>(context, listen: true);
      themeMode = settings.themeMode;
    } catch (_) {
      // Fallback for standalone test harness where Provider tree is not mounted
    }

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Start at splash; the splash screen resolves the correct next route.
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.onGenerateRoute,
      onUnknownRoute: AppRouter.onUnknownRoute,
    );
  }
}