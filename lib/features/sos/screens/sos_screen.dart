import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nari_suraksha/core/services/location_service.dart';
import 'package:nari_suraksha/core/services/sms_service.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/core/widgets/widgets.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/dashboard_provider.dart';
import 'package:nari_suraksha/providers/sos_provider.dart';
import 'package:nari_suraksha/providers/sos_escalation_provider.dart';
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

  /// True when a safety check or police confirmation sheet is currently showing.
  bool _isEscalationSheetShowing = false;

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

    // Listen to escalation provider for auto-showing safety check and police sheets
    Future.microtask(() {
      if (mounted) {
        context.read<SosEscalationProvider>().addListener(_onEscalationStateChanged);
      }
    });
  }

  @override
  void dispose() {
    // Safely remove listener — the provider may have been disposed already
    try {
      context.read<SosEscalationProvider>().removeListener(_onEscalationStateChanged);
    } catch (_) {}
    _pulseCtrl.dispose();
    _holdCtrl.dispose();
    _entryCtrl.dispose();
    super.dispose();
  }

  // ── Escalation auto-show logic ──────────────────────────────────────────

  void _onEscalationStateChanged() {
    if (!mounted || _isEscalationSheetShowing) return;
    final escalation = context.read<SosEscalationProvider>();

    // Auto-show safety check sheet
    if (escalation.isSafetyCheckPending && escalation.pendingEscalationPriority != null) {
      _isEscalationSheetShowing = true;
      SafetyCheckSheet.show(
        context,
        escalationPriority: escalation.pendingEscalationPriority!,
        onSafe: () {
          _isEscalationSheetShowing = false;
          escalation.resolveEmergency();
        },
        onStillInDanger: () {
          _isEscalationSheetShowing = false;
          escalation.confirmStillInDanger();
        },
      ).then((_) => _isEscalationSheetShowing = false);
      return;
    }

    // Auto-show police confirmation sheet
    if (escalation.isPoliceConfirmationPending) {
      _isEscalationSheetShowing = true;
      PoliceConfirmationSheet.show(
        context,
        onCallPolice: () {
          _isEscalationSheetShowing = false;
          escalation.authorizePoliceCall();
        },
        onSafe: () {
          _isEscalationSheetShowing = false;
          escalation.declinePoliceCall();
        },
      ).then((_) => _isEscalationSheetShowing = false);
    }
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
      _lastSosDocId = result.docId ?? (history.isNotEmpty ? history.first.id : null);
      if (_lastSosDocId != null) {
        final uid = context.read<UserProvider>().currentUid ?? '';
        final userName = context.read<UserProvider>().user?.name ?? 'A Nari Suraksha user';
        final contacts = context.read<ContactProvider>().contacts;
        final escalation = context.read<SosEscalationProvider>();

        // Sync contacts and user name for auto-SMS dispatch
        escalation.updateContacts(contacts);
        escalation.updateUserName(userName);

        // Parse lat/lng from mapsUrl for session tracking
        double lat = 0;
        double lng = 0;
        if (_lastMapsUrl != null) {
          final match = RegExp(r'q=([\d.-]+),([\d.-]+)').firstMatch(_lastMapsUrl!);
          if (match != null) {
            lat = double.tryParse(match.group(1) ?? '') ?? 0;
            lng = double.tryParse(match.group(2) ?? '') ?? 0;
          }
        }

        escalation.startSession(
              sosDocId: _lastSosDocId!,
              userId: uid,
              latitude: lat,
              longitude: lng,
              mapsUrl: _lastMapsUrl ?? '',
              startedAt: DateTime.now(),
              triggerSource: 'button',
            );
      }
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
        if (!mounted) return;
        await _showLocationSheet();
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

  /// Opens the live-location bottom sheet.
  Future<void> _showLocationSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LocationBottomSheet(),
    );
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

                  // Active Escalation Status
                  Consumer<SosEscalationProvider>(
                    builder: (ctx, ep, __) {
                      if (!ep.hasActiveSession) {
                        return const SliverToBoxAdapter(child: SizedBox.shrink());
                      }
                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
                        sliver: SliverToBoxAdapter(
                          child: _EscalationStatusPanel(cs: cs),
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
  });

  final String? mapsUrl;
  final String? sosDocId;
  final VoidCallback onGoToDashboard;
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
        'SOS Alert Active',
        style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your emergency has been recorded with live GPS. Contact priority escalation is running automatically.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),

            // Live Automatic SMS Dispatch Banner
            Consumer<SosEscalationProvider>(
              builder: (ctx, ep, _) {
                final isSending = ep.isSendingSms;
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: isSending ? const Color(0xFFFEF3C7) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isSending ? const Color(0xFFF59E0B) : const Color(0xFF86EFAC),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (isSending)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD97706)),
                        )
                      else
                        const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isSending
                              ? 'Sending background emergency SMS...'
                              : 'High Priority contacts alerted automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSending ? const Color(0xFFB45309) : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
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
        // ── Resolve / I'm Safe ───────────────────────────────────────
        Consumer2<SosProvider, SosEscalationProvider>(
          builder: (ctx, sp, ep, __) => SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: sp.isResolving
                  ? null
                  : () async {
                      await ep.resolveEmergency();
                      if (sosDocId != null) {
                        await sp.resolveLatest(sosDocId!);
                      }
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                        content: const Text(
                          'Emergency resolved. Stay safe!',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        duration: const Duration(seconds: 3),
                      ));
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
              ),
              child: sp.isResolving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("I'm Safe (Resolve SOS)", style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onGoToDashboard,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
            ),
            child: const Text('Back to Dashboard'),
          ),
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
// _EscalationStatusPanel
// ─────────────────────────────────────────────────────────────────────────────

