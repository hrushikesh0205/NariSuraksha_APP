import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nari_suraksha/core/routes/app_routes.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SplashPage  —  Warm, Premium, Trustworthy
// ─────────────────────────────────────────────────────────────────────────────

/// Premium animated splash screen.
///
/// Design: warm cream background, golden glowing aura behind an animated
/// shield, Poppins headline, heartfelt subtitle, soft bouncing dots loader.
///
/// Animation sequence (total ≈ 3 s):
///   0 ms → 400 ms   Background fades in.
///   200 ms → 900 ms  Golden glow circle scales in.
///   300 ms → 1100 ms Shield scales + fades with elastic overshoot.
///   900 ms → 1500 ms App name slides up + fades.
///   1100 ms → 1700 ms Subtitle slides up + fades.
///   1600 ms → 2200 ms Loading dots bounce in.
///   3000 ms           Navigate to onboarding.
///
/// Navigation logic is untouched — still pushes [AppRoutes.onboarding].
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with TickerProviderStateMixin {

  // ── Controllers ────────────────────────────────────────────────────────────
  late final AnimationController _entrance;
  late final AnimationController _glowPulse; // soft breathing glow
  late final AnimationController _dotBounce; // loading dots

  // ── Entrance animations ────────────────────────────────────────────────────
  late final Animation<double> _bgFade;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowFade;
  late final Animation<double> _shieldScale;
  late final Animation<double> _shieldFade;
  late final Animation<Offset> _nameSlide;
  late final Animation<double> _nameFade;
  late final Animation<Offset> _subtitleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _dotsFade;

  // ── Glow pulse ─────────────────────────────────────────────────────────────
  late final Animation<double> _glowBreath;

  // ── Dot bounce (3 dots, staggered) ────────────────────────────────────────
  late final Animation<double> _dot1;
  late final Animation<double> _dot2;
  late final Animation<double> _dot3;

  static const Duration _entranceDuration = Duration(milliseconds: 2200);
  static const Duration _splashTotal      = Duration(milliseconds: 3200);

  @override
  void initState() {
    super.initState();
    _setupSystemUI();
    _buildControllers();
    _buildAnimations();
    _startSequence();
  }

  void _setupSystemUI() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // dark icons on cream bg
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  void _buildControllers() {
    _entrance = AnimationController(vsync: this, duration: _entranceDuration);

    _glowPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _dotBounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  void _buildAnimations() {
    // Background
    _bgFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.18, curve: Curves.easeOut),
    );

    // Golden glow circle
    _glowScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.08, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _glowFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.08, 0.40, curve: Curves.easeIn),
    );

    // Breathing pulse on the glow
    _glowBreath = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _glowPulse, curve: Curves.easeInOut),
    );

    // Shield
    _shieldScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.12, 0.55, curve: Curves.elasticOut),
      ),
    );
    _shieldFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.12, 0.40, curve: Curves.easeIn),
    );

    // App name
    _nameSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.38, 0.70, curve: Curves.easeOutCubic),
    ));
    _nameFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.38, 0.65, curve: Curves.easeIn),
    );

    // Subtitle
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.7),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.52, 0.80, curve: Curves.easeOutCubic),
    ));
    _subtitleFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.52, 0.76, curve: Curves.easeIn),
    );

    // Dots
    _dotsFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.74, 1.0, curve: Curves.easeIn),
    );

    // Bouncing dot offsets (staggered phase)
    _dot1 = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(
        parent: _dotBounce,
        curve: const _PhaseInterval(0.00),
      ),
    );
    _dot2 = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(
        parent: _dotBounce,
        curve: const _PhaseInterval(0.20),
      ),
    );
    _dot3 = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(
        parent: _dotBounce,
        curve: const _PhaseInterval(0.40),
      ),
    );
  }

  Future<void> _startSequence() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    _entrance.forward();
    await Future<void>.delayed(_splashTotal);
    _navigateNext();
  }

  void _navigateNext() {
    if (!mounted) return;
    // Persistent Login: check if user is already authenticated.
    // FirebaseAuth caches credentials locally — works even after phone restart.
    // Wrapped in try-catch: FirebaseAuth.instance throws in test environments.
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // User is already logged in — skip onboarding and go straight to home.
        Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        return;
      }
    } catch (_) {
      // Firebase not initialized (e.g. in test) — fall through to onboarding.
    }
    // No cached session — go to onboarding flow.
    Navigator.of(context).pushReplacementNamed(AppRoutes.onboarding);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _glowPulse.dispose();
    _dotBounce.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _bgFade,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: AppColors.background,
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // ── Glow + Shield ────────────────────────────────────────────
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer soft glow aura
                      AnimatedBuilder(
                        animation: Listenable.merge([_glowScale, _glowFade, _glowBreath]),
                        builder: (_, __) => Transform.scale(
                          scale: _glowScale.value * _glowBreath.value,
                          child: Opacity(
                            opacity: (_glowFade.value * 0.75).clamp(0, 1),
                            child: Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.50),
                                    AppColors.primary.withValues(alpha: 0.20),
                                    AppColors.primary.withValues(alpha: 0.0),
                                  ],
                                  stops: const [0.0, 0.55, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Inner warm gold circle
                      ScaleTransition(
                        scale: _glowScale,
                        child: FadeTransition(
                          opacity: _glowFade,
                          child: Container(
                            width: 148,
                            height: 148,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryContainer,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.30),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Shield icon
                      ScaleTransition(
                        scale: _shieldScale,
                        child: FadeTransition(
                          opacity: _shieldFade,
                          child: const _ShieldLogo(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── App name ─────────────────────────────────────────────────
                SlideTransition(
                  position: _nameSlide,
                  child: FadeTransition(
                    opacity: _nameFade,
                    child: Text(
                      'Nari Suraksha',
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: AppColors.onBackground,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        fontSize: 32,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // ── Subtitle ─────────────────────────────────────────────────
                SlideTransition(
                  position: _subtitleSlide,
                  child: FadeTransition(
                    opacity: _subtitleFade,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                      child: Text(
                        'Because every woman deserves to feel safe.',
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.onSurfaceVariant,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl + AppSpacing.md),

                // ── Bouncing dots loader ──────────────────────────────────────
                FadeTransition(
                  opacity: _dotsFade,
                  child: _BouncingDots(d1: _dot1, d2: _dot2, d3: _dot3),
                ),

                const Spacer(flex: 2),

                // ── Footer badge ──────────────────────────────────────────────
                FadeTransition(
                  opacity: _dotsFade,
                  child: const _FooterBadge(),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

/// Warm shield logo with gold ring and location pin accent.
class _ShieldLogo extends StatelessWidget {
  const _ShieldLogo();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Shield icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.45),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.shield_rounded,
            size: 54,
            color: AppColors.onPrimary,
          ),
        ),
        // Small location pin at bottom-right
        Positioned(
          bottom: 6,
          right: 6,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary,
              border: Border.all(color: AppColors.background, width: 2),
            ),
            child: const Icon(
              Icons.location_on_rounded,
              size: 14,
              color: AppColors.onSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Three soft bouncing dots loading indicator.
class _BouncingDots extends StatelessWidget {
  const _BouncingDots({
    required this.d1,
    required this.d2,
    required this.d3,
  });

  final Animation<double> d1;
  final Animation<double> d2;
  final Animation<double> d3;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([d1, d2, d3]),
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _Dot(offset: d1.value),
          const SizedBox(width: AppSpacing.sm),
          _Dot(offset: d2.value),
          const SizedBox(width: AppSpacing.sm),
          _Dot(offset: d3.value),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.offset});
  final double offset;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, offset),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

/// "Secured by Nari Suraksha" footer badge — warm tinted.
class _FooterBadge extends StatelessWidget {
  const _FooterBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            size: 14,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 6),
          Text(
            'Secured by Nari Suraksha',
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.onPrimary,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom curve — phase-offset bounce (for staggered dots)
// ─────────────────────────────────────────────────────────────────────────────

/// Produces a bounce at [phase] offset within the [0, 1] timeline.
class _PhaseInterval extends Curve {
  const _PhaseInterval(this.phase);
  final double phase;

  @override
  double transformInternal(double t) {
    final double shifted = ((t + phase) % 1.0);
    // Sine arch: 0 → 1 → 0
    return math.sin(shifted * math.pi).clamp(0.0, 1.0);
  }
}
