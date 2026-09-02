import 'package:flutter/material.dart';

import 'package:nari_suraksha/core/routes/app_routes.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/features/splash/screens/splash_page.dart';
import 'package:nari_suraksha/features/onboarding/screens/onboarding_screen.dart';
import 'package:nari_suraksha/features/auth/screens/login_page.dart';
import 'package:nari_suraksha/features/auth/screens/register_page.dart';
import 'package:nari_suraksha/features/home/screens/home_page.dart';
import 'package:nari_suraksha/features/profile/screens/profile_page.dart';
import 'package:nari_suraksha/features/settings/screens/settings_page.dart';
import 'package:nari_suraksha/features/emergency_contacts/screens/contacts_screen.dart';
import 'package:nari_suraksha/features/voice_detection/screens/voice_sos_screen.dart';

/// Centralised routing authority for Nari Suraksha.
///
/// ## Architecture
/// The app uses Flutter's built-in [Navigator] with a single
/// [onGenerateRoute] factory — no third-party dependency required.
/// Route path constants live in [AppRoutes] so there are no magic
/// strings at call sites.
///
/// ## Usage
/// ```dart
/// MaterialApp(
///   initialRoute: AppRoutes.splash,
///   onGenerateRoute: AppRouter.onGenerateRoute,
///   onUnknownRoute: AppRouter.onUnknownRoute,
/// )
/// ```
///
/// ## Adding new routes
/// 1. Add a constant to [AppRoutes].
/// 2. Add a `case` block inside [onGenerateRoute].
/// 3. Create / import the target screen widget.
///
/// ## Transitions
/// All routes use [MaterialPageRoute] by default (platform-adaptive
/// slide on iOS, fade on Android).  Override [_buildRoute] locally
/// per-route to apply custom transitions where needed.
abstract final class AppRouter {
  AppRouter._(); // non-instantiable

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Route factory – wire into [MaterialApp.onGenerateRoute].
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ── Auth / launch flow ──────────────────────────────────────────────────
      case AppRoutes.splash:
        return _build(settings, const SplashPage());

      case AppRoutes.onboarding:
        return _build(settings, const OnboardingScreen());

      case AppRoutes.login:
        return _build(settings, const LoginPage());

      case AppRoutes.register:
        return _build(settings, const RegisterPage());

      // ── Main app ────────────────────────────────────────────────────────────
      case AppRoutes.home:
        return _build(settings, const HomePage());

      case AppRoutes.profile:
        return _build(settings, const ProfilePage());

      case AppRoutes.settings:
        return _build(settings, const SettingsPage());

      // ── Feature screens (Quick Actions) ────────────────────────────────────
      case AppRoutes.contacts:
        return _build(settings, const ContactsScreen());

      case AppRoutes.voiceSos:
        return _build(settings, const VoiceSosScreen());

      case AppRoutes.liveTracking:
        return _build(settings, const _ComingSoonPage(title: 'Live Tracking'));

      case AppRoutes.safeRoute:
        return _build(settings, const _ComingSoonPage(title: 'Safe Route'));

      case AppRoutes.safetyTimer:
        return _build(settings, const _ComingSoonPage(title: 'Safety Timer'));

      // ── Unknown ─────────────────────────────────────────────────────────────
      default:
        return onUnknownRoute(settings);
    }
  }

  /// Fallback route – wire into [MaterialApp.onUnknownRoute].
  ///
  /// Shows a friendly 404 page so the app never hard-crashes on an
  /// unrecognised path.
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => _NotFoundPage(routeName: settings.name ?? '(unknown)'),
    );
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Wraps [child] in a [MaterialPageRoute] with the given [settings].
  static MaterialPageRoute<void> _build(
    RouteSettings settings,
    Widget child,
  ) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => child,
    );
  }
}

// ── 404 page ─────────────────────────────────────────────────────────────────

/// Shown when an unrecognised route name is pushed.
class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage({required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Page not found')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 72, color: Colors.grey),
              const SizedBox(height: 24),
              Text(
                '404',
                style: theme.textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Route "$routeName" does not exist.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                icon: const Icon(Icons.home_rounded),
                label: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Coming Soon placeholder ───────────────────────────────────────────────────

/// Friendly placeholder shown for features not yet implemented.
class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 48,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Coming Soon',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$title is under development and will be available in the next update.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: const StadiumBorder(),
                  minimumSize: const Size(160, 48),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
