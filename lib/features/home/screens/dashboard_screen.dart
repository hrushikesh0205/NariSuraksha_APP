import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:nari_suraksha/core/routes/app_routes.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/core/widgets/widgets.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/dashboard_provider.dart';
import 'package:nari_suraksha/providers/sos_provider.dart';
import 'package:nari_suraksha/providers/user_provider.dart';
import 'package:nari_suraksha/features/sos/screens/sos_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DashboardScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Premium home dashboard for authenticated users.
///
/// Sections (top → bottom):
///  1. Gradient header  — time-aware greeting, user name, notification bell, avatar
///  2. Safety status card  — live GPS + internet + permission status
///  3. Hero SOS button  — large circular button with repeating pulse rings
///  4. Quick-actions grid  — 8 features in a 2-column grid with stagger animation
///  5. Recent alerts  — live Firestore stream with beautiful empty state
///  6. Daily safety tip card (gradient accent)
///
/// All animations, colours, spacing, and typography are preserved from
/// the original approved UI. Only data sources are wired to Firebase.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  // Pulse animation for the SOS button
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;
  late final Animation<double> _pulseOpacity;

  // Screen-entry fade + slide
  late final AnimationController _entryController;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  // Stagger controller for quick-action grid cards
  late final AnimationController _staggerController;

  // Periodic timer to keep the greeting fresh
  late final Timer _greetingTimer;
  DateTime _now = DateTime.now();

  // ── Quick action definitions ────────────────────────────────────────────────

  static List<_QuickAction> get _quickActions => [
    const _QuickAction(
      icon: Icons.contacts_rounded,
      label: 'Emergency\nContacts',
      color: AppColors.pastYellowIcon,
      bgColor: AppColors.pastYellow,
      route: AppRoutes.contacts,
    ),
    _QuickAction(
      icon: Icons.location_on_rounded,
      label: 'Live\nTracking',
      color: AppColors.pastBlueIcon,
      bgColor: AppColors.pastBlue,
      onTap: (context) {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const LocationBottomSheet(),
        );
      },
    ),
    const _QuickAction(
      icon: Icons.mic_rounded,
      label: 'Voice\nSOS',
      color: AppColors.pastGreenIcon,
      bgColor: AppColors.pastGreen,
      route: AppRoutes.voiceSos,
    ),
    _QuickAction(
      icon: Icons.sos_rounded,
      label: 'Emergency\nSOS',
      color: const Color(0xFFEF4444),
      bgColor: const Color(0xFFFEE2E2),
      onTap: (context) {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SosScreen(),
          ),
        );
      },
    ),
  ];

  // ── Safety tips & quotes ────────────────────────────────────────────────────

  static const List<String> _safetyTips = [
    'Share your live location with a trusted contact before traveling alone.',
    'Keep your phone charged above 30% when heading out.',
    'Save local emergency numbers under ICE (In Case of Emergency).',
    'Walk in well-lit, populated areas whenever possible at night.',
    'Trust your instincts — if something feels wrong, leave immediately.',
    'Inform someone of your expected arrival time and route.',
    'Avoid wearing headphones in both ears while walking alone.',
    'Keep a personal alarm or whistle accessible at all times.',
  ];

  static const List<String> _motivationalQuotes = [
    'Your safety is our highest priority. ✨',
    'Stay aware. Stay confident. 💡',
    'You are never alone. We are with you. 🤝',
    'Small precautions create big protection. 🛡️',
    'Confidence is your greatest strength. 💪',
    'Prepared today. Protected tomorrow. 🌟',
    'Safety begins with awareness. 👀',
    'You deserve to feel secure every day. ❤️',
    'Your journey matters. We keep you safe. 📍',
    'Stay strong. Stay safe. 🌿',
    'Confidence is your best protection. 🔥',
    'Trust yourself. You know what to do. 🌈',
    'Safety is not a privilege — it is your right. 💯',
    'Every step you take, we are right beside you. 💛',
    'Be alert, be aware, be amazing. 🌚',
  ];

  late final String _todayTip;
  late final String _todayQuote;

  @override
  void initState() {
    super.initState();

    // Daily tip + motivational quote rotate by day-of-year
    final dayOfYear = DateTime.now()
            .difference(DateTime(DateTime.now().year, 1, 1))
            .inDays;
    _todayTip = _safetyTips[dayOfYear % _safetyTips.length];
    _todayQuote = _motivationalQuotes[dayOfYear % _motivationalQuotes.length];

    // ── Pulse ──────────────────────────────────────────────────────────────────
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseScale = Tween<double>(begin: 1.0, end: 1.55).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );
    _pulseOpacity = Tween<double>(begin: 0.55, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOutCubic),
    );

    // ── Entry ──────────────────────────────────────────────────────────────────
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _entryFade = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeOutCubic,
    );
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    // ── Stagger ────────────────────────────────────────────────────────────────
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        _entryController.forward();
        _staggerController.forward();
      }
    });

    // Refresh the greeting every minute so Good Morning → Good Afternoon
    // → Good Evening transitions happen live without a restart.
    _greetingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // ── Kick off data loading ──────────────────────────────────────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DashboardProvider>().initialize();
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entryController.dispose();
    _staggerController.dispose();
    _greetingTimer.cancel();
    super.dispose();
  }

  String get _greeting {
    final hour = _now.hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _entryFade,
        child: SlideTransition(
          position: _entrySlide,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Gradient header ──────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader()),

              // ── Safety status ────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                sliver: SliverToBoxAdapter(
                  child: _SafetyStatusSection(),
                ),
              ),

              // ── SOS hero ─────────────────────────────────────────────────────
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: _SosButton(
                    pulseScale: _pulseScale,
                    pulseOpacity: _pulseOpacity,
                  ),
                ),
              ),

              // ── Dashboard stats row ──────────────────────────────────────────
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, 0),
                sliver: SliverToBoxAdapter(
                  child: _DashboardStatsRow(),
                ),
              ),

              // ── Quick actions label ──────────────────────────────────────────
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Quick Actions',
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

              // ── Quick actions grid ───────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                sliver: SliverToBoxAdapter(
                  child: _QuickActionsGrid(
                    actions: _quickActions,
                    staggerController: _staggerController,
                  ),
                ),
              ),

              // ── Recent alerts label ──────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Recent Alerts',
                    actionLabel: 'See all',
                    onAction: () => _showNotificationsSheet(context),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

              // ── Recent alerts card ───────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                sliver: SliverToBoxAdapter(
                  child: _RecentAlertsSection(cs: cs),
                ),
              ),

              // ── Daily tip label ──────────────────────────────────────────────
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'Daily Safety Tip',
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

              // ── Daily tip card ───────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
                sliver: SliverToBoxAdapter(
                  child: _SafetyTipCard(tip: _todayTip, cs: cs),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Greeting + name — driven by UserProvider
                  Expanded(
                    child: Consumer<UserProvider>(
                      builder: (_, userProv, __) {
                        final displayName = userProv.user?.firstName ?? 'User';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_greeting,',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.onPrimary.withValues(alpha: 0.90),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            userProv.isLoading
                                ? _HeaderShimmer()
                                : Text(
                                    '$displayName 👋',
                                    style: AppTextStyles.headlineMedium.copyWith(
                                      color: AppColors.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Notification bell
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () => _showNotificationsSheet(context),
                        icon: const Icon(Icons.notifications_outlined),
                        color: AppColors.onPrimary,
                        tooltip: 'Notifications',
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: AppSpacing.xs),

                  // Avatar — dynamic initials (taps navigate to Profile)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed(AppRoutes.profile);
                    },
                    child: Consumer<UserProvider>(
                      builder: (_, userProv, __) {
                        final user = userProv.user;
                        return CircularAvatarWidget(
                          name: user?.name ?? 'SB',
                          radius: 22,
                          backgroundColor:
                              AppColors.onPrimary.withValues(alpha: 0.2),
                          foregroundColor: AppColors.onPrimary,
                          badge: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryDark,
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Motivational quote
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: AppColors.onPrimary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _todayQuote,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.onPrimary.withValues(alpha: 0.90),
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationsBottomSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeaderShimmer  —  loading placeholder for user name
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      width: 120,
      decoration: BoxDecoration(
        color: AppColors.onPrimary.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SafetyStatusSection  —  live GPS / internet / permission status
// ─────────────────────────────────────────────────────────────────────────────

class _SafetyStatusSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (_, dash, __) {
        if (dash.isInitializing) {
          return _StatusShimmer();
        }

        final status = dash.safetyStatus;

        if (status.isSafe) {
          return StatusCard(
            icon: Icons.shield_rounded,
            title: 'You are Safe',
            message: 'GPS active · Internet connected · All systems normal.',
            variant: StatusVariant.success,
            actionLabel: 'Refresh',
            onAction: () => dash.refreshSafetyStatus(),
          );
        }

        // Build a descriptive warning
        final issues = <String>[];
        if (!status.isConnected) issues.add('No internet');
        if (!status.isLocationEnabled) issues.add('GPS disabled');
        if (!status.hasLocationPermission) issues.add('Location access denied');

        final lastUpdated = status.lastUpdated != null
            ? ' · Updated ${DateFormat('HH:mm').format(status.lastUpdated!)}'
            : '';

        return StatusCard(
          icon: Icons.warning_amber_rounded,
          title: 'Safety Check Required',
          message: '${issues.join(' · ')}$lastUpdated',
          variant: issues.any((i) => i.contains('GPS') || i.contains('internet'))
              ? StatusVariant.error
              : StatusVariant.warning,
          actionLabel: 'Fix',
          onAction: () => dash.refreshSafetyStatus(),
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────────
// _DashboardStatsRow  —  real counts + live status chips
// ────────────────────────────────────────────────────────────────────────────────

/// Compact row of four stat chips shown between the SOS button and Quick Actions.
///
/// Values are driven by:
/// - Emergency contacts count — [ContactProvider.count]
/// - SOS activations — [DashboardProvider.sosCount]
/// - GPS status       — [DashboardProvider.locationStatusLabel]
/// - Connectivity     — [DashboardProvider.isConnected]
class _DashboardStatsRow extends StatelessWidget {
  const _DashboardStatsRow();

  @override
  Widget build(BuildContext context) {
    return Consumer2<DashboardProvider, ContactProvider>(
      builder: (_, dash, contacts, __) {
        final isInit = dash.isInitializing;
        final cs = Theme.of(context).colorScheme;

        return Row(
          children: [
            Expanded(
              child: _StatChip(
                icon: Icons.people_rounded,
                label: 'Contacts',
                value: isInit ? '…' : '${contacts.count}',
                color: AppColors.pastBlueIcon,
                bg: AppColors.pastBlue,
                cs: cs,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatChip(
                icon: Icons.sos_rounded,
                label: 'SOS Sent',
                value: isInit ? '…' : '${dash.sosCount}',
                color: AppColors.error,
                bg: AppColors.errorContainer,
                cs: cs,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatChip(
                icon: isInit
                    ? Icons.location_searching_rounded
                    : (dash.safetyStatus.isLocationEnabled &&
                            dash.safetyStatus.hasLocationPermission
                        ? Icons.location_on_rounded
                        : Icons.location_off_rounded),
                label: 'Location',
                value: isInit ? '…' : dash.locationStatusLabel,
                color: isInit
                    ? AppColors.pastPurpleIcon
                    : (dash.safetyStatus.isLocationEnabled &&
                            dash.safetyStatus.hasLocationPermission
                        ? AppColors.pastGreenIcon
                        : AppColors.warning),
                bg: isInit
                    ? AppColors.pastPurple
                    : (dash.safetyStatus.isLocationEnabled &&
                            dash.safetyStatus.hasLocationPermission
                        ? AppColors.pastGreen
                        : AppColors.warning.withValues(alpha: 0.12)),
                cs: cs,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _StatChip(
                icon: isInit
                    ? Icons.wifi_find_rounded
                    : (dash.isConnected
                        ? Icons.wifi_rounded
                        : Icons.wifi_off_rounded),
                label: 'Network',
                value: isInit
                    ? '…'
                    : (dash.isConnected ? 'Online' : 'Offline'),
                color: isInit
                    ? AppColors.pastMintIcon
                    : (dash.isConnected
                        ? AppColors.pastGreenIcon
                        : AppColors.error),
                bg: isInit
                    ? AppColors.pastMint
                    : (dash.isConnected
                        ? AppColors.pastGreen
                        : AppColors.errorContainer),
                cs: cs,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A single compact stat chip used by [_DashboardStatsRow].
class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
    required this.cs,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.titleSmall.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 10,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusShimmer  —  skeleton for safety status card
// ─────────────────────────────────────────────────────────────────────────────

class _StatusShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border(left: BorderSide(color: cs.secondary, width: 4)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 13,
                  width: 120,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 11,
                  width: 200,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SosButton  —  Hero SOS with full Firestore + SMS integration
// ─────────────────────────────────────────────────────────────────────────────

class _SosButton extends StatefulWidget {
  const _SosButton({
    required this.pulseScale,
    required this.pulseOpacity,
  });

  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;

  @override
  State<_SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<_SosButton> {
  bool _pressed = false;

  /// Guards against rapid double-tap firing the SOS twice.
  bool _isTriggerLocked = false;

  static const Color _sosRed = Color(0xFFEF4444);
  static const double _buttonSize = 140;

  /// Full SOS flow triggered by double-tap.
  ///
  /// 1. Lock against duplicate triggers.
  /// 2. Haptic feedback.
  /// 3. Call [DashboardProvider.triggerSos] (location → Firestore → activity log).
  /// 4. On success: load the latest SOS doc ID from [SosProvider], show [SosSuccessSheet].
  /// 5. On failure: show error snackbar.
  /// 6. Always unlock trigger in finally.
  Future<void> _handleDoubleTap(BuildContext ctx) async {
    if (_isTriggerLocked) return;

    setState(() => _isTriggerLocked = true);
    HapticFeedback.heavyImpact();

    final dash = ctx.read<DashboardProvider>();
    final result = await dash.triggerSos();

    if (!ctx.mounted) {
      setState(() => _isTriggerLocked = false);
      return;
    }

    if (result.isSuccess) {
      // Reload SOS history so we can get the newly-created doc ID.
      await ctx.read<SosProvider>().loadHistory();
      if (!ctx.mounted) {
        setState(() => _isTriggerLocked = false);
        return;
      }

      final history = ctx.read<SosProvider>().history;
      final sosDocId = result.docId ?? (history.isNotEmpty ? history.first.id : null);
      final sosTime = DateTime.now();

      await SosSuccessSheet.show(
        ctx,
        mapsUrl: result.mapsUrl,
        sosTime: sosTime,
        sosDocId: sosDocId,
        onDone: () {},
      );
    } else {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.failureReason ?? 'SOS failed. Please try again.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    setState(() => _isTriggerLocked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (ctx, dash, __) {
        final isLoading = dash.isSosTriggerLoading;

        return Column(
          children: [
            GestureDetector(
              onTapDown: isLoading ? null : (_) => setState(() => _pressed = true),
              onTapUp: isLoading ? null : (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              onDoubleTap: isLoading ? null : () => _handleDoubleTap(ctx),
              child: AnimatedScale(
                scale: _pressed ? 0.93 : 1.0,
                duration: const Duration(milliseconds: 120),
                child: SizedBox(
                  width: _buttonSize + 80,
                  height: _buttonSize + 80,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Outer repeating pulse ring
                      AnimatedBuilder(
                        animation: widget.pulseScale,
                        builder: (_, __) => Transform.scale(
                          scale: widget.pulseScale.value,
                          child: Opacity(
                            opacity: widget.pulseOpacity.value,
                            child: Container(
                              width: _buttonSize,
                              height: _buttonSize,
                              decoration: const BoxDecoration(
                                color: _sosRed,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Soft inner glow ring
                      Container(
                        width: _buttonSize + 22,
                        height: _buttonSize + 22,
                        decoration: BoxDecoration(
                          color: _sosRed.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                      ),
                      // Main button
                      Container(
                        width: _buttonSize,
                        height: _buttonSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0xFFFF6B6B), _sosRed],
                            stops: [0.3, 1.0],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _sosRed.withValues(
                                  alpha: isLoading ? 0.20 : 0.45),
                              blurRadius: 30,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(36),
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                              )
                            : const Icon(
                                Icons.sos_rounded,
                                color: Colors.white,
                                size: 56,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Emergency SOS',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isLoading ? 'Sending alert…' : 'Double-tap only in emergency',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick action model
// ─────────────────────────────────────────────────────────────────────────────

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    this.route,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;

  /// Named route to push. `null` = "Coming Soon" sheet.
  final String? route;

  /// Optional custom tap handler (e.g. open bottom sheet or custom screen).
  final void Function(BuildContext context)? onTap;
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuickActionsGrid
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.actions,
    required this.staggerController,
  });

  final List<_QuickAction> actions;
  final AnimationController staggerController;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.55,
      ),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final start = (index * 0.10).clamp(0.0, 0.8);
        final end = (start + 0.35).clamp(0.0, 1.0);

        final fadeIn = Tween<double>(begin: 0, end: 1).animate(
          CurvedAnimation(
            parent: staggerController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        );
        final slideIn = Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: staggerController,
            curve: Interval(start, end, curve: Curves.easeOut),
          ),
        );

        return FadeTransition(
          opacity: fadeIn,
          child: SlideTransition(
            position: slideIn,
            child: _QuickActionTile(action: actions[index]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuickActionTile
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionTile extends StatefulWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 130),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  bool _hovered = false;

  void _handleTap(BuildContext context) {
    if (widget.action.onTap != null) {
      widget.action.onTap!(context);
      return;
    }
    final route = widget.action.route;
    if (route != null) {
      Navigator.of(context).pushNamed(route);
    } else {
      // Coming Soon — show a friendly bottom sheet
      _showComingSoon(context, widget.action.label.replaceAll('\n', ' '));
    }
  }

  void _showComingSoon(BuildContext context, String featureName) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppColors.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  size: 34,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '$featureName — Coming Soon',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'This feature is under development and will be available in the next update. Stay tuned!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.onPrimary,
                    shape: const StadiumBorder(),
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final action = widget.action;

    return AnimatedBuilder(
      animation: _pressScale,
      builder: (_, child) =>
          Transform.scale(scale: _pressScale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _hovered = true);
          _pressCtrl.forward();
        },
        onTapUp: (_) {
          setState(() => _hovered = false);
          _pressCtrl.reverse();
        },
        onTapCancel: () {
          setState(() => _hovered = false);
          _pressCtrl.reverse();
        },
        onTap: () => _handleTap(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: _hovered
                  ? action.color.withValues(alpha: 0.40)
                  : cs.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: action.color.withValues(alpha: _hovered ? 0.10 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: action.color,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(action.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    action.label,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RecentAlertsSection  —  live Firestore-backed alerts
// ─────────────────────────────────────────────────────────────────────────────

class _RecentAlertsSection extends StatelessWidget {
  const _RecentAlertsSection({required this.cs});

  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (_, dash, __) {
        if (dash.isInitializing) {
          return _AlertsShimmer(cs: cs);
        }

        if (dash.alertsErrorMessage != null) {
          return _AlertsErrorCard(cs: cs, message: dash.alertsErrorMessage!);
        }

        final alerts = dash.recentAlerts;

        if (alerts.isEmpty) {
          return _EmptyAlertsCard(cs: cs);
        }

        return _AlertsListCard(cs: cs, alerts: alerts);
      },
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyAlertsCard extends StatelessWidget {
  const _EmptyAlertsCard({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 44,
            color: cs.onSurfaceVariant.withValues(alpha: 0.45),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No Recent Alerts',
            style: AppTextStyles.titleSmall.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Alerts and notifications will appear here.',
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Alert items list ──────────────────────────────────────────────────────────

class _AlertsListCard extends StatelessWidget {
  const _AlertsListCard({required this.cs, required this.alerts});
  final ColorScheme cs;
  final List<ActivityLogModel> alerts;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: alerts.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: cs.outlineVariant,
          indent: AppSpacing.md,
          endIndent: AppSpacing.md,
        ),
        itemBuilder: (_, index) => _AlertItem(
          log: alerts[index],
          cs: cs,
        ),
      ),
    );
  }
}

class _AlertItem extends StatelessWidget {
  const _AlertItem({required this.log, required this.cs});
  final ActivityLogModel log;
  final ColorScheme cs;

  IconData get _icon => switch (log.type) {
        ActivityLogType.sosActivated => Icons.sos_rounded,
        ActivityLogType.locationShared => Icons.location_on_rounded,
        ActivityLogType.contactAdded => Icons.person_add_rounded,
        ActivityLogType.contactDeleted => Icons.person_remove_rounded,
        ActivityLogType.timerCompleted => Icons.timer_off_rounded,
        ActivityLogType.timerStarted => Icons.timer_rounded,
        ActivityLogType.profileUpdated => Icons.manage_accounts_rounded,
        ActivityLogType.unknown => Icons.notifications_rounded,
      };

  Color get _iconColor => switch (log.type) {
        ActivityLogType.sosActivated => AppColors.error,
        ActivityLogType.locationShared => AppColors.pastBlueIcon,
        ActivityLogType.contactAdded => AppColors.pastGreenIcon,
        ActivityLogType.contactDeleted => AppColors.error,
        ActivityLogType.timerCompleted => AppColors.pastLavenderIcon,
        ActivityLogType.timerStarted => AppColors.pastYellowIcon,
        ActivityLogType.profileUpdated => AppColors.pastPurpleIcon,
        ActivityLogType.unknown => cs.onSurfaceVariant,
      };

  Color get _bgColor => switch (log.type) {
        ActivityLogType.sosActivated => AppColors.errorContainer,
        ActivityLogType.locationShared => AppColors.pastBlue,
        ActivityLogType.contactAdded => AppColors.pastGreen,
        ActivityLogType.contactDeleted => AppColors.errorContainer,
        ActivityLogType.timerCompleted => AppColors.pastLavender,
        ActivityLogType.timerStarted => AppColors.pastYellow,
        ActivityLogType.profileUpdated => AppColors.pastPurple,
        ActivityLogType.unknown => cs.surfaceContainerHighest,
      };

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(log.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.type.displayLabel,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            timeStr,
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _AlertsShimmer extends StatelessWidget {
  const _AlertsShimmer({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: List.generate(3, (i) => _ShimmerRow(cs: cs, isLast: i == 2)),
      ),
    );
  }
}

class _ShimmerRow extends StatelessWidget {
  const _ShimmerRow({required this.cs, required this.isLast});
  final ColorScheme cs;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 13,
                      width: 100,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 11,
                      width: 180,
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: cs.outlineVariant,
            indent: AppSpacing.md,
            endIndent: AppSpacing.md,
          ),
      ],
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _AlertsErrorCard extends StatelessWidget {
  const _AlertsErrorCard({required this.cs, required this.message});
  final ColorScheme cs;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.error.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: cs.error, size: 28),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Could not load alerts',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.read<DashboardProvider>().refreshAlerts(),
            child: Text(
              'Retry',
              style: AppTextStyles.labelMedium.copyWith(color: cs.error),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SafetyTipCard  —  unchanged from original design
// ─────────────────────────────────────────────────────────────────────────────

class _SafetyTipCard extends StatelessWidget {
  const _SafetyTipCard({required this.tip, required this.cs});

  final String tip;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.tertiary.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: AppColors.tertiary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.lightbulb_rounded,
              color: AppColors.tertiary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Tip",
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.tertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurface,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotificationsBottomSheet  —  Recent Alerts modal sheet
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationsBottomSheet extends StatelessWidget {
  const _NotificationsBottomSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Alerts',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onSurface,
                          ),
                        ),
                        Text(
                          'Safety and emergency notifications',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: cs.outlineVariant),
            Flexible(
              child: Consumer2<DashboardProvider, SosProvider>(
                builder: (context, dash, sosProv, __) {
                  final alerts = dash.recentAlerts;
                  final sosRecords = sosProv.history;

                  if (dash.isInitializing && alerts.isEmpty && sosRecords.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppSpacing.xxl),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (alerts.isEmpty && sosRecords.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: _EmptyAlertsCard(cs: cs),
                    );
                  }

                  // If we have activity logs, render them with status badges
                  if (alerts.isNotEmpty) {
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      shrinkWrap: true,
                      itemCount: alerts.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                        indent: AppSpacing.md,
                        endIndent: AppSpacing.md,
                      ),
                      itemBuilder: (_, index) {
                        return _NotificationAlertTile(
                          log: alerts[index],
                          cs: cs,
                        );
                      },
                    );
                  }

                  // Fallback to SOS records from history if no activity logs
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    shrinkWrap: true,
                    itemCount: sosRecords.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: cs.outlineVariant.withValues(alpha: 0.5),
                      indent: AppSpacing.md,
                      endIndent: AppSpacing.md,
                    ),
                    itemBuilder: (_, index) {
                      return _SosRecordAlertTile(
                        record: sosRecords[index],
                        cs: cs,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationAlertTile extends StatelessWidget {
  const _NotificationAlertTile({required this.log, required this.cs});
  final ActivityLogModel log;
  final ColorScheme cs;

  IconData get _icon => switch (log.type) {
        ActivityLogType.sosActivated => Icons.sos_rounded,
        ActivityLogType.locationShared => Icons.location_on_rounded,
        ActivityLogType.contactAdded => Icons.person_add_rounded,
        ActivityLogType.contactDeleted => Icons.person_remove_rounded,
        ActivityLogType.timerCompleted => Icons.timer_off_rounded,
        ActivityLogType.timerStarted => Icons.timer_rounded,
        ActivityLogType.profileUpdated => Icons.manage_accounts_rounded,
        ActivityLogType.unknown => Icons.notifications_rounded,
      };

  Color get _iconColor => switch (log.type) {
        ActivityLogType.sosActivated => AppColors.error,
        ActivityLogType.locationShared => AppColors.pastBlueIcon,
        ActivityLogType.contactAdded => AppColors.pastGreenIcon,
        ActivityLogType.contactDeleted => AppColors.error,
        ActivityLogType.timerCompleted => AppColors.pastLavenderIcon,
        ActivityLogType.timerStarted => AppColors.pastYellowIcon,
        ActivityLogType.profileUpdated => AppColors.pastPurpleIcon,
        ActivityLogType.unknown => cs.onSurfaceVariant,
      };

  Color get _bgColor => switch (log.type) {
        ActivityLogType.sosActivated => AppColors.errorContainer,
        ActivityLogType.locationShared => AppColors.pastBlue,
        ActivityLogType.contactAdded => AppColors.pastGreen,
        ActivityLogType.contactDeleted => AppColors.errorContainer,
        ActivityLogType.timerCompleted => AppColors.pastLavender,
        ActivityLogType.timerStarted => AppColors.pastYellow,
        ActivityLogType.profileUpdated => AppColors.pastPurple,
        ActivityLogType.unknown => cs.surfaceContainerHighest,
      };

  String get _statusLabel => switch (log.type) {
        ActivityLogType.sosActivated => 'Active',
        ActivityLogType.locationShared => 'Shared',
        ActivityLogType.contactAdded => 'Saved',
        ActivityLogType.contactDeleted => 'Removed',
        ActivityLogType.timerCompleted => 'Completed',
        ActivityLogType.timerStarted => 'Started',
        ActivityLogType.profileUpdated => 'Updated',
        ActivityLogType.unknown => 'Alert',
      };

  Color get _statusColor => switch (log.type) {
        ActivityLogType.sosActivated => AppColors.error,
        ActivityLogType.locationShared => AppColors.pastBlueIcon,
        ActivityLogType.contactAdded => AppColors.pastGreenIcon,
        ActivityLogType.contactDeleted => AppColors.error,
        _ => cs.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a · dd MMM yyyy').format(log.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(_icon, color: _iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.type.displayLabel,
                        style: AppTextStyles.titleSmall.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        _statusLabel,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  log.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SosRecordAlertTile extends StatelessWidget {
  const _SosRecordAlertTile({required this.record, required this.cs});
  final SosRecordModel record;
  final ColorScheme cs;

  bool get _isResolved => record.status == SosStatus.resolved;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('hh:mm a · dd MMM yyyy').format(record.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isResolved
                  ? AppColors.pastGreen
                  : AppColors.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.sos_rounded,
              color: _isResolved ? AppColors.pastGreenIcon : AppColors.error,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Emergency SOS Alert',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (_isResolved ? AppColors.success : AppColors.error)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        _isResolved ? 'Resolved' : 'Active',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: _isResolved ? AppColors.success : AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'GPS: ${record.latitude.toStringAsFixed(5)}, ${record.longitude.toStringAsFixed(5)}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 13,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timeStr,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

