import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
        onSave: (name, phone, relation) async {
          final uid = context.read<UserProvider>().currentUid;
          if (uid == null) return 'Not signed in.';
          return context.read<ContactProvider>().addContact(
                uid: uid,
                name: name,
                phone: phone,
                relation: relation,
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
        onSave: (name, phone, relation) async {
          final uid = context.read<UserProvider>().currentUid;
          if (uid == null) return 'Not signed in.';
          return context.read<ContactProvider>().editContact(
                uid: uid,
                contact: contact.copyWith(
                  name: name,
                  phone: phone,
                  relation: relation,
                ),
              );
        },
      ),
    );
  }

  // ── Contact options sheet ─────────────────────────────────────────────────

  void _showContactOptions(BuildContext ctx, EmergencyContact contact) {
    BottomActionSheet.show(
      context: ctx,
      title: contact.name,
      subtitle: contact.relation,
      actions: [
        SheetAction(
          icon: Icons.phone_rounded,
          label: 'Call',
          subtitle: contact.phone,
          onTap: () {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text('Calling ${contact.name}…'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        SheetAction(
          icon: Icons.message_rounded,
          label: 'Send Message',
          onTap: () {
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text('Messaging ${contact.name}…'),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        SheetAction(
          icon: Icons.edit_rounded,
          label: 'Edit Contact',
          onTap: () {
            Navigator.pop(ctx);
            _showEditContactSheet(contact);
          },
        ),
        SheetAction(
          icon: Icons.delete_outline_rounded,
          label: 'Remove Contact',
          isDangerous: true,
          onTap: () async {
            Navigator.pop(ctx);
            final confirmed = await ConfirmationDialog.show(
              context: ctx,
              title: 'Remove Contact?',
              message:
                  '${contact.name} will no longer be alerted during emergencies.',
              confirmLabel: 'Remove',
              isDangerous: true,
              icon: Icons.delete_outline_rounded,
            );
            if (confirmed != true || !ctx.mounted) return;
            final uid = ctx.read<UserProvider>().currentUid;
            if (uid == null) return;
            final err = await ctx.read<ContactProvider>().deleteContact(
                  uid: uid,
                  contact: contact,
                );
            if (err != null && ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                SnackBar(
                  content: Text(err),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              );
            }
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
  });

  final EmergencyContact contact;
  final ColorScheme cs;
  final Color avatarBg;
  final Color avatarFg;
  final VoidCallback onLongPress;

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
                          const SizedBox(height: 2),
                          if (c.relation.isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.family_restroom_rounded,
                                  size: 13,
                                  color: Color(0xFF16A34A),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  c.relation,
                                  style: AppTextStyles.labelMedium.copyWith(
                                    color: const Color(0xFF16A34A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 2),
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Calling ${c.name}…'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
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
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Messaging ${c.name}…'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
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
    required this.onSave,
  });

  final String title;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController relationCtrl;

  /// Called on save. Returns null on success or an error string.
  final Future<String?> Function(String name, String phone, String relation)
      onSave;

  @override
  State<_ContactFormSheet> createState() => _ContactFormSheetState();
}

class _ContactFormSheetState extends State<_ContactFormSheet> {
  bool _isSaving = false;
  String? _error;

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

    final err = await widget.onSave(name, phone, relation);

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
                'This person will be alerted during emergencies.',
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