class _EscalationStatusPanel extends StatelessWidget {
  const _EscalationStatusPanel({required this.cs});
  final ColorScheme cs;

  static const _sosRed = Color(0xFFEF4444);

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final escalation = context.watch<SosEscalationProvider>();
    final session = escalation.activeSession;
    if (session == null || session.isResolved) {
      return const SizedBox.shrink();
    }

    final contacts = context.watch<ContactProvider>().contacts;
    final highContacts = contacts.where((c) => c.priority == ContactPriority.high).toList();
    final medContacts = contacts.where((c) => c.priority == ContactPriority.medium).toList();
    final lowContacts = contacts.where((c) => c.priority == ContactPriority.low).toList();

    final seconds = escalation.elapsed.inSeconds;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _sosRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: _sosRed.withValues(alpha: 0.35), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status badge + Timer
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _sosRed.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield, color: _sosRed, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE EMERGENCY SOS',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: _sosRed,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      'Automated escalation in progress',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _sosRed,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuration(escalation.elapsed),
                      style: AppTextStyles.labelSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.md),

          // Escalation Tiers
          Text(
            'Escalation Tiers',
            style: AppTextStyles.labelMedium.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // High Priority Tier (T=0)
          _buildTierRow(
            title: 'High Priority Contacts',
            timing: 'T = 0m',
            isAlerted: session.isHighAlerted,
            contactsCount: highContacts.length,
            cs: cs,
          ),
          const SizedBox(height: 6),

          // Medium Priority Tier (T=2m)
          _buildTierRow(
            title: 'Medium Priority Contacts',
            timing: session.isMediumAlerted
                ? 'Alerted'
                : seconds < 120
                    ? 'In ${120 - seconds}s'
                    : 'Pending Check',
            isAlerted: session.isMediumAlerted,
            contactsCount: medContacts.length,
            cs: cs,
          ),
          const SizedBox(height: 6),

          // Low Priority Tier (T=5m)
          _buildTierRow(
            title: 'Low Priority Contacts',
            timing: session.isLowAlerted
                ? 'Alerted'
                : seconds < 300
                    ? 'In ${300 - seconds}s'
                    : 'Pending Check',
            isAlerted: session.isLowAlerted,
            contactsCount: lowContacts.length,
            cs: cs,
          ),
          const SizedBox(height: 6),

          // Police Tier (112)
          _buildTierRow(
            title: 'Police / Emergency (112)',
            timing: session.policeCallAuthorized == true
                ? 'Authorized'
                : 'Confirmation Required',
            isAlerted: session.policeCallAuthorized == true,
            contactsCount: null,
            cs: cs,
            isPolice: true,
          ),

          // Sending SMS indicator
          if (escalation.isSendingSms) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _sosRed),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Sending emergency SMS to contacts...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: _sosRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          // Action buttons: "I'M SAFE" and "CALL 112"
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Resolve Emergency?'),
                        content: const Text(
                          'Are you sure you want to mark this emergency as resolved and stop further escalation?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('I am Safe'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true && context.mounted) {
                      await context.read<SosEscalationProvider>().resolveEmergency();
                      if (context.mounted) {
                        context.read<SosProvider>().loadHistory();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Emergency marked as resolved.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text("I'm Safe"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () {
                    PoliceConfirmationSheet.show(
                      context,
                      onCallPolice: () {
                        context.read<SosEscalationProvider>().authorizePoliceCall();
                      },
                      onSafe: () {
                        context.read<SosEscalationProvider>().declinePoliceCall();
                      },
                    );
                  },
                  icon: const Icon(Icons.local_police, size: 18, color: _sosRed),
                  label: const Text('Call 112', style: TextStyle(color: _sosRed)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _sosRed),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTierRow({
    required String title,
    required String timing,
    required bool isAlerted,
    required int? contactsCount,
    required ColorScheme cs,
    bool isPolice = false,
  }) {
    final statusColor = isAlerted ? AppColors.success : (isPolice ? _sosRed : cs.onSurfaceVariant);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: isAlerted ? AppColors.success.withValues(alpha: 0.3) : cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAlerted ? Icons.check_circle : (isPolice ? Icons.local_police_outlined : Icons.schedule),
            color: statusColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              contactsCount != null ? '$title ($contactsCount)' : title,
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: isAlerted ? FontWeight.w600 : FontWeight.normal,
                color: cs.onSurface,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              timing,
              style: AppTextStyles.labelSmall.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
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
// _LocationBottomSheet
// ─────────────────────────────────────────────────────────────────────────────

/// Live-location bottom sheet opened when the user taps the "Share Location"
/// emergency action card.
///
/// On open it immediately fetches the device's current GPS position using
/// [LocationService] and presents two actions:
///  - **Open in Maps** — launches Google Maps with the coordinates.
///  - **Share Location** — opens the native Android share sheet so the user
///    can send the location URL via WhatsApp, SMS, etc.
class LocationBottomSheet extends StatefulWidget {
  const LocationBottomSheet({super.key, this.locationService});

  /// Injectable for testing — defaults to [LocationService].
  final LocationService? locationService;

  @override
  State<LocationBottomSheet> createState() => _LocationBottomSheetState();
}

enum _LocationState { loading, success, error }

class _LocationBottomSheetState extends State<LocationBottomSheet> {
  static const _greenColor = Color(0xFF16A34A);

  late final LocationService _locationService;
  _LocationState _state = _LocationState.loading;
  double? _lat;
  double? _lng;
  String _errorMessage = 'Unable to get your current location. Please enable location services.';
  bool _isOpeningMaps = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _locationService = widget.locationService ?? LocationService();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() => _state = _LocationState.loading);
    try {
      final position = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _state = _LocationState.success;
      });
    } catch (e) {
      debugPrint('📍 _LocationBottomSheet.fetchLocation error: $e');
      if (!mounted) return;
      final msg = e.toString().toLowerCase();
      String friendlyMsg;
      if (msg.contains('disabled') || msg.contains('service')) {
        friendlyMsg = 'Location services are disabled. Please enable GPS in Settings.';
      } else if (msg.contains('permission') || msg.contains('denied')) {
        friendlyMsg = 'Location permission denied. Please grant location access in Settings.';
      } else if (msg.contains('timeout') || msg.contains('time')) {
        friendlyMsg = 'Location request timed out. Please try again.';
      } else {
        friendlyMsg = 'Unable to get your current location. Please enable location services.';
      }
      setState(() {
        _errorMessage = friendlyMsg;
        _state = _LocationState.error;
      });
    }
  }

  String get _mapsUrl =>
      'https://www.google.com/maps/search/?api=1&query=${_lat!},${_lng!}';

  String get _shareText =>
      'Nari Suraksha \u2014 My Current Location\n\n'
      'I am sharing my current location with you.\n\n'
      'Location:\n$_mapsUrl';

  Future<void> _openInMaps() async {
    if (_lat == null || _lng == null) return;
    setState(() => _isOpeningMaps = true);
    try {
      final uri = Uri.parse(_mapsUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        _showSnack('Cannot open Maps on this device.');
      }
    } finally {
      if (mounted) setState(() => _isOpeningMaps = false);
    }
  }

  Future<void> _shareLocation() async {
    if (_lat == null || _lng == null) return;
    setState(() => _isSharing = true);
    try {
      await Share.share(_shareText, subject: 'Nari Suraksha \u2014 My Current Location');
    } catch (e) {
      debugPrint('📤 _LocationBottomSheet.shareLocation error: $e');
      if (mounted) _showSnack('Unable to open share sheet. Please try again.');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

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
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: AppSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
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

            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: _greenColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT LOCATION',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    Text(
                      _state == _LocationState.loading
                          ? 'Fetching GPS...'
                          : _state == _LocationState.success
                              ? '\u{1F4CD} Location detected'
                              : 'Location unavailable',
                      style: AppTextStyles.titleSmall.copyWith(
                        color: _state == _LocationState.success
                            ? _greenColor
                            : _state == _LocationState.error
                                ? cs.error
                                : cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),

            // Content
            if (_state == _LocationState.loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.md),
                      Text('Getting your current location...'),
                    ],
                  ),
                ),
              )
            else if (_state == _LocationState.success) ...[
              // Coordinates card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: _greenColor.withValues(alpha: 0.30)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gps_fixed_rounded, color: _greenColor, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'GPS Fix Acquired',
                          style: AppTextStyles.labelMedium.copyWith(
                            color: _greenColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_lat!.toStringAsFixed(6)}, ${_lng!.toStringAsFixed(6)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: const Color(0xFF166534),
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Open in Maps button
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _isOpeningMaps ? null : _openInMaps,
                  icon: _isOpeningMaps
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.map_rounded),
                  label: const Text('Open in Maps'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _greenColor),
                    foregroundColor: _greenColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Share Location button
              SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: _isSharing ? null : _shareLocation,
                  icon: _isSharing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.share_rounded),
                  label: const Text('Share Location'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _greenColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Error state
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cs.errorContainer.withValues(alpha: 0.50),
                  borderRadius: BorderRadius.circular(AppRadius.card),
                  border: Border.all(color: cs.error.withValues(alpha: 0.30)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_off_rounded, color: cs.error, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: AppTextStyles.bodySmall.copyWith(color: cs.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _fetchLocation,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 50,
                child: TextButton.icon(
                  onPressed: () async {
                    await LocationService().openLocationSettings();
                  },
                  icon: const Icon(Icons.settings_rounded),
                  label: const Text('Open Location Settings'),
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.button),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.sm),
          ],
        ),
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

