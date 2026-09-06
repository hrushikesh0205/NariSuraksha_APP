import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/providers/sos_escalation_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SafetyCheckSheet
// ─────────────────────────────────────────────────────────────────────────────

/// Reusable safety confirmation sheet shown at T=4 min and T=8 min during an active SOS.
///
/// Gives the user a chance to confirm they are safe (which immediately halts escalation
/// and marks the SOS resolved) or confirm they are still in danger (which triggers
/// the next priority tier immediately).
///
/// Features a 30-second timeout: If the user does not respond within 30 seconds,
/// it automatically treats the situation as danger and sends the next tier's SMS.
class SafetyCheckSheet extends StatefulWidget {
  const SafetyCheckSheet({
    super.key,
    required this.escalationPriority,
    required this.onSafe,
    required this.onStillInDanger,
  });

  final ContactPriority escalationPriority;
  final VoidCallback onSafe;
  final VoidCallback onStillInDanger;

  static Future<void> show(
    BuildContext context, {
    required ContactPriority escalationPriority,
    required VoidCallback onSafe,
    required VoidCallback onStillInDanger,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => SafetyCheckSheet(
        escalationPriority: escalationPriority,
        onSafe: onSafe,
        onStillInDanger: onStillInDanger,
      ),
    );
  }

  @override
  State<SafetyCheckSheet> createState() => _SafetyCheckSheetState();
}

class _SafetyCheckSheetState extends State<SafetyCheckSheet> {
  static const int _timeoutSeconds = 30;
  int _secondsRemaining = _timeoutSeconds;
  Timer? _countdownTimer;
  bool _actionTaken = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _handleStillInDanger(isTimeout: true);
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handleSafe() {
    if (_actionTaken) return;
    _actionTaken = true;
    _countdownTimer?.cancel();
    Navigator.of(context).pop();
    widget.onSafe();
  }

  void _handleStillInDanger({bool isTimeout = false}) {
    if (_actionTaken) return;
    _actionTaken = true;
    _countdownTimer?.cancel();
    if (mounted) {
      Navigator.of(context).pop();
    }
    if (isTimeout) {
      debugPrint('🚨 SafetyCheckSheet: 30s timeout elapsed without response. Auto-escalating...');
    }
    widget.onStillInDanger();
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer<SosEscalationProvider>(
      builder: (context, escalationProv, _) {
        final elapsed = escalationProv.elapsed;

        return Container(
          margin: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Top warning bar ──────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xxl),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'ACTIVE EMERGENCY · ${_formatElapsed(elapsed)}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    // Icon
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFFD97706),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Header matching required prompt exactly
                    Text(
                      '🚨 ARE YOU SAFE?',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "We haven't received confirmation that you are safe.\nPlease confirm your current situation.",
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Timeout countdown badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        'Auto-alerting ${widget.escalationPriority.displayLabel} in ${_secondsRemaining}s if unanswered',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Buttons ──────────────────────────────────────────────
                    // [ I'M SAFE ]
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _handleSafe,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle_rounded, size: 20),
                        label: const Text(
                          "I'M SAFE",
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // [ I'M STILL IN DANGER ]
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleStillInDanger(isTimeout: false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(
                              color: AppColors.error, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button),
                          ),
                        ),
                        icon: const Icon(Icons.emergency_rounded, size: 20),
                        label: Text(
                          "I'M STILL IN DANGER (Alert ${widget.escalationPriority.shortLabel})",
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
