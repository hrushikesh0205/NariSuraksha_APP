import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'package:nari_suraksha/core/services/voice_sos_service.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/core/widgets/sos_success_sheet.dart';
import 'package:nari_suraksha/providers/dashboard_provider.dart';
import 'package:nari_suraksha/providers/sos_provider.dart';
import 'package:nari_suraksha/providers/voice_sos_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VoiceSosScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Voice SOS Emergency Keyword Detection Screen.
///
/// Features:
/// - Real-time keyword listening with animated pulse rings.
/// - Live transcription display of recognized speech.
/// - Supported emergency phrase chips.
/// - Permission request & error handling.
/// - Automatic trigger of existing SOS pipeline upon keyword match.
/// - Instant presentation of [SosSuccessSheet] / SMS alert flow.
class VoiceSosScreen extends StatefulWidget {
  const VoiceSosScreen({super.key});

  @override
  State<VoiceSosScreen> createState() => _VoiceSosScreenState();
}

class _VoiceSosScreenState extends State<VoiceSosScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseScale1;
  late final Animation<double> _pulseOpacity1;
  late final Animation<double> _pulseScale2;
  late final Animation<double> _pulseOpacity2;

  late final AnimationController _waveCtrl;

  bool _isSuccessSheetShown = false;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the listening microphone button
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
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
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _pulseOpacity2 = Tween<double>(begin: 0.50, end: 0.0).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Audio wave simulation animation
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Initialize provider when entering the screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final voiceProv = context.read<VoiceSosProvider>();
        if (!voiceProv.isInitialized) {
          voiceProv.initialize();
        }
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _waveCtrl.dispose();

    // Stop microphone listening when leaving screen to protect user privacy & battery
    try {
      final voiceProv = context.read<VoiceSosProvider>();
      if (voiceProv.isListening) {
        voiceProv.stopListening();
      }
    } catch (_) {}

    super.dispose();
  }

  Future<void> _handleToggleListening(VoiceSosProvider provider) async {
    HapticFeedback.mediumImpact();

    if (provider.state == VoiceSosState.permissionPermanentlyDenied) {
      await openAppSettings();
      await provider.initialize();
      return;
    }

    if (provider.state == VoiceSosState.permissionRequired) {
      final ok = await provider.initialize();
      if (!ok) return;
    }

    if (provider.state == VoiceSosState.sosTriggered ||
        provider.state == VoiceSosState.emergencyDetected) {
      provider.reset();
    }

    await provider.toggleListening();
  }

  void _checkAndShowSosSuccess(VoiceSosProvider provider) {
    if (provider.state == VoiceSosState.sosTriggered &&
        provider.lastSosResult != null &&
        provider.lastSosResult!.isSuccess &&
        !_isSuccessSheetShown) {
      _isSuccessSheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        // Reload SOS history so we can pass the newly-created doc ID to SosSuccessSheet
        await context.read<SosProvider>().loadHistory();
        if (!mounted) return;

        final history = context.read<SosProvider>().history;
        final sosDocId = provider.lastSosResult?.docId ??
            (history.isNotEmpty ? history.first.id : null);
        final sosTime = provider.lastSosTime ?? DateTime.now();

        await SosSuccessSheet.show(
          context,
          mapsUrl: provider.lastSosResult!.mapsUrl,
          sosTime: sosTime,
          sosDocId: sosDocId,
          onDone: () {
            _isSuccessSheetShown = false;
            provider.reset();
          },
        );
        _isSuccessSheetShown = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<VoiceSosProvider>(
      builder: (context, voiceProv, _) {
        _checkAndShowSosSuccess(voiceProv);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: cs.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
            title: Text(
              'Voice SOS',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.info_outline_rounded),
                onPressed: () => _showVoiceSosInfoDialog(context),
                tooltip: 'Voice SOS Help',
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Top Status Pill ──────────────────────────────────────────
                  _buildStatusPill(voiceProv, cs),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Hero Microphone Animation ────────────────────────────────
                  _buildHeroMicButton(voiceProv, cs),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Status Title & Subtitle ──────────────────────────────────
                  _buildStatusText(voiceProv, cs),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Live Speech Transcript Box ───────────────────────────────
                  _buildTranscriptBox(voiceProv, cs),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Action Button ────────────────────────────────────────────
                  _buildMainActionButton(voiceProv, cs),
                  const SizedBox(height: AppSpacing.xl),

                  // ── Configured Emergency Phrases ─────────────────────────────
                  _buildPhrasesCard(voiceProv, cs),
                  const SizedBox(height: AppSpacing.lg),

                  // ── Safety / Privacy Notice ──────────────────────────────────
                  _buildPrivacyNotice(cs),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildStatusPill(VoiceSosProvider provider, ColorScheme cs) {
    Color bg;
    Color fg;
    IconData icon;
    String label;

    switch (provider.state) {
      case VoiceSosState.listening:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        icon = Icons.mic_rounded;
        label = 'Voice SOS Active · Listening';
      case VoiceSosState.emergencyDetected:
      case VoiceSosState.triggeringSos:
        bg = const Color(0xFFFEE2E2);
        fg = AppColors.error;
        icon = Icons.warning_amber_rounded;
        label = 'Emergency Phrase Detected!';
      case VoiceSosState.sosTriggered:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        icon = Icons.check_circle_rounded;
        label = 'SOS Triggered Successfully';
      case VoiceSosState.permissionRequired:
      case VoiceSosState.permissionPermanentlyDenied:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        icon = Icons.mic_off_rounded;
        label = 'Microphone Permission Required';
      case VoiceSosState.unavailable:
      case VoiceSosState.error:
        bg = const Color(0xFFFEE2E2);
        fg = AppColors.error;
        icon = Icons.error_outline_rounded;
        label = provider.errorMessage ?? 'Voice Recognition Error';
      case VoiceSosState.idle:
      case VoiceSosState.initializing:
        bg = AppColors.primaryContainer;
        fg = AppColors.primaryDark;
        icon = Icons.shield_outlined;
        label = 'Voice SOS Ready';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroMicButton(VoiceSosProvider provider, ColorScheme cs) {
    final isListening = provider.isListening;
    final isTriggering = provider.state == VoiceSosState.triggeringSos ||
        provider.state == VoiceSosState.emergencyDetected;
    final isSuccess = provider.state == VoiceSosState.sosTriggered;

    Color buttonBg = AppColors.primary;
    if (isListening) {
      buttonBg = const Color(0xFF16A34A);
    } else if (isTriggering || isSuccess) {
      buttonBg = AppColors.error;
    }

    const double buttonSize = 130;

    return GestureDetector(
      onTap: () => _handleToggleListening(provider),
      child: SizedBox(
        width: buttonSize + 80,
        height: buttonSize + 80,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulse rings when actively listening
            if (isListening) ...[
              AnimatedBuilder(
                animation: _pulseScale1,
                builder: (_, __) => Transform.scale(
                  scale: _pulseScale1.value,
                  child: Opacity(
                    opacity: _pulseOpacity1.value,
                    child: Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: buttonBg,
                        shape: BoxShape.circle,
                      ),
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
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: buttonBg,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Soft glow ring
            Container(
              width: buttonSize + 20,
              height: buttonSize + 20,
              decoration: BoxDecoration(
                color: buttonBg.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
            ),

            // Main central button
            Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    buttonBg.withValues(alpha: 0.85),
                    buttonBg,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: buttonBg.withValues(alpha: isListening ? 0.40 : 0.25),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: isTriggering
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 4,
                        ),
                      )
                    : Icon(
                        isListening
                            ? Icons.mic_rounded
                            : (isSuccess
                                ? Icons.check_rounded
                                : Icons.mic_none_rounded),
                        color: Colors.white,
                        size: 56,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusText(VoiceSosProvider provider, ColorScheme cs) {
    String title;
    String subtitle;

    switch (provider.state) {
      case VoiceSosState.listening:
        title = 'Listening for Emergency Keywords';
        subtitle = 'Say "Help", "Emergency", or "Save me" clearly';
      case VoiceSosState.emergencyDetected:
      case VoiceSosState.triggeringSos:
        title = 'Emergency Keyword Detected!';
        subtitle = 'Triggering emergency SOS and notifying contacts…';
      case VoiceSosState.sosTriggered:
        title = 'SOS Alert Sent!';
        subtitle = 'Your emergency contacts and location have been alerted.';
      case VoiceSosState.permissionRequired:
        title = 'Microphone Access Required';
        subtitle = 'Tap the button below to grant microphone permission.';
      case VoiceSosState.permissionPermanentlyDenied:
        title = 'Microphone Permission Blocked';
        subtitle = 'Please enable microphone access in your device settings.';
      case VoiceSosState.unavailable:
        title = 'Voice Detection Unavailable';
        subtitle = 'Speech recognition is not supported on this device.';
      case VoiceSosState.error:
        title = 'Voice SOS Error';
        subtitle = provider.errorMessage ?? 'Please try again.';
      case VoiceSosState.idle:
      case VoiceSosState.initializing:
        title = 'Voice SOS Protection';
        subtitle = 'Tap the microphone or button below to start voice detection.';
    }

    return Column(
      children: [
        Text(
          title,
          style: AppTextStyles.titleLarge.copyWith(
            color: cs.onSurface,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(
            color: cs.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTranscriptBox(VoiceSosProvider provider, ColorScheme cs) {
    final text = provider.recognizedText.trim();
    final isListening = provider.isListening;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(
          color: isListening ? const Color(0xFF86EFAC) : cs.outlineVariant,
          width: isListening ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.record_voice_over_rounded,
                size: 18,
                color: isListening ? const Color(0xFF16A34A) : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Recognized Speech',
                style: AppTextStyles.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (isListening)
                Row(
                  children: List.generate(4, (index) {
                    return AnimatedBuilder(
                      animation: _waveCtrl,
                      builder: (_, __) {
                        final waveVal = (_waveCtrl.value + (index * 0.25)) % 1.0;
                        final height = 6.0 + (waveVal * 12.0);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          width: 3,
                          height: height,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      },
                    );
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              text.isNotEmpty
                  ? '"$text"'
                  : (isListening
                      ? 'Listening… Speak an emergency phrase'
                      : 'Audio preview will appear here when listening'),
              style: AppTextStyles.bodyMedium.copyWith(
                color: text.isNotEmpty ? cs.onSurface : cs.onSurfaceVariant.withValues(alpha: 0.7),
                fontStyle: text.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                fontWeight: text.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButton(VoiceSosProvider provider, ColorScheme cs) {
    final isListening = provider.isListening;
    final isTriggering = provider.state == VoiceSosState.triggeringSos ||
        provider.state == VoiceSosState.emergencyDetected;

    String buttonLabel;
    IconData buttonIcon;
    Color buttonColor;

    if (provider.state == VoiceSosState.permissionPermanentlyDenied) {
      buttonLabel = 'Open App Settings';
      buttonIcon = Icons.settings_rounded;
      buttonColor = const Color(0xFFD97706);
    } else if (provider.state == VoiceSosState.permissionRequired) {
      buttonLabel = 'Grant Microphone Permission';
      buttonIcon = Icons.mic_rounded;
      buttonColor = AppColors.primary;
    } else if (isListening) {
      buttonLabel = 'Stop Listening';
      buttonIcon = Icons.stop_rounded;
      buttonColor = AppColors.error;
    } else if (isTriggering) {
      buttonLabel = 'Triggering SOS…';
      buttonIcon = Icons.emergency_rounded;
      buttonColor = AppColors.error;
    } else {
      buttonLabel = 'Start Listening';
      buttonIcon = Icons.mic_rounded;
      buttonColor = const Color(0xFF16A34A);
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: isTriggering ? null : () => _handleToggleListening(provider),
        style: FilledButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          elevation: 2,
        ),
        icon: isTriggering
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Icon(buttonIcon, size: 22),
        label: Text(
          buttonLabel,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildPhrasesCard(VoiceSosProvider provider, ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Text(
                'Supported Emergency Phrases',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Speaking any of these triggers the full SOS pipeline automatically:',
            style: AppTextStyles.bodySmall.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: provider.emergencyPhrases.map((phrase) {
              final isMatched = provider.lastDetectedPhrase == phrase;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isMatched
                      ? AppColors.errorContainer
                      : AppColors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: isMatched ? AppColors.error : AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isMatched ? Icons.check_circle_rounded : Icons.campaign_rounded,
                      size: 14,
                      color: isMatched ? AppColors.error : AppColors.primaryDark,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '"$phrase"',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: isMatched ? AppColors.error : AppColors.primaryDark,
                        fontWeight: isMatched ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyNotice(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF64748B)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Privacy First: Voice data is processed strictly for keyword detection and is never recorded or stored.',
              style: AppTextStyles.bodySmall.copyWith(
                color: const Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVoiceSosInfoDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.mic_rounded, color: Color(0xFF16A34A), size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How Voice SOS Works',
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Hands-free emergency triggering',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildInfoBullet('1. Start Listening', 'Tap the Start Listening button when you are in an alert situation.'),
              _buildInfoBullet('2. Speak Keyword', 'Speak any supported emergency keyword like "Help" or "Emergency".'),
              _buildInfoBullet('3. Automatic SOS', 'The app immediately captures GPS coordinates, records the SOS in Firestore, logs activity, and prepares emergency SMS.'),
              _buildInfoBullet('4. False Positive Protection', 'Words like "helper" or "helpful" will not accidentally trigger SOS.'),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBullet(String heading, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF16A34A)),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                children: [
                  TextSpan(text: '$heading: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
