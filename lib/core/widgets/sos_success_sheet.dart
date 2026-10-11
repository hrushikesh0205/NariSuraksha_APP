import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nari_suraksha/core/services/sms_service.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/core/widgets/safety_check_sheet.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/sos_escalation_provider.dart';
import 'package:nari_suraksha/providers/sos_provider.dart';
import 'package:nari_suraksha/providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SmsContactsSheet  — public, shared widget
// ─────────────────────────────────────────────────────────────────────────────

/// Bottom sheet that shows emergency contacts grouped/filtered by priority with "Send SMS" actions.
///
/// Uses [SmsService] to build the emergency message and open the native SMS
/// composer.
class SmsContactsSheet extends StatefulWidget {
  const SmsContactsSheet({
    super.key,
    required this.contacts,
    required this.userName,
    required this.mapsUrl,
    required this.sosTime,
    this.initialPriorityFilter,
  });

  final List<EmergencyContact> contacts;
  final String userName;
  final String mapsUrl;
  final DateTime sosTime;
  final ContactPriority? initialPriorityFilter;

  /// Convenience factory — shows the sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required List<EmergencyContact> contacts,
    required String userName,
    required String mapsUrl,
    required DateTime sosTime,
    ContactPriority? initialPriorityFilter,
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
        initialPriorityFilter: initialPriorityFilter,
      ),
    );
  }

  @override
  State<SmsContactsSheet> createState() => _SmsContactsSheetState();
}

class _SmsContactsSheetState extends State<SmsContactsSheet> {
  static const _smsService = SmsService();

  /// Tracks which contacts have already had the SMS composer opened in this sheet session.
  final Set<int> _sent = {};
  ContactPriority? _selectedPriority;

  @override
  void initState() {
    super.initState();
    _selectedPriority = widget.initialPriorityFilter;
  }

  String get _message => _smsService.buildEmergencyMessage(
        userName: widget.userName,
        mapsUrl: widget.mapsUrl,
        timestamp: widget.sosTime,
      );

  List<EmergencyContact> get _displayedContacts {
    if (_selectedPriority == null) {
      // Sort: High -> Medium -> Low
      final sorted = List<EmergencyContact>.from(widget.contacts);
      sorted.sort((a, b) => a.priority.index.compareTo(b.priority.index));
      return sorted;
    }
    return widget.contacts
        .where((c) => c.priority == _selectedPriority)
        .toList();
  }

