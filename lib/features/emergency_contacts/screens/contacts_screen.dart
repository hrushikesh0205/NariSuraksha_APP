import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nari_suraksha/core/services/sms_service.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/core/widgets/widgets.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ContactsScreen
// ─────────────────────────────────────────────────────────────────────────────

/// Emergency contacts manager — real Firestore CRUD via [ContactProvider].
///
/// UI, animations, colors, and spacing are preserved from the approved design.
/// Only the data source has been changed from static dummies to live Firestore.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with TickerProviderStateMixin {
  // Screen-entry animation
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  // Stagger animation for contact cards
  late final AnimationController _staggerCtrl;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    Future.delayed(const Duration(milliseconds: 60), () {
      if (mounted) {
        _entryCtrl.forward();
        _staggerCtrl.forward();
      }
    });

    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim());
    });

    // Ensure ContactProvider is subscribed to the current user
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final uid = context.read<UserProvider>().currentUid;
      if (uid != null) {
        context.read<ContactProvider>().subscribe(uid);
      }
    });
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _staggerCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<EmergencyContact> _filtered(List<EmergencyContact> all) {
    if (_query.isEmpty) return all;
    final q = _query.toLowerCase();
    return all.where((c) {
      return c.name.toLowerCase().contains(q) ||
          c.phone.contains(q) ||
          c.relation.toLowerCase().contains(q);
    }).toList();
  }

  // ── Avatar palette ────────────────────────────────────────────────────────

  static const _avatarPalettes = [
    (bg: AppColors.pastBlue, fg: AppColors.pastBlueIcon),
    (bg: AppColors.pastGreen, fg: AppColors.pastGreenIcon),
    (bg: AppColors.pastYellow, fg: AppColors.pastYellowIcon),
    (bg: AppColors.pastPurple, fg: AppColors.pastPurpleIcon),
    (bg: AppColors.pastPeach, fg: AppColors.pastPeachIcon),
  ];

  ({Color bg, Color fg}) _palette(int index) =>
      _avatarPalettes[index % _avatarPalettes.length];

  // ── Add contact ───────────────────────────────────────────────────────────

  void _showAddContactSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relationCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactFormSheet(
        title: 'Add Emergency Contact',
        nameCtrl: nameCtrl,
        phoneCtrl: phoneCtrl,
        relationCtrl: relationCtrl,
        initialPriority: ContactPriority.high,
        onSave: (name, phone, relation, priority) async {
          final uid = context.read<UserProvider>().currentUid;
          if (uid == null) return 'Not signed in.';
          return context.read<ContactProvider>().addContact(
                uid: uid,
                name: name,
                phone: phone,
                relation: relation,
                priority: priority,
              );
        },
      ),
    );
  }

  // ── Edit contact ──────────────────────────────────────────────────────────

  void _showEditContactSheet(EmergencyContact contact) {
    final nameCtrl = TextEditingController(text: contact.name);
    final phoneCtrl = TextEditingController(text: contact.phone);
    final relationCtrl = TextEditingController(text: contact.relation);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactFormSheet(
        title: 'Edit Contact',
        nameCtrl: nameCtrl,
        phoneCtrl: phoneCtrl,
        relationCtrl: relationCtrl,
        initialPriority: contact.priority,
        onSave: (name, phone, relation, priority) async {
          final uid = context.read<UserProvider>().currentUid;
          if (uid == null) return 'Not signed in.';
          return context.read<ContactProvider>().editContact(
                uid: uid,
                contact: contact.copyWith(
                  name: name,
                  phone: phone,
                  relation: relation,
                  priority: priority,
                ),
              );
        },
      ),
    );
  }

  static const _smsService = SmsService();

  // ── Call Contact Action ───────────────────────────────────────────────────

  Future<void> _handleCallContact(EmergencyContact contact) async {
    final rawPhone = contact.phone.trim();
    if (rawPhone.isEmpty || !_smsService.isValidPhone(rawPhone)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid phone number for ${contact.name}.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final normalized = _smsService.normalizePhone(rawPhone);
    final uri = Uri(scheme: 'tel', path: normalized);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cannot open phone dialer on this device.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ContactsScreen] Error launching call to $normalized: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot open phone dialer on this device.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Message Contact Action ────────────────────────────────────────────────

  Future<void> _handleMessageContact(EmergencyContact contact) async {
    final rawPhone = contact.phone.trim();
    if (rawPhone.isEmpty || !_smsService.isValidPhone(rawPhone)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invalid phone number for ${contact.name}.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final message = _smsService.buildQuickAlertMessage();

    // 1. Attempt direct background SMS via native Android SmsManager
    final result = await _smsService.sendDirectSms(
      phone: rawPhone,
      message: message,
      contactName: contact.name,
    );

    if (!mounted) return;

    if (result.result == SmsResult.sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Emergency message sent to ${contact.name}.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // 2. Fallback: If permission was denied or direct send failed, open SMS composer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Opening Messages to send the emergency message.'),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        duration: const Duration(seconds: 3),
      ),
    );

    final launched = await _smsService.openSmsComposer(
      phone: rawPhone,
      message: message,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to send message. Please try again.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ── Contact options sheet ─────────────────────────────────────────────────

  void _showContactOptions(BuildContext sheetContext, EmergencyContact contact) {
    BottomActionSheet.show(
      context: context,
      title: contact.name,
      subtitle: contact.relation,
      actions: [
        SheetAction(
          icon: Icons.phone_rounded,
          label: 'Call',
          subtitle: contact.phone,
          onTap: () => _handleCallContact(contact),
        ),
        SheetAction(
          icon: Icons.message_rounded,
          label: 'Send Message',
          onTap: () => _handleMessageContact(contact),
        ),
        SheetAction(
          icon: Icons.edit_rounded,
          label: 'Edit Contact',
          onTap: () {
            _showEditContactSheet(contact);
          },
        ),
        SheetAction(
          icon: Icons.delete_outline_rounded,
          label: 'Remove Contact',
          isDangerous: true,
          onTap: () async {
            debugPrint('══════════════════════════════════════════════════════════');
            debugPrint('👉 [UI: CONTACT OPTIONS] "Remove Contact" tapped');
            debugPrint('   - contact.id: "${contact.id}"');
            debugPrint('   - contact.name: "${contact.name}"');
            debugPrint('   - contact.phone: "${contact.phone}"');
            debugPrint('   - contact.userId: "${contact.userId}"');
            debugPrint('   - contact.priority: ${contact.priority.name}');

            final messenger = ScaffoldMessenger.of(context);
            final contactProv = context.read<ContactProvider>();
            final userProv = context.read<UserProvider>();

            debugPrint('👉 [UI: CONFIRMATION DIALOG] Displaying ConfirmationDialog.show...');
            final confirmed = await ConfirmationDialog.show(
              context: context,
              title: 'Remove Contact?',
              message:
                  '${contact.name} will no longer be alerted during emergencies.',
              confirmLabel: 'Remove',
              isDangerous: true,
              icon: Icons.delete_outline_rounded,
            );
            debugPrint('👉 [UI: CONFIRMATION DIALOG] Dialog result: confirmed = $confirmed, mounted = $mounted');
            if (confirmed != true || !mounted) {
              debugPrint('⚠️ [UI: CANCELLED] Deletion was not confirmed or screen unmounted.');
              return;
            }

            final authUser = FirebaseAuth.instance.currentUser;
            final uid = authUser?.uid ?? userProv.currentUid;
            debugPrint('👉 [UI: AUTH STATUS] FirebaseAuth uid: ${authUser?.uid}, userProvider uid: ${userProv.currentUid}');
            if (uid == null || uid.isEmpty) {
              debugPrint('🔥 [UI: AUTH ERROR] Cannot delete: User is not authenticated.');
              messenger.showSnackBar(
                SnackBar(
                  content: const Text('Cannot delete: You are not signed in.'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              );
              return;
            }

            debugPrint('👉 [UI: CALLING PROVIDER] Calling contactProv.deleteContact(uid: $uid, contact: ${contact.name})...');
            final err = await contactProv.deleteContact(
              uid: uid,
              contact: contact,
            );

            if (!mounted) {
              debugPrint('⚠️ [UI: UNMOUNTED] Screen unmounted after deleteContact.');
              return;
            }

            if (err != null) {
              debugPrint('🔥 [UI: DELETE FAILED] Provider returned error: $err');
              messenger.showSnackBar(
                SnackBar(
                  content: Text(err),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              );
            } else {
              debugPrint('✅ [UI: DELETE SUCCESS] Successfully deleted ${contact.name}. Showing SnackBar.');
              messenger.showSnackBar(
                SnackBar(
                  content: Text('${contact.name} removed from emergency contacts.'),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
            debugPrint('══════════════════════════════════════════════════════════');
          },
        ),
      ],
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: Consumer<ContactProvider>(
        builder: (_, cp, __) => cp.hasReachedLimit
            ? const SizedBox.shrink()
            : FloatingActionButton.extended(
                onPressed: _showAddContactSheet,
                icon: cp.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.person_add_rounded),
                label: Text(
                  'Add Contact',
                  style:
                      AppTextStyles.labelLarge.copyWith(color: cs.onPrimary),
                ),
                backgroundColor: cs.primary,
                foregroundColor: cs.onPrimary,
                elevation: 3,
              ),
      ),
      body: FadeTransition(
        opacity: _entryFade,
        child: SlideTransition(
          position: _entrySlide,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Gradient header ────────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader(cs)),

              // ── Search bar ─────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                sliver: SliverToBoxAdapter(
                  child: _SearchBar(controller: _searchCtrl),
                ),
              ),

              // ── Contact list ───────────────────────────────────────────────
              Consumer<ContactProvider>(
                builder: (ctx, cp, __) {
                  if (cp.isLoading) {
                    return const SliverPadding(
                      padding: EdgeInsets.all(AppSpacing.xl),
                      sliver: SliverToBoxAdapter(
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }

                  if (cp.errorMessage != null) {
                    return SliverPadding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      sliver: SliverToBoxAdapter(
                        child: EmptyStateWidget(
                          icon: Icons.wifi_off_rounded,
                          title: 'Could not load contacts',
                          message: cp.errorMessage!,
                        ),
                      ),
                    );
                  }

                  final allContacts = cp.contacts;
                  final contacts = _filtered(allContacts);

                  return SliverMainAxisGroup(
                    slivers: [
                      // Section label + count badge
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
                        sliver: SliverToBoxAdapter(
                          child: Row(
                            children: [
                              Text(
                                'My Contacts',
                                style: AppTextStyles.sectionHeading.copyWith(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                ),
                                child: Text(
                                  '${allContacts.length} / 5',
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Empty state
                      if (contacts.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          sliver: SliverToBoxAdapter(
                            child: EmptyStateWidget(
                              icon: Icons.contacts_outlined,
                              title: allContacts.isEmpty
                                  ? 'No contacts yet'
                                  : 'No contacts found',
                              message: allContacts.isEmpty
                                  ? 'Tap "Add Contact" to add your first emergency contact.'
                                  : 'Try a different search term.',
                            ),
                          ),
                        )
                      else
                        // Contact cards with stagger
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(
                              AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                          sliver: SliverList.separated(
                            itemCount: contacts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, i) {
                              final contact = contacts[i];
                              final palette = _palette(i);
                              final start = (i * 0.12).clamp(0.0, 0.7);
                              final end = (start + 0.40).clamp(0.0, 1.0);
                              final fade =
                                  Tween<double>(begin: 0, end: 1).animate(
                                CurvedAnimation(
                                  parent: _staggerCtrl,
                                  curve: Interval(start, end,
                                      curve: Curves.easeOut),
                                ),
                              );
                              final slide = Tween<Offset>(
                                begin: const Offset(0, 0.12),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: _staggerCtrl,
                                  curve: Interval(start, end,
                                      curve: Curves.easeOut),
                                ),
                              );
                              return FadeTransition(
                                opacity: fade,
                                child: SlideTransition(
                                  position: slide,
                                  child: _ContactCard(
                                    contact: contact,
                                    cs: cs,
                                    avatarBg: palette.bg,
                                    avatarFg: palette.fg,
                                    onLongPress: () =>
                                        _showContactOptions(context, contact),
                                    onCall: () => _handleCallContact(contact),
                                    onMessage: () => _handleMessageContact(contact),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),

              // ── How-it-works card ──────────────────────────────────────────
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
                sliver: SliverToBoxAdapter(
                  child: SectionHeader(
                    title: 'How It Works',
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.xxl + AppSpacing.xl),
                sliver: SliverToBoxAdapter(
                  child: _HowItWorksCard(cs: cs),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _buildHeader(ColorScheme cs) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
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
          child: Row(
            children: [
              // Text block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency Contacts',
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'These contacts will be notified during an emergency.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.80),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Shield icon badge
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: AppColors.onPrimary,
                  size: 28,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchBar
// ─────────────────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
      decoration: InputDecoration(
        hintText: 'Search contacts…',
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: cs.onSurfaceVariant,
        ),
        prefixIcon: Icon(Icons.search_rounded,
            color: cs.onSurfaceVariant, size: 22),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (_, val, __) => val.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: cs.onSurfaceVariant, size: 20),
                  onPressed: controller.clear,
                )
              : const SizedBox.shrink(),
        ),
        filled: true,
        fillColor: cs.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ContactCard  — backed by real EmergencyContact
// ─────────────────────────────────────────────────────────────────────────────

class _ContactCard extends StatefulWidget {
  const _ContactCard({
    required this.contact,
    required this.cs,
    required this.avatarBg,
    required this.avatarFg,
    required this.onLongPress,
    required this.onCall,
    required this.onMessage,
  });

  final EmergencyContact contact;
  final ColorScheme cs;
  final Color avatarBg;
  final Color avatarFg;
  final VoidCallback onLongPress;
  final VoidCallback onCall;
  final VoidCallback onMessage;

  @override
  State<_ContactCard> createState() => _ContactCardState();
}

class _ContactCardState extends State<_ContactCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.97).animate(
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
    final c = widget.contact;
    final cs = widget.cs;

    return AnimatedBuilder(
      animation: _pressScale,
      builder: (_, child) =>
          Transform.scale(scale: _pressScale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _pressCtrl.forward(),
        onTapUp: (_) => _pressCtrl.reverse(),
        onTapCancel: () => _pressCtrl.reverse(),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onLongPress();
        },
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                // ── Top row: avatar + info + options ────────────────────────
                Row(
                  children: [
                    // Avatar
                    Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.avatarFg.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: widget.avatarBg,
                        child: Text(
                          c.initials,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: widget.avatarFg,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: AppSpacing.md),

                    // Name + relation + phone
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (c.relation.isNotEmpty)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.family_restroom_rounded,
                                      size: 13,
                                      color: Color(0xFF16A34A),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      c.relation,
                                      style: AppTextStyles.labelMedium.copyWith(
                                        color: const Color(0xFF16A34A),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              _buildCardPriorityBadge(c.priority),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            c.phone,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // More options
                    IconButton(
                      onPressed: widget.onLongPress,
                      icon: Icon(Icons.more_vert_rounded,
                          color: cs.onSurfaceVariant, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                          minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.sm),
                Divider(height: 1, color: cs.outlineVariant),
                const SizedBox(height: AppSpacing.sm),

                // ── Action buttons ───────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.phone_rounded,
                        label: 'Call',
                        color: AppColors.secondary,
                        bgColor: AppColors.secondaryContainer,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onCall();
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.message_rounded,
                        label: 'Message',
                        color: cs.primary,
                        bgColor: cs.primaryContainer,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onMessage();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildCardPriorityBadge(ContactPriority priority) {
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ActionButton
// ─────────────────────────────────────────────────────────────────────────────

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 110));
    _scale = Tween<double>(begin: 1.0, end: 0.93).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: widget.bgColor,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 16, color: widget.color),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: widget.color,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ContactFormSheet  — used for both Add and Edit
// ─────────────────────────────────────────────────────────────────────────────

class _ContactFormSheet extends StatefulWidget {
  const _ContactFormSheet({
    required this.title,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.relationCtrl,
    this.initialPriority = ContactPriority.high,
    required this.onSave,
  });

  final String title;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController relationCtrl;
  final ContactPriority initialPriority;

  /// Called on save. Returns null on success or an error string.
  final Future<String?> Function(
    String name,
    String phone,
    String relation,
    ContactPriority priority,
  ) onSave;

  @override
  State<_ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<_ContactFormSheet> {
  bool _isSaving = false;
  String? _error;
  late ContactPriority _selectedPriority;

  @override
  void initState() {
    super.initState();
    _selectedPriority = widget.initialPriority;
  }

  Future<void> _handleSave() async {
    final name = widget.nameCtrl.text.trim();
    final phone = widget.phoneCtrl.text.trim();
    final relation = widget.relationCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter a name.');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter a phone number.');
      return;
    }
    if (!EmergencyContact.isValidPhone(phone)) {
      setState(() => _error = 'Please enter a valid phone number.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final err = await widget.onSave(name, phone, relation, _selectedPriority);

    if (!mounted) return;

    if (err != null) {
      setState(() {
        _isSaving = false;
        _error = err;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Widget _buildPrioritySelector(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alert Priority (Escalation Tier)',
          style: AppTextStyles.labelLarge.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        _buildPriorityOption(
          priority: ContactPriority.high,
          title: 'High Priority',
          subtitle: 'Immediate Alert (T = 0 min)',
          color: const Color(0xFFDC2626),
          bgColor: const Color(0xFFFEE2E2),
        ),
        const SizedBox(height: 6),
        _buildPriorityOption(
          priority: ContactPriority.medium,
          title: 'Medium Priority',
          subtitle: 'Alerted after 2 minutes if unresolved',
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFEF3C7),
        ),
        const SizedBox(height: 6),
        _buildPriorityOption(
          priority: ContactPriority.low,
          title: 'Low Priority',
          subtitle: 'Alerted after 5 minutes if unresolved',
          color: const Color(0xFF4F46E5),
          bgColor: const Color(0xFFE0E7FF),
        ),
      ],
    );
  }

  Widget _buildPriorityOption({
    required ContactPriority priority,
    required String title,
    required String subtitle,
    required Color color,
    required Color bgColor,
  }) {
    final isSelected = _selectedPriority == priority;
    return InkWell(
      onTap: () => setState(() => _selectedPriority = priority),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? bgColor.withValues(alpha: 0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.25),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? color : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? color : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.xxl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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
                  widget.title,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This person will be alerted based on their priority level.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Name field
                CustomTextField(
                  controller: widget.nameCtrl,
                  label: 'Full Name',
                  hint: 'e.g. Ananya Sharma',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: AppSpacing.md),

                // Relation field
                CustomTextField(
                  controller: widget.relationCtrl,
                  label: 'Relationship',
                  hint: 'e.g. Mother, Friend, Sister',
                  prefixIcon: Icons.family_restroom_rounded,
                ),
                const SizedBox(height: AppSpacing.md),

                // Phone field
                CustomTextField(
                  controller: widget.phoneCtrl,
                  label: 'Phone Number',
                  hint: '+91 98765 43210',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: AppSpacing.md),

                // Priority selector
                _buildPrioritySelector(cs),

                // Error message
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 16, color: AppColors.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _error!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.lg),

                PrimaryButton(
                  label: _isSaving ? 'Saving…' : 'Save Contact',
                  onPressed: _isSaving ? () {} : _handleSave,
                  icon: _isSaving ? null : Icons.check_rounded,
                ),

                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HowItWorksCard  — unchanged from original
// ─────────────────────────────────────────────────────────────────────────────

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard({required this.cs});

  final ColorScheme cs;

  static const _steps = <_HowStep>[
    _HowStep(
      icon: Icons.sos_rounded,
      title: 'SOS Triggered',
      description: 'You hold the SOS button for 3 seconds.',
    ),
    _HowStep(
      icon: Icons.location_on_rounded,
      title: 'Location Captured',
      description:
          'Your real-time GPS location is captured immediately.',
    ),
    _HowStep(
      icon: Icons.sms_rounded,
      title: 'Contacts Notified',
      description:
          'All contacts here receive an SMS and app alert with your location.',
    ),
    _HowStep(
      icon: Icons.phone_in_talk_rounded,
      title: 'Help Dispatched',
      description:
          'Your contacts can see your live location and call for help.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.primary.withValues(alpha: 0.18)),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(Icons.info_outline_rounded,
                    color: cs.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'How Emergency Contacts Work',
                style: AppTextStyles.titleSmall.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: cs.primary.withValues(alpha: 0.15)),
          const SizedBox(height: AppSpacing.md),
          ...List.generate(_steps.length, (i) {
            final step = _steps[i];
            final isLast = i == _steps.length - 1;
            return _StepRow(step: step, index: i, isLast: isLast, cs: cs);
          }),
        ],
      ),
    );
  }
}

class _HowStep {
  const _HowStep({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.index,
    required this.isLast,
    required this.cs,
  });

  final _HowStep step;
  final int index;
  final bool isLast;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(step.icon, color: cs.onPrimary, size: 14),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 36,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
