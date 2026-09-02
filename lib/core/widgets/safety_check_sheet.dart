import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/providers/sos_escalation_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SafetyCheckSheet
// ─────────────────────────────────────────────────────────────────────────────

/// Reusable safety confirmation sheet shown at T=2 min and T=5 min during an active SOS.
///
/// Gives the user a chance to confirm they are safe (which immediately halts escalation
/// and marks the SOS resolved) or confirm they are still in danger (which triggers
/// the next priority tier immediately).
class SafetyCheckSheet extends StatelessWidget {
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

                    Text(
                      'Are You Safe Now?',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'High Priority contacts were alerted when SOS started. '
                      'We are ready to alert your ${escalationPriority.displayLabel} contacts.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Buttons ──────────────────────────────────────────────
                    // "Yes, I'm Safe"
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onSafe();
                        },
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
                          "Yes, I'm Safe (Resolve SOS)",
                          style: TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // "I'm Still in Danger"
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onStillInDanger();
                        },
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
                          "I'm Still in Danger (Alert ${escalationPriority.shortLabel})",
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14),
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
