/// Centralised route-name constants for Nari Suraksha.
///
/// Every navigable destination in the app has a unique, compile-time
/// constant path defined here.  Import this file wherever a route name
/// is referenced to avoid magic strings.
///
/// Naming conventions
/// ──────────────────
///  • Top-level screens use simple paths, e.g. [AppRoutes.splash].
///  • Nested / detail screens append a segment, e.g. `/home/detail`.
///  • Dynamic segments are written as `:paramName`.
abstract final class AppRoutes {
  AppRoutes._(); // non-instantiable

  // ── Auth Flow ────────────────────────────────────────────────────────────────

  /// Animated splash / brand screen shown on cold start.
  static const String splash = '/';

  /// Multi-page onboarding carousel (first-run only).
  static const String onboarding = '/onboarding';

  /// Sign-in screen.
  static const String login = '/login';

  /// New-account registration screen.
  static const String register = '/register';

  // ── Main App ─────────────────────────────────────────────────────────────────

  /// Main home / dashboard shell (hosts bottom navigation).
  static const String home = '/home';

  /// User profile & account details.
  static const String profile = '/profile';

  /// App preferences & configuration.
  static const String settings = '/settings';

  // ── Feature Screens ───────────────────────────────────────────────────────────

  /// Emergency contacts management screen.
  static const String contacts = '/contacts';

  /// Live location tracking / map screen.
  static const String liveTracking = '/live-tracking';

  /// Safe route planning screen.
  static const String safeRoute = '/safe-route';

  /// Safety timer screen.
  static const String safetyTimer = '/safety-timer';
}