  Future<void> _sendSms(EmergencyContact contact, int index) async {
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
      if (mounted) {
        context.read<SosEscalationProvider>().recordContactAlerted(contact.phone);
      }
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

  Widget _buildPriorityBadge(ContactPriority priority) {
    Color bg;
    Color fg;
    String label;

    switch (priority) {
      case ContactPriority.high:
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'High · T=0';
        break;
      case ContactPriority.medium:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'Medium · +2m';
        break;
      case ContactPriority.low:
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF4F46E5);
        label = 'Low · +5m';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final displayed = _displayedContacts;
    final escalationProv = context.watch<SosEscalationProvider>();

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
                            '${widget.contacts.length} registered contact${widget.contacts.length == 1 ? '' : 's'}',
                            style: AppTextStyles.bodySmall
                                .copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Priority Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('All Contacts'),
                        selected: _selectedPriority == null,
                        onSelected: (_) =>
                            setState(() => _selectedPriority = null),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('High (T=0)'),
                        selected: _selectedPriority == ContactPriority.high,
                        onSelected: (_) => setState(
                            () => _selectedPriority = ContactPriority.high),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Medium (+2m)'),
                        selected: _selectedPriority == ContactPriority.medium,
                        onSelected: (_) => setState(
                            () => _selectedPriority = ContactPriority.medium),
                      ),
                      const SizedBox(width: 8),
                      FilterChip(
                        label: const Text('Low (+5m)'),
                        selected: _selectedPriority == ContactPriority.low,
                        onSelected: (_) => setState(
                            () => _selectedPriority = ContactPriority.low),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Contact list ───────────────────────────────────────────────────────
          if (displayed.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Text(
                  'No contacts found in this priority tier.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: displayed.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (_, i) {
                  final contact = displayed[i];
                  final isSentLocally = _sent.contains(i);
                  final isAlreadyAlerted =
                      escalationProv.isContactAlerted(contact.phone);
                  final isOpened = isSentLocally || isAlreadyAlerted;
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
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            contact.name,
                            style: AppTextStyles.titleSmall.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildPriorityBadge(contact.priority),
                      ],
                    ),
                    subtitle: Text(
                      contact.relation.isNotEmpty
                          ? '${contact.relation} · ${contact.phone}'
                          : contact.phone,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                    trailing: isOpened
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.success.withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded,
                                    color: AppColors.success, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Opened',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
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
                                  color: AppColors.error
                                      .withValues(alpha: 0.10),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                ),
                                child: const Text(
                                  'Invalid #',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              )
                            : TextButton(
                                onPressed: () => _sendSms(contact, i),
                                style: TextButton.styleFrom(
                                  backgroundColor: const Color(0xFFEDE9FE),
                                  foregroundColor: const Color(0xFF7C3AED),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppRadius.button),
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
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12),
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

/// Enhanced bottom sheet shown after SOS is triggered.
///
/// Displays:
/// - Real-time GPS location tile.
/// - Priority-based Escalation Status Timeline (T=0 High, T=2m Medium, T=5m Low).
/// - "Alert Emergency Contacts" (opens [SmsContactsSheet]).
/// - "Resolve Emergency / I'm Safe" (resolves active SOS session).
class SosSuccessSheet extends StatefulWidget {
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
    // Start or join escalation session
    if (sosDocId != null) {
      final uid = context.read<UserProvider>().currentUid ?? '';
      final userName = context.read<UserProvider>().user?.name ?? 'A Nari Suraksha user';
      final contacts = context.read<ContactProvider>().contacts;
      final escalation = context.read<SosEscalationProvider>();

      escalation.updateContacts(contacts);
      escalation.updateUserName(userName);

      double lat = 0;
      double lng = 0;
      if (mapsUrl != null) {
        final match = RegExp(r'q=([\d.-]+),([\d.-]+)').firstMatch(mapsUrl);
        if (match != null) {
          lat = double.tryParse(match.group(1) ?? '') ?? 0;
          lng = double.tryParse(match.group(2) ?? '') ?? 0;
        }
      }

      escalation.startSession(
            sosDocId: sosDocId,
            userId: uid,
            latitude: lat,
            longitude: lng,
            mapsUrl: mapsUrl ?? '',
            startedAt: sosTime,
            triggerSource: 'dashboard',
          );
    }

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

  @override
  State<SosSuccessSheet> createState() => _SosSuccessSheetState();
}

class _SosSuccessSheetState extends State<SosSuccessSheet> {
  bool _safetySheetShown = false;

  Future<void> _openMaps() async {
    if (widget.mapsUrl == null) return;
    final uri = Uri.parse(widget.mapsUrl!);
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

  String _formatCountdown(int remainingSeconds) {
    if (remainingSeconds <= 0) return 'Alerting now';
    final m = remainingSeconds ~/ 60;
    final s = remainingSeconds % 60;
    return 'in $m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final escalationProv = context.watch<SosEscalationProvider>();
    final elapsed = escalationProv.elapsed;
    final session = escalationProv.activeSession;

    // Check if a safety check is pending and pop up the SafetyCheckSheet
    if (escalationProv.isSafetyCheckPending &&
        !_safetySheetShown &&
        escalationProv.pendingEscalationPriority != null) {
      _safetySheetShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final priority = escalationProv.pendingEscalationPriority!;
        final sosProv = context.read<SosProvider>();
        final nav = Navigator.of(context);

        SafetyCheckSheet.show(
          context,
          escalationPriority: priority,
          onSafe: () async {
            _safetySheetShown = false;
            await escalationProv.resolveEmergency();
            if (widget.sosDocId != null) {
              await sosProv.resolveLatest(widget.sosDocId!);
            }
            if (!mounted) return;
            nav.pop();
          },
          onStillInDanger: () async {
            _safetySheetShown = false;
            await escalationProv.confirmStillInDanger();
            // Automatically dispatches SMS in background — NO manual contact selection UI
          },
        );
      });
    }

    final isMediumAlerted = session?.isMediumAlerted ?? false;
    final isLowAlerted = session?.isLowAlerted ?? false;
    final mediumCountdown = 240 - elapsed.inSeconds;
    final lowCountdown = 480 - elapsed.inSeconds;
    final policeCountdown = 720 - elapsed.inSeconds;

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

          // ── Success icon + Title ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: SosSuccessSheet._sosRed.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      color: SosSuccessSheet._sosRed, size: 36),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'SOS Alert Active',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Emergency recorded with live GPS. Priority escalation active.',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),

                // Location tile
                if (widget.mapsUrl != null)
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

                const SizedBox(height: AppSpacing.md),

                // ── Priority Escalation Timeline Card ────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Escalation Schedule',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(
                              'Active: ${elapsed.inMinutes}m ${(elapsed.inSeconds % 60).toString().padLeft(2, '0')}s',
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // T=0 High
                      _buildTimelineRow(
                        title: 'High Priority (T=0)',
                        status: 'Alerted',
                        isDone: true,
                        color: const Color(0xFFDC2626),
                      ),
                      const SizedBox(height: 6),

                      // T=4m Medium
                      _buildTimelineRow(
                        title: 'Medium Priority (T=4m)',
                        status: isMediumAlerted
                            ? 'Alerted'
                            : _formatCountdown(mediumCountdown),
                        isDone: isMediumAlerted,
                        color: const Color(0xFFD97706),
                      ),
                      const SizedBox(height: 6),

                      // T=8m Low
                      _buildTimelineRow(
                        title: 'Low Priority (T=8m)',
                        status: isLowAlerted
                            ? 'Alerted'
                            : _formatCountdown(lowCountdown),
                        isDone: isLowAlerted,
                        color: const Color(0xFF4F46E5),
                      ),
                      const SizedBox(height: 6),

                      // T=12m Police
                      _buildTimelineRow(
                        title: 'Police 100 (T=12m)',
                        status: session?.policeCallAuthorized == true
                            ? 'Authorized'
                            : (policeCountdown <= 0 ? 'Pending Choice' : _formatCountdown(policeCountdown)),
                        isDone: session?.policeCallAuthorized == true,
                        color: const Color(0xFFDC2626),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Triggered at ${_formatTime(widget.sosTime)}',
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
                // Live Automatic SMS Dispatch Status
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: escalationProv.isSendingSms
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: escalationProv.isSendingSms
                          ? const Color(0xFFF59E0B)
                          : const Color(0xFF86EFAC),
                    ),
                  ),
                  child: Row(
                    children: [
                      if (escalationProv.isSendingSms)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFD97706),
                          ),
                        )
                      else
                        const Icon(Icons.check_circle_rounded,
                            size: 18, color: Color(0xFF16A34A)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          escalationProv.isSendingSms
                              ? 'Sending automatic background SMS...'
                              : 'Automatic SMS dispatched to contacts.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: escalationProv.isSendingSms
                                ? const Color(0xFFB45309)
                                : const Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Resolve emergency / I'm Safe
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await escalationProv.resolveEmergency();
                      if (widget.sosDocId != null && context.mounted) {
                        await context
                            .read<SosProvider>()
                            .resolveLatest(widget.sosDocId!);
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              "Emergency resolved. You're safe!",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 18),
                        SizedBox(width: 8),
                        Text("I'm Safe (Resolve Emergency)",
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.sm),

                // Done / go to dashboard
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDone();
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Back to Dashboard',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow({
    required String title,
    required String status,
    required bool isDone,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(
          isDone ? Icons.check_circle_rounded : Icons.schedule_rounded,
          size: 16,
          color: isDone ? const Color(0xFF16A34A) : color,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isDone ? const Color(0xFF16A34A) : color,
          ),
        ),
      ],
    );
  }
}

