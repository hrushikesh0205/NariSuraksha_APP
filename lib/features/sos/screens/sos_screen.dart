import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nari_suraksha/core/services/sms_service.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/core/widgets/widgets.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/dashboard_provider.dart';
import 'package:nari_suraksha/providers/sos_provider.dart';
import 'package:nari_suraksha/providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SosScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Premium Emergency SOS screen.
///
/// UI sections (top to bottom):
///  1. Custom top app bar
///  2. Hero SOS button with dual pulse rings + 3-second hold
///  3. Countdown preview card
///  4. Emergency action cards (Police, Ambulance, Location, SMS)
///  5. Trusted contacts list (real from ContactProvider)
///  6. SOS History (last 5 records, with Resolve action)
///  7. Emergency instructions card
class SosScreen extends StatefulWidget {
  const SosScreen({super.key, this.onSosSuccess});

  /// Called after a successful SOS to switch back to the Dashboard tab.
  final VoidCallback? onSosSuccess;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> with TickerProviderStateMixin {
  // ── Animations ──────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale1;
  late final Animation<double> _pulseOpacity1;
  late final Animation<double> _pulseScale2;
  late final Animation<double> _pulseOpacity2;

  late final AnimationController _holdCtrl;
  late final Animation<double> _holdProgress;

  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  int _countdownDigit = 3;
  bool _isHolding = false;

  /// True while [DashboardProvider.triggerSos] is running (shows overlay).
  bool _isSosTriggerLoading = false;

  static const _sosRed = Color(0xFFEF4444);
  static const _buttonSize = 150.0;

  /// Maps URL from the last successful SOS (shared with success dialog).
  String? _lastMapsUrl;

  /// Firestore doc ID of the last SOS (used for the resolve action).
  String? _lastSosDocId;

  // ── Static data ─────────────────────────────────────────────────────────────

  static const _emergencyActions = <_EmergencyAction>[
    _EmergencyAction(
      id: 'police',
      icon: Icons.local_police_rounded,
      label: 'Call Police',
      sublabel: 'Dial 100',
      color: Color(0xFF1D4ED8),
      bgColor: Color(0xFFDBEAFE),
    ),
    _EmergencyAction(
      id: 'ambulance',
      icon: Icons.local_hospital_rounded,
      label: 'Call Ambulance',
      sublabel: 'Dial 108',
      color: Color(0xFFDC2626),
      bgColor: Color(0xFFFEE2E2),
    ),
    _EmergencyAction(
      id: 'location',
      icon: Icons.location_on_rounded,
      label: 'Share Location',
      sublabel: 'Open in Maps',
      color: Color(0xFF16A34A),
      bgColor: Color(0xFFDCFCE7),
    ),
    _EmergencyAction(
      id: 'sms',
      icon: Icons.sms_rounded,
      label: 'Emergency SMS',
      sublabel: 'Alert Contacts',
      color: Color(0xFF7C3AED),
      bgColor: Color(0xFFEDE9FE),
    ),
  ];

  static const _avatarPalettes = [
    (bg: AppColors.pastYellow, fg: AppColors.pastYellowIcon),
    (bg: AppColors.pastGreen, fg: AppColors.pastGreenIcon),
    (bg: AppColors.pastLavender, fg: AppColors.pastLavenderIcon),
    (bg: AppColors.pastBlue, fg: AppColors.pastBlueIcon),
    (bg: AppColors.pastPeach, fg: AppColors.pastPeachIcon),
  ];

  static const _instructions = <String>[
    'Stay calm and take slow, deep breaths.',
    'Move to a safe, well-lit public place.',
    'Keep your phone visible and charged.',
    'Wait for help — your location is being shared.',
  ];

  // ── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Dual pulse rings (offset phase)
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    _pulseScale1 = Tween<double>(begin: 1.0, end: 1.65).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOutCubic),
    );
    _pulseOpacity1 = Tween<double>(begin: 0.50, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOutCubic),
    );
    _pulseScale2 = Tween<double>(begin: 1.0, end: 1.65).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _pulseOpacity2 = Tween<double>(begin: 0.50, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Hold countdown (3 s)
    _holdCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _holdProgress = CurvedAnimation(parent: _holdCtrl, curve: Curves.linear);
    _holdCtrl.addListener(() {
      final digit = 3 - (_holdCtrl.value * 3).floor();
      if (digit != _countdownDigit) {
        setState(() => _countdownDigit = digit.clamp(1, 3));
      }
    });
    _holdCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) _onSosTriggered();
    });

    // Entry animation
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));
    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) _entryCtrl.forward();
    });

    // Pre-load SOS history
    Future.microtask(() {
      if (mounted) context.read<SosProvider>().loadHistory();
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _holdCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Hold logic ─────────────────────────────────────────────────────────────

  void _onHoldStart() {
    if (_isSosTriggerLoading) return;
    setState(() {
      _isHolding = true;
      _countdownDigit = 3;
    });
    HapticFeedback.mediumImpact();
    _holdCtrl.forward(from: 0);
  }

  void _onHoldEnd() {
    if (_holdCtrl.isCompleted) return;
    setState(() {
      _isHolding = false;
      _countdownDigit = 3;
    });
    _holdCtrl
      ..stop()
      ..reset();
  }

  // ── SOS trigger ─────────────────────────────────────────────────────────────

  Future<void> _onSosTriggered() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = false;
      _countdownDigit = 3;
      _isSosTriggerLoading = true;
    });
    _holdCtrl.reset();

    if (!mounted) return;
    final dashProvider = context.read<DashboardProvider>();
    final result = await dashProvider.triggerSos();

    if (!mounted) return;
    setState(() => _isSosTriggerLoading = false);

    if (result.isSuccess) {
      _lastMapsUrl = result.mapsUrl;
      // Reload history to get the new doc id for the resolve action.
      await context.read<SosProvider>().loadHistory();
      if (!mounted) return;
      final history = context.read<SosProvider>().history;
      _lastSosDocId = history.isNotEmpty ? history.first.id : null;
      await _showSuccessDialog();
    } else {
      _showErrorSnackBar(result.failureReason ?? 'SOS failed. Please try again.');
    }
  }

  // ── Dialogs / snackbars ─────────────────────────────────────────────────────

  Future<void> _showSuccessDialog() => _showSuccessDialogWithSms();

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: _sosRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      duration: const Duration(seconds: 4),
    ));
  }

  // ── Emergency action handlers ───────────────────────────────────────────────

  Future<void> _handleEmergencyAction(String id) async {
    switch (id) {
      case 'police':
        await _launchPhone('100');
      case 'ambulance':
        await _launchPhone('108');
      case 'location':
        await _shareMapsUrl();
      case 'sms':
        await _showSmsContactsSheet();
    }
  }

  Future<void> _launchPhone(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      _showErrorSnackBar('Cannot open the phone dialler on this device.');
    }
  }

  Future<void> _shareMapsUrl() async {
    if (_lastMapsUrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Trigger SOS first to capture your location.',
            style: TextStyle(fontWeight: FontWeight.w600)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        duration: const Duration(seconds: 3),
      ));
      return;
    }
    final uri = Uri.parse(_lastMapsUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      _showErrorSnackBar('Cannot open Maps on this device.');
    }
  }

  // ── SMS sheet ───────────────────────────────────────────────────────────────

  /// Opens the "Alert Emergency Contacts" bottom sheet.
  ///
  /// Reads contacts from [ContactProvider], builds the emergency message using
  /// [SmsService], and opens the native SMS composer for each contact.
  Future<void> _showSmsContactsSheet() async {
    if (!mounted) return;
    final contacts = context.read<ContactProvider>().contacts;
    final userName = context.read<UserProvider>().user?.name ?? 'A Nari Suraksha user';
    final mapsUrl = _lastMapsUrl ??
        'https://www.google.com/maps/search/?api=1&query=0.0,0.0';
    final sosTime = DateTime.now();

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'No emergency contacts saved. Add contacts first.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        backgroundColor: AppColors.warning,
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    await SmsContactsSheet.show(
      context,
      contacts: contacts,
      userName: userName,
      mapsUrl: mapsUrl,
      sosTime: sosTime,
    );
  }

  Future<void> _showSuccessDialogWithSms() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SosSuccessDialog(
        mapsUrl: _lastMapsUrl,
        sosDocId: _lastSosDocId,
        onGoToDashboard: () {
          Navigator.of(context).pop();
          widget.onSosSuccess?.call();
        },
        onAlertContacts: () {
          Navigator.of(context).pop();
          _showSmsContactsSheet();
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Scrollable content
          FadeTransition(
            opacity: _entryFade,
            child: SlideTransition(
              position: _entrySlide,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Top app bar
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: cs.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 1,
                    leading: IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back_rounded),
                      tooltip: 'Back',
                    ),
                    title: Text(
                      'Emergency SOS',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    actions: [
                      IconButton(
                        onPressed: () => _showInfoDialog(context),
                        icon: Icon(Icons.info_outline_rounded, color: cs.onSurfaceVariant),
                        tooltip: 'Emergency info',
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),

                  // Hero SOS button
                  SliverToBoxAdapter(child: _buildHeroSection(cs)),

                  // Countdown preview
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, 0),
                    sliver: SliverToBoxAdapter(
                      child: _CountdownPreview(
                        digit: _countdownDigit,
                        progress: _holdProgress,
                        isActive: _isHolding,
                        cs: cs,
                      ),
                    ),
                  ),

                  // Emergency Actions
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
                    sliver: SliverToBoxAdapter(
                      child: SectionHeader(title: 'Emergency Actions', padding: EdgeInsets.zero),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                    sliver: SliverToBoxAdapter(
                      child: _EmergencyActionsGrid(
                        actions: _emergencyActions,
                        cs: cs,
                        onActionTap: _handleEmergencyAction,
                      ),
                    ),
                  ),

                  // Trusted Contacts
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
                    sliver: SliverToBoxAdapter(
                      child: SectionHeader(
                        title: 'Trusted Contacts',
                        actionLabel: 'Manage',
                        onAction: () => Navigator.of(context).pushNamed('/contacts'),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  Consumer<ContactProvider>(
                    builder: (ctx, cp, __) {
                      if (cp.isLoading) {
                        return const SliverPadding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          sliver: SliverToBoxAdapter(
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        );
                      }
                      final contacts = cp.contacts;
                      if (contacts.isEmpty) {
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                          sliver: SliverToBoxAdapter(child: _NoContactsCard(cs: cs)),
                        );
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                        sliver: SliverList.separated(
                          itemCount: contacts.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) {
                            final palette = _avatarPalettes[i % _avatarPalettes.length];
                            return _ContactTile(
                              contact: contacts[i],
                              cs: cs,
                              avatarBg: palette.bg,
                              avatarFg: palette.fg,
                            );
                          },
                        ),
                      );
                    },
                  ),

                  // SOS History
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
                    sliver: SliverToBoxAdapter(
                      child: SectionHeader(
                        title: 'SOS History',
                        actionLabel: 'Refresh',
                        onAction: () => context.read<SosProvider>().loadHistory(),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                    sliver: SliverToBoxAdapter(child: _SosHistorySection(cs: cs)),
                  ),

                  // Emergency Instructions
                  const SliverPadding(
                    padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
                    sliver: SliverToBoxAdapter(
                      child: SectionHeader(title: 'Emergency Instructions', padding: EdgeInsets.zero),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xxl),
                    sliver: SliverToBoxAdapter(
                      child: _InstructionsCard(instructions: _instructions, cs: cs),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Full-screen loading overlay while triggerSos() runs
          if (_isSosTriggerLoading) const _SosTriggerOverlay(),
        ],
      ),
    );
  }

  // ── Hero section ────────────────────────────────────────────────────────────

  Widget _buildHeroSection(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_sosRed.withValues(alpha: 0.06), cs.surface],
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onLongPressStart: (_) => _onHoldStart(),
            onLongPressEnd: (_) => _onHoldEnd(),
            onLongPressCancel: _onHoldEnd,
            child: AnimatedScale(
              scale: _isHolding ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 150),
              child: SizedBox(
                width: _buttonSize + 100,
                height: _buttonSize + 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _pulseScale1,
                      builder: (_, __) => Transform.scale(
                        scale: _pulseScale1.value,
                        child: Opacity(
                          opacity: _pulseOpacity1.value,
                          child: Container(
                            width: _buttonSize,
                            height: _buttonSize,
                            decoration: const BoxDecoration(color: _sosRed, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _pulseScale2,
                      builder: (_, __) => Transform.scale(
                        scale: _pulseScale2.value,
                        child: Opacity(
                          opacity: _pulseOpacity2.value,
                          child: Container(
                            width: _buttonSize,
                            height: _buttonSize,
                            decoration: const BoxDecoration(color: _sosRed, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: _buttonSize + 24,
                      height: _buttonSize + 24,
                      decoration: BoxDecoration(
                        color: _sosRed.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: _buttonSize,
                      height: _buttonSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [Color(0xFFFF6B6B), _sosRed],
                          stops: [0.25, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _sosRed.withValues(alpha: 0.50),
                            blurRadius: 32,
                            spreadRadius: _isHolding ? 8 : 4,
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sos_rounded, color: Colors.white, size: 58),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Tap and Hold for 3 Seconds',
            style: AppTextStyles.titleLarge.copyWith(color: _sosRed, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'This will notify your emergency contacts.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _InfoSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SosTriggerOverlay
// ─────────────────────────────────────────────────────────────────────────────

class _SosTriggerOverlay extends StatelessWidget {
  const _SosTriggerOverlay();
  static const _sosRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      child: Center(
        child: Container(
          width: 260,
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 32, offset: Offset(0, 8))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(_sosRed),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sending SOS\u2026',
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Obtaining your GPS location and\nrecording your emergency.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SosSuccessDialog
// ─────────────────────────────────────────────────────────────────────────────

class _SosSuccessDialog extends StatelessWidget {
  const _SosSuccessDialog({
    required this.mapsUrl,
    required this.sosDocId,
    required this.onGoToDashboard,
    required this.onAlertContacts,
  });

  final String? mapsUrl;
  final String? sosDocId;
  final VoidCallback onGoToDashboard;
  final VoidCallback onAlertContacts;
  static const _sosRed = Color(0xFFEF4444);

  Future<void> _openMaps() async {
    if (mapsUrl == null) return;
    final uri = Uri.parse(mapsUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      icon: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: _sosRed.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_circle_rounded, color: _sosRed, size: 32),
      ),
      title: Text(
        'SOS Alert Sent!',
        style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your emergency has been recorded in Firestore with your GPS coordinates.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (mapsUrl != null) ...[
              const SizedBox(height: AppSpacing.sm),
              InkWell(
                onTap: _openMaps,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_rounded, size: 16, color: AppColors.primaryDark),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tap to view your location in Maps',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Recorded at ${DateFormat("hh:mm a, dd MMM yyyy").format(DateTime.now())}',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
      actions: [
        // ── Alert contacts via SMS ──────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: onAlertContacts,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEDE9FE),
              foregroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sms_rounded, size: 18),
                SizedBox(width: 8),
                Text('Alert Emergency Contacts', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        // ── Resolve / Go to Dashboard ───────────────────────────────────────
        if (sosDocId != null)
          Consumer<SosProvider>(
            builder: (ctx, sp, __) => TextButton(
              onPressed: sp.isResolving
                  ? null
                  : () async {
                      final ok = await sp.resolveLatest(sosDocId!);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: Text(
                          ok ? 'Emergency resolved. Stay safe!' : sp.resolveError ?? 'Could not resolve.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: ok ? AppColors.success : AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        duration: const Duration(seconds: 3),
                      ));
                    },
              child: sp.isResolving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Resolve Emergency'),
            ),
          ),
        FilledButton(
          onPressed: onGoToDashboard,
          style: FilledButton.styleFrom(
            backgroundColor: _sosRed,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          ),
          child: const Text('Go to Dashboard'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CountdownPreview
// ─────────────────────────────────────────────────────────────────────────────

class _CountdownPreview extends StatelessWidget {
  const _CountdownPreview({
    required this.digit,
    required this.progress,
    required this.isActive,
    required this.cs,
  });

  final int digit;
  final Animation<double> progress;
  final bool isActive;
  final ColorScheme cs;
  static const _sosRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isActive ? _sosRed.withValues(alpha: 0.08) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isActive ? _sosRed.withValues(alpha: 0.40) : cs.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: AnimatedBuilder(
              animation: progress,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: isActive ? progress.value : 0,
                    strokeWidth: 5,
                    backgroundColor: cs.outlineVariant,
                    valueColor: const AlwaysStoppedAnimation<Color>(_sosRed),
                    strokeCap: StrokeCap.round,
                  ),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: isActive ? _sosRed : cs.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                    child: Text('$digit'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: AppTextStyles.titleSmall.copyWith(
                    color: isActive ? _sosRed : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  child: Text(isActive ? 'SOS activating in $digit...' : 'Hold to Activate SOS'),
                ),
                const SizedBox(height: 4),
                Text(
                  isActive ? 'Release to cancel the alert.' : 'Press and hold the button for 3 seconds.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            children: List.generate(3, (i) {
              final filled = isActive && (2 - i) >= (digit - 1);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: filled ? _sosRed : cs.outlineVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmergencyAction data class
// ─────────────────────────────────────────────────────────────────────────────

class _EmergencyAction {
  const _EmergencyAction({
    required this.id,
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.bgColor,
  });

  final String id;
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color bgColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmergencyActionsGrid
// ─────────────────────────────────────────────────────────────────────────────

class _EmergencyActionsGrid extends StatelessWidget {
  const _EmergencyActionsGrid({
    required this.actions,
    required this.cs,
    required this.onActionTap,
  });

  final List<_EmergencyAction> actions;
  final ColorScheme cs;
  final void Function(String id) onActionTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.35,
      ),
      itemCount: actions.length,
      itemBuilder: (_, i) => _EmergencyActionCard(
        action: actions[i],
        cs: cs,
        onTap: () => onActionTap(actions[i].id),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EmergencyActionCard
// ─────────────────────────────────────────────────────────────────────────────

class _EmergencyActionCard extends StatefulWidget {
  const _EmergencyActionCard({
    required this.action,
    required this.cs,
    required this.onTap,
  });

  final _EmergencyAction action;
  final ColorScheme cs;
  final VoidCallback onTap;

  @override
  State<_EmergencyActionCard> createState() => _EmergencyActionCardState();
}

class _EmergencyActionCardState extends State<_EmergencyActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final cs = widget.cs;

    return AnimatedBuilder(
      animation: _pressScale,
      builder: (_, child) => Transform.scale(scale: _pressScale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) {
          setState(() => _pressed = true);
          _pressCtrl.forward();
          HapticFeedback.selectionClick();
        },
        onTapUp: (_) {
          setState(() => _pressed = false);
          _pressCtrl.reverse();
        },
        onTapCancel: () {
          setState(() => _pressed = false);
          _pressCtrl.reverse();
        },
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(
              color: _pressed ? action.color.withValues(alpha: 0.45) : cs.outlineVariant,
            ),
            boxShadow: [
              BoxShadow(
                color: action.color.withValues(alpha: _pressed ? 0.12 : 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: action.color,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(action.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                style: AppTextStyles.titleSmall.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                action.sublabel,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NoContactsCard
// ─────────────────────────────────────────────────────────────────────────────

class _NoContactsCard extends StatelessWidget {
  const _NoContactsCard({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'No emergency contacts added yet. Add contacts so they are notified when you trigger SOS.',
              style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed('/contacts'),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ContactTile  — real phone call via url_launcher
// ─────────────────────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.cs,
    required this.avatarBg,
    required this.avatarFg,
  });

  final EmergencyContact contact;
  final ColorScheme cs;
  final Color avatarBg;
  final Color avatarFg;

  Future<void> _callContact(BuildContext context) async {
    final phone = contact.phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('No phone number available.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        duration: const Duration(seconds: 2),
      ));
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Cannot call ${contact.name} from this device.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: avatarBg, shape: BoxShape.circle),
            child: Center(
              child: Text(
                contact.initials,
                style: AppTextStyles.titleMedium.copyWith(color: avatarFg, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: AppTextStyles.titleSmall.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  contact.relation.isNotEmpty ? '${contact.relation} \u00B7 ${contact.phone}' : contact.phone,
                  style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _callContact(context),
            icon: Icon(Icons.phone_rounded, color: cs.primary, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: cs.primaryContainer,
              minimumSize: const Size(40, 40),
              padding: const EdgeInsets.all(8),
            ),
            tooltip: 'Call ${contact.name}',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SosHistorySection
// ─────────────────────────────────────────────────────────────────────────────

class _SosHistorySection extends StatelessWidget {
  const _SosHistorySection({required this.cs});
  final ColorScheme cs;
  static const _sosRed = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Consumer<SosProvider>(
      builder: (ctx, sp, __) {
        if (sp.isLoadingHistory) {
          return Container(
            height: 72,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        }
        if (sp.historyError != null) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline_rounded, color: cs.error, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(sp.historyError!,
                      style: AppTextStyles.bodySmall.copyWith(color: cs.onErrorContainer)),
                ),
                TextButton(
                  onPressed: () => ctx.read<SosProvider>().loadHistory(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (sp.history.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: cs.onSurfaceVariant, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Text('No SOS events recorded yet.',
                    style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),
          );
        }
        return Column(
          children: sp.history.asMap().entries.map((e) {
            final record = e.value;
            final isLast = e.key == sp.history.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
              child: _SosHistoryTile(
                record: record,
                cs: cs,
                sosRed: _sosRed,
                onResolve: record.status == SosStatus.active && record.id != null
                    ? () async {
                        final ok = await ctx.read<SosProvider>().resolveLatest(record.id!);
                        if (!ctx.mounted) return;
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(
                            ok ? 'Emergency marked as resolved.' : ctx.read<SosProvider>().resolveError ?? 'Could not resolve.',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          backgroundColor: ok ? AppColors.success : AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                          duration: const Duration(seconds: 3),
                        ));
                      }
                    : null,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SosHistoryTile
// ─────────────────────────────────────────────────────────────────────────────

class _SosHistoryTile extends StatelessWidget {
  const _SosHistoryTile({
    required this.record,
    required this.cs,
    required this.sosRed,
    required this.onResolve,
  });

  final SosRecordModel record;
  final ColorScheme cs;
  final Color sosRed;
  final VoidCallback? onResolve;

  @override
  Widget build(BuildContext context) {
    final isActive = record.status == SosStatus.active;
    final hasCoords = record.latitude != 0.0 || record.longitude != 0.0;
    final mapsUrl = hasCoords
        ? 'https://www.google.com/maps/search/?api=1&query=${record.latitude},${record.longitude}'
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isActive ? sosRed.withValues(alpha: 0.05) : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isActive ? sosRed.withValues(alpha: 0.30) : cs.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isActive ? sosRed.withValues(alpha: 0.12) : AppColors.pastGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isActive ? Icons.sos_rounded : Icons.check_circle_rounded,
              color: isActive ? sosRed : AppColors.pastGreenIcon,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isActive ? sosRed.withValues(alpha: 0.15) : AppColors.pastGreen,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        isActive ? 'ACTIVE' : 'RESOLVED',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isActive ? sosRed : AppColors.pastGreenIcon,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('dd MMM \u00B7 hh:mm a').format(record.timestamp),
                      style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (mapsUrl != null)
                  GestureDetector(
                    onTap: () async {
                      final uri = Uri.parse(mapsUrl);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    child: Text(
                      '${record.latitude.toStringAsFixed(5)}, ${record.longitude.toStringAsFixed(5)}  (tap to open)',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primaryDark,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                else
                  Text('Location not captured.',
                      style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant)),
                if (onResolve != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Consumer<SosProvider>(
                      builder: (_, sp, __) => TextButton.icon(
                        onPressed: sp.isResolving ? null : onResolve,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.success,
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: sp.isResolving
                            ? const SizedBox(
                                width: 12, height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_circle_outline_rounded, size: 16),
                        label: Text(
                          sp.isResolving ? 'Resolving\u2026' : 'Mark as Resolved',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.success, fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
// _InstructionsCard
// ─────────────────────────────────────────────────────────────────────────────

class _InstructionsCard extends StatelessWidget {
  const _InstructionsCard({required this.instructions, required this.cs});

  final List<String> instructions;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.primary.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.health_and_safety_rounded, color: cs.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Stay Safe \u2014 What To Do',
                style: AppTextStyles.titleSmall.copyWith(color: cs.primary, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),
          ...instructions.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: cs.onPrimary, fontWeight: FontWeight.w700, fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InfoSheet
// ─────────────────────────────────────────────────────────────────────────────

class _InfoSheet extends StatelessWidget {
  const _InfoSheet();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            const SizedBox(height: AppSpacing.lg),
            Text(
              'About Emergency SOS',
              style: AppTextStyles.titleLarge.copyWith(color: cs.onSurface, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Emergency SOS records your GPS coordinates in Firestore and provides '
              'quick access to emergency services. Hold the red SOS button for 3 seconds '
              'to activate.\n\n'
              'After activating you can:\n'
              '\u2022  View your location in Google Maps.\n'
              '\u2022  Call Police (100) or Ambulance (108) directly.\n'
              '\u2022  Call any trusted contact from the list below.\n'
              '\u2022  Mark the emergency as resolved once you are safe.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: AppSpacing.lg),
            const StatusCard(
              icon: Icons.lock_rounded,
              title: 'Your Privacy is Protected',
              message: 'Location data is only recorded during active emergencies.',
              variant: StatusVariant.info,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}

