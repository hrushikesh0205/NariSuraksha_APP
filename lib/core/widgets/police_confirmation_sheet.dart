import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/providers/sos_escalation_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PoliceConfirmationSheet
// ─────────────────────────────────────────────────────────────────────────────

/// Final emergency escalation confirmation sheet.
///
/// Shown after all contact tiers (High → Medium → Low) have been alerted and the
/// SOS is still unresolved.  Gives the user a clear choice to either:
///   1. Call Police / Emergency Services (112) — opens dialer with 112 pre-filled.
///   2. Confirm they are safe — resolves the SOS immediately.
///
/// **NEVER** auto-dials 112; the user must explicitly confirm.
class PoliceConfirmationSheet extends StatelessWidget {
  const PoliceConfirmationSheet({
    super.key,
    required this.onCallPolice,
    required this.onSafe,
  });

  final VoidCallback onCallPolice;
  final VoidCallback onSafe;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onCallPolice,
    required VoidCallback onSafe,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => PoliceConfirmationSheet(
        onCallPolice: onCallPolice,
        onSafe: onSafe,
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  Future<void> _launchDialer() async {
    final uri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 28,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Critical warning bar ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xxl),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.sos_rounded,
                        color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'EMERGENCY UNRESOLVED · ${_formatElapsed(elapsed)}',
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
                    // ── Alert icon ───────────────────────────────────────────
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.local_police_rounded,
                        color: AppColors.error,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Text(
                      '🚨 EMERGENCY ESCALATION',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    Text(
                      'You have not confirmed that you are safe.\n'
                      'Do you want to contact Police / Emergency Services?',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Escalation status ────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Column(
                        children: [
                          _EscalationStep(
                            label: 'High Priority (T=0)',
                            isComplete: true,
                            color: Color(0xFFDC2626),
                          ),
                          SizedBox(height: 4),
                          _EscalationStep(
                            label: 'Medium Priority (T=4m)',
                            isComplete: true,
                            color: Color(0xFFD97706),
                          ),
                          SizedBox(height: 4),
                          _EscalationStep(
                            label: 'Low Priority (T=8m)',
                            isComplete: true,
                            color: Color(0xFF4F46E5),
                          ),
                          SizedBox(height: 4),
                          _EscalationStep(
                            label: 'Police / 112 (T=12m)',
                            isComplete: false,
                            color: AppColors.error,
                            isCurrent: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Buttons ──────────────────────────────────────────────
                    // [ CALL 112 ] - only called when explicitly tapped
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _launchDialer();
                          onCallPolice();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.button),
                          ),
                        ),
                        icon: const Icon(Icons.call_rounded, size: 22),
                        label: const Text(
                          'CALL 112',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: 0.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // [ I'M SAFE ]
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onSafe();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF16A34A),
                          side: const BorderSide(
                              color: Color(0xFF16A34A), width: 1.5),
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

// ─────────────────────────────────────────────────────────────────────────────
// _EscalationStep
// ─────────────────────────────────────────────────────────────────────────────

class _EscalationStep extends StatelessWidget {
  const _EscalationStep({
    required this.label,
    required this.isComplete,
    required this.color,
    this.isCurrent = false,
  });

  final String label;
  final bool isComplete;
  final Color color;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isComplete
                ? color.withValues(alpha: 0.15)
                : isCurrent
                    ? color.withValues(alpha: 0.10)
                    : Colors.grey.shade200,
            shape: BoxShape.circle,
            border: isCurrent
                ? Border.all(color: color, width: 2)
                : null,
          ),
          child: Icon(
            isComplete ? Icons.check_rounded : Icons.radio_button_unchecked,
            size: 14,
            color: isComplete || isCurrent ? color : Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isComplete || isCurrent ? FontWeight.w700 : FontWeight.w500,
            color: isComplete || isCurrent ? color : Colors.grey,
          ),
        ),
        if (isComplete)
          Text(
            '  ✓ Alerted',
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        if (isCurrent && !isComplete)
          Text(
            '  ← Pending',
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}
