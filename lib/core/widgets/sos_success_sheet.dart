import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nari_suraksha/core/services/sms_service.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/sos_provider.dart';
import 'package:nari_suraksha/providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmsContactsSheet  — public, shared widget
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom sheet that shows all emergency contacts with a "Send SMS" button each.
///
/// Uses [SmsService] to build the emergency message and open the native SMS
/// composer. The user taps Send in the SMS app — no SEND_SMS permission needed.
///
/// Used by both the Dashboard and the dedicated SOS screen.
class SmsContactsSheet extends StatefulWidget {
  const SmsContactsSheet({
    super.key,
    required this.contacts,
    required this.userName,
    required this.mapsUrl,
    required this.sosTime,
  });

  final List<EmergencyContact> contacts;
  final String userName;
  final String mapsUrl;
  final DateTime sosTime;

  /// Convenience factory — shows the sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<EmergencyContact> contacts,
    required String userName,
    required String mapsUrl,
    required DateTime sosTime,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SmsContactsSheet(
        contacts: contacts,
        userName: userName,
        mapsUrl: mapsUrl,
        sosTime: sosTime,
      ),
    );
  }

  @override
  State<SmsContactsSheet> createState() => _SmsContactsSheetState();
}

class _SmsContactsSheetState extends State<SmsContactsSheet> {
  static const _smsService = SmsService();

  /// Tracks which contacts have already had the SMS composer opened.
  final Set<int> _sent = {};

  String get _message => _smsService.buildEmergencyMessage(
        userName: widget.userName,
        mapsUrl: widget.mapsUrl,
        timestamp: widget.sosTime,
      );

  Future<void> _sendSms(int index) async {
    final contact = widget.contacts[index];

    if (!_smsService.isValidPhone(contact.phone)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${contact.name} has an invalid phone number.',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          duration: const Duration(seconds: 3),
        ));
      }
      return;
    }

    final launched = await _smsService.openSmsComposer(
      phone: contact.phone,
      message: _message,
    );

    if (launched) {
      setState(() => _sent.add(index));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Could not open SMS app for ${contact.name}.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final contacts = widget.contacts;
    final validCount =
        contacts.where((c) => _smsService.isValidPhone(c.phone)).length;

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.xxl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Drag handle ──────────────────────────────────────────────────────
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
          ),

          // ── Header ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEDE9FE),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.sms_rounded,
                          color: Color(0xFF7C3AED), size: 22),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alert Emergency Contacts',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$validCount contact${validCount == 1 ? '' : 's'} to notify',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE9FE),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: Color(0xFF7C3AED), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tap "Send SMS" for each contact. Your SMS app will open with the message pre-filled.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: const Color(0xFF7C3AED)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Contact list ───────────────────────────────────────────────────────
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: contacts.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) {
                final contact = contacts[i];
                final isSent = _sent.contains(i);
                final hasValidPhone = _smsService.isValidPhone(contact.phone);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      contact.initials,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    contact.name,
                    style: AppTextStyles.titleSmall.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    contact.relation.isNotEmpty
                        ? '${contact.relation} · ${contact.phone}'
                        : contact.phone,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                  trailing: isSent
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded,
                                  color: AppColors.success, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Opened',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : !hasValidPhone
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.10),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                'Invalid #',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : TextButton(
                              onPressed: () => _sendSms(i),
                              style: TextButton.styleFrom(
                                backgroundColor: const Color(0xFFEDE9FE),
                                foregroundColor: const Color(0xFF7C3AED),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.button),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Send SMS',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                );
              },
            ),
          ),

          // ── Footer ────────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.onSurface,
                  foregroundColor: cs.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.button),
                  ),
                ),
                child: const Text('Done',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SosSuccessSheet  — shared bottom-sheet shown after a successful SOS trigger
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom sheet shown after the Dashboard SOS button is successfully triggered.
///
/// Displays the recorded location, timestamp, and offers:
/// - "Alert Emergency Contacts" → opens [SmsContactsSheet]
/// - "Resolve Emergency" (if [sosDocId] is known)
/// - "Go to Dashboard" / "Done"
///
/// Used by the Dashboard. The dedicated SOS screen uses its own AlertDialog
/// (`_SosSuccessDialog`) which is intentionally kept intact.
class SosSuccessSheet extends StatelessWidget {
  const SosSuccessSheet({
    super.key,
    required this.mapsUrl,
    required this.sosTime,
    required this.sosDocId,
    required this.onDone,
  });

  final String? mapsUrl;
  final DateTime sosTime;
  final String? sosDocId;
  final VoidCallback onDone;

  static const _sosRed = Color(0xFFEF4444);

  /// Convenience factory — shows the sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String? mapsUrl,
    required DateTime sosTime,
    required String? sosDocId,
    required VoidCallback onDone,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => SosSuccessSheet(
        mapsUrl: mapsUrl,
        sosTime: sosTime,
        sosDocId: sosDocId,
        onDone: onDone,
      ),
    );
  }

  Future<void> _openMaps() async {
    if (mapsUrl == null) return;
    final uri = Uri.parse(mapsUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '$hour:$minute $period, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),

          // ── Success icon ───────────────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: _sosRed.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: _sosRed, size: 36),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'SOS Alert Sent!',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your emergency has been recorded with your GPS location.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),

                // Location tile
                if (mapsUrl != null)
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
                          const Icon(Icons.location_on_rounded,
                              size: 16, color: AppColors.primaryDark),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Tap to view your location in Maps',
                              style: AppTextStyles.bodySmall
                                  .copyWith(color: AppColors.primaryDark),
                            ),
                          ),
                          const Icon(Icons.open_in_new_rounded,
                              size: 14, color: AppColors.primaryDark),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Recorded at ${_formatTime(sosTime)}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1),

          // ── Action buttons ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
            child: Column(
              children: [
                // Alert Contacts via SMS
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonal(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _openSmsSheet(context);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFEDE9FE),
                      foregroundColor: const Color(0xFF7C3AED),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sms_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('Alert Emergency Contacts',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Resolve emergency (only if we have the doc ID)
                if (sosDocId != null)
                  Consumer<SosProvider>(
                    builder: (ctx, sp, __) => SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: sp.isResolving
                            ? null
                            : () async {
                                final ok =
                                    await sp.resolveLatest(sosDocId!);
                                if (!ctx.mounted) return;
                                Navigator.of(ctx).pop();
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      ok
                                          ? 'Emergency resolved. Stay safe!'
                                          : sp.resolveError ??
                                              'Could not resolve.',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    backgroundColor:
                                        ok ? AppColors.success : AppColors.error,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.md),
                                    ),
                                    duration: const Duration(seconds: 3),
                                  ),
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.button),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: sp.isResolving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Resolve Emergency',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),

                if (sosDocId != null) const SizedBox(height: AppSpacing.sm),

                // Done / go to dashboard
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onDone();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _sosRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Done',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openSmsSheet(BuildContext context) {
    final contacts = context.read<ContactProvider>().contacts;
    final userName =
        context.read<UserProvider>().user?.name ?? 'A Nari Suraksha user';
    final url = mapsUrl ??
        'https://www.google.com/maps/search/?api=1&query=0.0,0.0';

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
          'No emergency contacts saved. Add contacts first.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.warning,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        duration: const Duration(seconds: 3),
      ));
      return;
    }

    SmsContactsSheet.show(
      context,
      contacts: contacts,
      userName: userName,
      mapsUrl: url,
      sosTime: sosTime,
    );
  }
}
