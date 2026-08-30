import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:nari_suraksha/core/routes/app_routes.dart';
import 'package:nari_suraksha/core/services/auth_service.dart';
import 'package:nari_suraksha/core/services/location_service.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/core/widgets/widgets.dart';
import 'package:nari_suraksha/models/user_model.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/profile_provider.dart';
import 'package:nari_suraksha/providers/settings_provider.dart';
import 'package:nari_suraksha/providers/user_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ProfilePage
// ─────────────────────────────────────────────────────────────────────────────

/// Dynamic, fully functional user profile and settings screen.
///
/// Sections:
///  1. Gradient Hero — photo/avatar, name, email, phone, edit profile action
///  2. Dynamic Safety Score — live calculated based on contacts, medical, location
///  3. Medical Information — blood group, allergies, conditions, medications with Firestore sync
///  4. Emergency Contacts summary — real contact list preview + one-tap dialler + manage action
///  5. App Settings — real toggles (notifications, location, language, dark/light theme)
///  6. Privacy & Security — biometrics toggle, password change, permissions viewer, account deletion
///  7. About App — version, feedback rating, share app, licenses & terms
///  8. Sign Out action with clean state teardown
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  // Entry animation
  late final AnimationController _entryCtrl;
  late final Animation<double> _entryFade;
  late final Animation<Offset> _entrySlide;

  // Safety score gauge animation
  late final AnimationController _scoreCtrl;
  late Animation<double> _scoreAnim;

  final LocationService _locationService = LocationService();
  bool _isLocationReady = false;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _entryFade = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entrySlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    _scoreCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _scoreAnim = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOutCubic),
    );

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        _entryCtrl.forward();
      }
    });

    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    try {
      final res = await _locationService.checkPermission();
      if (mounted) {
        setState(() {
          _isLocationReady = res is LocationPermissionGranted;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _scoreCtrl.dispose();
    super.dispose();
  }

  // ── Dynamic Safety Score Calculator ────────────────────────────────────────

  double _calculateSafetyScore({
    required UserModel? user,
    required int contactsCount,
    required bool isLocationReady,
  }) {
    double score = 20.0; // Base registered score

    if (user != null) {
      if (user.name.isNotEmpty && user.name != 'User') score += 10.0;
      if (user.phone != null && user.phone!.isNotEmpty) score += 10.0;

      // Medical info completeness
      if (user.bloodGroup.isNotEmpty) score += 10.0;
      if (user.allergies.isNotEmpty ||
          user.conditions.isNotEmpty ||
          user.medications.isNotEmpty) {
        score += 10.0;
      }
    }

    // Contacts score (up to 30)
    if (contactsCount >= 3) {
      score += 30.0;
    } else if (contactsCount == 2) {
      score += 20.0;
    } else if (contactsCount == 1) {
      score += 10.0;
    }

    // Location readiness (10)
    if (isLocationReady) {
      score += 10.0;
    }

    return score.clamp(0.0, 100.0);
  }

  // ── Logout confirmation ────────────────────────────────────────────────────

  Future<void> _confirmLogout() async {
    final confirmed = await ConfirmationDialog.show(
      context: context,
      title: 'Sign Out?',
      message:
          'You will be signed out of Nari Suraksha. Emergency alerts require you to be signed in.',
      confirmLabel: 'Sign Out',
      cancelLabel: 'Stay',
      isDangerous: true,
      icon: Icons.logout_rounded,
    );
    if (confirmed == true && mounted) {
      context.read<ContactProvider>().unsubscribe();
      context.read<UserProvider>().clearUser();
      await AuthService().signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.login,
        (route) => false,
      );
    }
  }

  // ── Edit Profile sheet ─────────────────────────────────────────────────────

  void _showEditProfileSheet(UserModel user) {
    final nameCtrl = TextEditingController(text: user.name);
    final phoneCtrl = TextEditingController(text: user.phone ?? '');
    final photoCtrl = TextEditingController(text: user.photoUrl ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        bool isSaving = false;
        String? error;

        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SingleChildScrollView(
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
                      'Edit Profile',
                      style: AppTextStyles.titleLarge
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CustomTextField(
                      controller: nameCtrl,
                      label: 'Full Name',
                      hint: 'Priya Sharma',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomTextField(
                      controller: phoneCtrl,
                      label: 'Phone Number',
                      hint: '+91 98765 43210',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomTextField(
                      controller: photoCtrl,
                      label: 'Photo URL (optional)',
                      hint: 'https://example.com/avatar.jpg',
                      prefixIcon: Icons.image_outlined,
                      keyboardType: TextInputType.url,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        error!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: isSaving ? 'Saving…' : 'Save Changes',
                      icon: isSaving ? null : Icons.check_rounded,
                      onPressed: isSaving
                          ? () {}
                          : () async {
                              final name = nameCtrl.text.trim();
                              if (name.isEmpty) {
                                setSheetState(
                                    () => error = 'Name cannot be empty.');
                                return;
                              }

                              setSheetState(() {
                                isSaving = true;
                                error = null;
                              });

                              final err = await context
                                  .read<ProfileProvider>()
                                  .updateBasicInfo(
                                    current: user,
                                    name: name,
                                    phone: phoneCtrl.text.trim(),
                                    photoUrl: photoCtrl.text.trim(),
                                  );

                              if (err != null) {
                                setSheetState(() {
                                  isSaving = false;
                                  error = err;
                                });
                              } else {
                                if (ctx.mounted) {
                                  await ctx.read<UserProvider>().refresh();
                                }
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Profile updated successfully!',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.md),
                                      ),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Edit Medical Info sheet ─────────────────────────────────────────────────

  void _showEditMedicalSheet(UserModel user) {
    final bloodCtrl = TextEditingController(text: user.bloodGroup);
    final allergiesCtrl = TextEditingController(text: user.allergies);
    final conditionsCtrl = TextEditingController(text: user.conditions);
    final medsCtrl = TextEditingController(text: user.medications);

    final bloodOptions = [
      'A+',
      'A-',
      'B+',
      'B-',
      'AB+',
      'AB-',
      'O+',
      'O-',
      'Unknown'
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        bool isSaving = false;
        String? error;

        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SingleChildScrollView(
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
                      'Edit Medical Information',
                      style: AppTextStyles.titleLarge
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This information helps emergency responders assist you quickly.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Blood group selector chips
                    Text(
                      'Blood Group',
                      style: AppTextStyles.labelMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: bloodOptions.map((bg) {
                        final isSelected = bloodCtrl.text == bg;
                        return ChoiceChip(
                          label: Text(bg),
                          selected: isSelected,
                          selectedColor: AppColors.primaryContainer,
                          onSelected: (selected) {
                            setSheetState(() {
                              bloodCtrl.text = selected ? bg : '';
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomTextField(
                      controller: allergiesCtrl,
                      label: 'Allergies',
                      hint: 'e.g. Penicillin, Peanuts, Pollen',
                      prefixIcon: Icons.warning_amber_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomTextField(
                      controller: conditionsCtrl,
                      label: 'Medical Conditions',
                      hint: 'e.g. Asthma, Diabetes, Hypertension',
                      prefixIcon: Icons.medical_information_rounded,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    CustomTextField(
                      controller: medsCtrl,
                      label: 'Medications',
                      hint: 'e.g. Inhaler, Metformin 500mg',
                      prefixIcon: Icons.medication_rounded,
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        error!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    PrimaryButton(
                      label: isSaving ? 'Saving…' : 'Save Medical Info',
                      icon: isSaving ? null : Icons.check_rounded,
                      onPressed: isSaving
                          ? () {}
                          : () async {
                              setSheetState(() {
                                isSaving = true;
                                error = null;
                              });
                              final err = await context
                                  .read<ProfileProvider>()
                                  .updateMedicalInfo(
                                    current: user,
                                    bloodGroup: bloodCtrl.text.trim(),
                                    allergies: allergiesCtrl.text.trim(),
                                    conditions: conditionsCtrl.text.trim(),
                                    medications: medsCtrl.text.trim(),
                                  );
                              if (err != null) {
                                setSheetState(() {
                                  isSaving = false;
                                  error = err;
                                });
                              } else {
                                if (ctx.mounted) {
                                  await ctx.read<UserProvider>().refresh();
                                }
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Medical details saved to your profile!',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.md),
                                      ),
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Language Selection Sheet ───────────────────────────────────────────────

  void _showLanguageSelectionSheet(SettingsProvider settings, String? uid) {
    final languages = [
      'English (India)',
      'Hindi (हिंदी)',
      'Marathi (मराठी)',
      'Bengali (বাংলা)',
      'Tamil (தமிழ்)',
      'Telugu (తెలుగు)',
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
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
              const SizedBox(height: AppSpacing.md),
              Text(
                'Select App Language',
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              ...languages.map((lang) {
                final isSelected = settings.language == lang;
                return ListTile(
                  title: Text(
                    lang,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.normal,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: cs.primary)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  onTap: () {
                    settings.setLanguage(lang, uid: uid);
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Language set to $lang'),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ── Theme Selection Sheet ──────────────────────────────────────────────────

  void _showThemeSelectionSheet(SettingsProvider settings, String? uid) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final options = [
          (mode: ThemeMode.system, label: 'System default', icon: Icons.phone_android_rounded),
          (mode: ThemeMode.light, label: 'Light mode', icon: Icons.light_mode_outlined),
          (mode: ThemeMode.dark, label: 'Dark mode', icon: Icons.dark_mode_outlined),
        ];

        return Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
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
              const SizedBox(height: AppSpacing.md),
              Text(
                'Appearance Theme',
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              ...options.map((opt) {
                final isSelected = settings.themeMode == opt.mode;
                return ListTile(
                  leading: Icon(opt.icon,
                      color: isSelected ? cs.primary : cs.onSurfaceVariant),
                  title: Text(
                    opt.label,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.normal,
                      color: isSelected ? cs.primary : cs.onSurface,
                    ),
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle_rounded, color: cs.primary)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  onTap: () {
                    settings.setThemeMode(opt.mode, uid: uid);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ── Change Password Dialog ─────────────────────────────────────────────────

  void _showChangePasswordDialog(UserModel user) {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        bool isSaving = false;
        String? error;

        return StatefulBuilder(
          builder: (ctx, setSheetState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Container(
              margin: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: SingleChildScrollView(
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
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Change Password',
                      style: AppTextStyles.titleLarge
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PasswordField(
                      controller: currentPwCtrl,
                      label: 'Current Password',
                      hint: 'Enter current password',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PasswordField(
                      controller: newPwCtrl,
                      label: 'New Password',
                      hint: 'At least 6 characters',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PasswordField(
                      controller: confirmPwCtrl,
                      label: 'Confirm New Password',
                      hint: 'Re-enter new password',
                    ),
                    if (error != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        error!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.error),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () async {
                            final err = await context
                                .read<ProfileProvider>()
                                .sendPasswordResetEmail(user.email);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(err ??
                                      'Reset email sent to ${user.email}'),
                                  backgroundColor: err == null
                                      ? AppColors.success
                                      : AppColors.error,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                ),
                              );
                            }
                          },
                          child: const Text('Send Reset Email Instead'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    PrimaryButton(
                      label: isSaving ? 'Updating…' : 'Update Password',
                      onPressed: isSaving
                          ? () {}
                          : () async {
                              final cur = currentPwCtrl.text;
                              final nw = newPwCtrl.text;
                              final conf = confirmPwCtrl.text;

                              if (cur.isEmpty) {
                                setSheetState(() =>
                                    error = 'Please enter your current password.');
                                return;
                              }
                              if (nw.length < 6) {
                                setSheetState(() => error =
                                    'New password must be at least 6 characters.');
                                return;
                              }
                              if (nw != conf) {
                                setSheetState(
                                    () => error = 'New passwords do not match.');
                                return;
                              }

                              setSheetState(() {
                                isSaving = true;
                                error = null;
                              });

                              final err = await context
                                  .read<ProfileProvider>()
                                  .changePassword(
                                    currentPassword: cur,
                                    newPassword: nw,
                                  );

                              if (err != null) {
                                setSheetState(() {
                                  isSaving = false;
                                  error = err;
                                });
                              } else {
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text(
                                        'Password updated successfully!',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      backgroundColor: AppColors.success,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppRadius.md),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Privacy & Permissions Sheet ────────────────────────────────────────────

  void _showPrivacySettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
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
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Icon(Icons.shield_rounded,
                      color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Privacy & Permissions',
                    style: AppTextStyles.titleMedium
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _isLocationReady
                        ? const Color(0xFFDCFCE7)
                        : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.location_on_rounded,
                    color: _isLocationReady
                        ? const Color(0xFF16A34A)
                        : AppColors.error,
                  ),
                ),
                title: const Text('GPS Location Permission'),
                subtitle: Text(_isLocationReady ? 'Granted' : 'Disabled / Required'),
                trailing: TextButton(
                  onPressed: () async {
                    await openAppSettings();
                    _checkLocationStatus();
                  },
                  child: const Text('Settings'),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Nari Suraksha Privacy Pledge:',
                style: AppTextStyles.labelLarge
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '• Your GPS location is transmitted ONLY when an SOS is actively triggered by you.\n'
                '• Your medical data is strictly private and stored in your personal account.\n'
                '• Emergency contacts are notified exclusively upon your command.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Delete Account Dialog ──────────────────────────────────────────────────

  void _showDeleteAccountDialog(UserModel user) {
    final pwCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        bool isDeleting = false;
        String? error;

        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            icon: const Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: 36),
            title: const Text('Delete Account?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action is irreversible. All your profile data, SOS history, and emergency contacts will be permanently removed.',
                  style: TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.md),
                PasswordField(
                  controller: pwCtrl,
                  label: 'Confirm Password',
                  hint: 'Enter your password',
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: isDeleting
                    ? null
                    : () async {
                        if (pwCtrl.text.isEmpty) {
                          setDialogState(() =>
                              error = 'Password is required to confirm.');
                          return;
                        }
                        setDialogState(() {
                          isDeleting = true;
                          error = null;
                        });

                        final err = await context
                            .read<ProfileProvider>()
                            .deleteAccount(password: pwCtrl.text);

                        if (err != null) {
                          setDialogState(() {
                            isDeleting = false;
                            error = err;
                          });
                        } else {
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            context.read<ContactProvider>().unsubscribe();
                            context.read<UserProvider>().clearUser();
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.login,
                              (route) => false,
                            );
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                child: Text(isDeleting ? 'Deleting…' : 'Delete Account'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── About App Dialog ───────────────────────────────────────────────────────

  void _showAboutAppDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: AppColors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.shield_rounded,
              color: AppColors.primaryDark, size: 30),
        ),
        title: const Text('Nari Suraksha',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Version 1.0.0 (Build 1)',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            Text(
              'Nari Suraksha is an advanced AI-driven safety and emergency response mobile application designed to protect women and provide rapid SOS alerting, location tracking, and emergency support.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            SizedBox(height: 12),
            Text('National Emergency Number: 112\nWomen Helpline: 1091',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                    fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Rate App Dialog ────────────────────────────────────────────────────────

  void _showRateAppDialog() {
    int rating = 5;
    final feedbackCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          icon: const Icon(Icons.star_rounded,
              color: Color(0xFFCA8A04), size: 36),
          title: const Text('Rate Nari Suraksha'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('How would you rate your experience with the app?'),
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starNum = index + 1;
                  return IconButton(
                    icon: Icon(
                      starNum <= rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFCA8A04),
                      size: 32,
                    ),
                    onPressed: () => setDialogState(() => rating = starNum),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
              CustomTextField(
                controller: feedbackCtrl,
                label: 'Feedback (optional)',
                hint: 'Tell us how we can improve safety features...',
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Thank you for your rating and feedback! 💖',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                );
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Share App Sheet ────────────────────────────────────────────────────────

  void _showShareAppSheet() {
    const shareText =
        'Stay safe with Nari Suraksha - AI-driven Women Safety App. Download and protect yourself and loved ones: https://narisuraksha.org';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
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
              const SizedBox(height: AppSpacing.md),
              Text(
                'Share Nari Suraksha',
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Share this app with friends, family, and loved ones to spread protection and peace of mind.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        shareText,
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded,
                          color: AppColors.primaryDark),
                      onPressed: () {
                        Clipboard.setData(
                            const ClipboardData(text: shareText));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Share link copied to clipboard!'),
                            backgroundColor: AppColors.success,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  // ── Legal & Licenses Sheet ─────────────────────────────────────────────────

  void _showLegalSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.xxl),
          ),
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
              const SizedBox(height: AppSpacing.md),
              Text(
                'Legal & Open Source',
                style: AppTextStyles.titleMedium
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Open Source Licenses'),
                subtitle: const Text('Third-party software libraries'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  showLicensePage(
                    context: context,
                    applicationName: 'Nari Suraksha',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.shield_rounded,
                          size: 40, color: AppColors.primary),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Privacy Policy'),
                subtitle: const Text('How your data is protected'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPrivacySettingsSheet();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.gavel_outlined),
                title: const Text('Terms of Service'),
                subtitle: const Text('User agreements & safety guidelines'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAboutAppDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Consumer3<UserProvider, ContactProvider, SettingsProvider>(
      builder: (context, userProv, contactProv, settingsProv, _) {
        final user = userProv.user;
        final contacts = contactProv.contacts;
        final uid = user?.uid ?? userProv.currentUid;

        // Initialize settings once user is loaded
        if (user != null && settingsProv.language == 'English (India)') {
          settingsProv.initFromUser(user);
        }

        // Calculate dynamic safety score
        final calculatedScore = _calculateSafetyScore(
          user: user,
          contactsCount: contacts.length,
          isLocationReady: _isLocationReady,
        );

        _scoreAnim = Tween<double>(
          begin: 0,
          end: calculatedScore / 100.0,
        ).animate(
          CurvedAnimation(parent: _scoreCtrl, curve: Curves.easeOutCubic),
        );
        _scoreCtrl.forward(from: 0);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: FadeTransition(
            opacity: _entryFade,
            child: SlideTransition(
              position: _entrySlide,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ── Hero header ───────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _buildHero(cs, user),
                  ),

                  // ── Dynamic Safety Score Card ─────────────────────────────
                  _sectionLabel('Safety Score', cs),
                  _section(
                    child: _SafetyScoreCard(
                      scoreAnim: _scoreAnim,
                      score: calculatedScore,
                      contactsCount: contacts.length,
                      medicalSet: user != null && user.bloodGroup.isNotEmpty,
                      locationReady: _isLocationReady,
                      cs: cs,
                    ),
                  ),

                  // ── Medical Information ───────────────────────────────────
                  _sectionLabel('Medical Information', cs),
                  _section(
                    child: _MedicalInfoCard(
                      cs: cs,
                      user: user,
                      onEdit: user != null
                          ? () => _showEditMedicalSheet(user)
                          : null,
                    ),
                  ),

                  // ── Emergency Contacts Summary ────────────────────────────
                  _sectionLabel('Emergency Contacts', cs),
                  _section(
                    child: _ContactsSummaryCard(
                      cs: cs,
                      contacts: contacts,
                      onManage: () {
                        Navigator.pushNamed(context, AppRoutes.contacts);
                      },
                    ),
                  ),

                  // ── App Settings ──────────────────────────────────────────
                  _sectionLabel('App Settings', cs),
                  _section(
                    child: _SettingsGroup(
                      cs: cs,
                      items: [
                        _SettingsTile(
                          icon: Icons.notifications_outlined,
                          iconColor: AppColors.primary,
                          iconBg: AppColors.primaryContainer,
                          title: 'Notifications',
                          subtitle: settingsProv.notificationsEnabled
                              ? 'Alert and reminder notifications active'
                              : 'Notifications turned off',
                          trailing: Switch(
                            value: settingsProv.notificationsEnabled,
                            onChanged: (v) => settingsProv
                                .setNotificationsEnabled(v, uid: uid),
                            activeThumbColor: cs.onPrimary,
                            activeTrackColor: cs.primary,
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.location_on_outlined,
                          iconColor: const Color(0xFF16A34A),
                          iconBg: const Color(0xFFDCFCE7),
                          title: 'Location Sharing',
                          subtitle: settingsProv.locationSharingEnabled
                              ? (_isLocationReady
                                  ? 'GPS ready for emergency alerts'
                                  : 'Location permission needed')
                              : 'Location sharing disabled',
                          trailing: Switch(
                            value: settingsProv.locationSharingEnabled,
                            onChanged: (v) async {
                              if (v && !_isLocationReady) {
                                final res =
                                    await _locationService.requestPermission();
                                setState(() {
                                  _isLocationReady =
                                      res is LocationPermissionGranted;
                                });
                              }
                              settingsProv.setLocationSharingEnabled(v,
                                  uid: uid);
                            },
                            activeThumbColor: cs.onPrimary,
                            activeTrackColor: cs.primary,
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.language_rounded,
                          iconColor: const Color(0xFF7C3AED),
                          iconBg: const Color(0xFFEDE9FE),
                          title: 'Language',
                          subtitle: settingsProv.language,
                          onTap: () =>
                              _showLanguageSelectionSheet(settingsProv, uid),
                        ),
                        _SettingsTile(
                          icon: Icons.dark_mode_outlined,
                          iconColor: const Color(0xFF0E7490),
                          iconBg: const Color(0xFFCFFAFE),
                          title: 'Appearance',
                          subtitle: settingsProv.themeModeLabel,
                          onTap: () =>
                              _showThemeSelectionSheet(settingsProv, uid),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  // ── Privacy & Security ────────────────────────────────────
                  _sectionLabel('Privacy & Security', cs),
                  _section(
                    child: _SettingsGroup(
                      cs: cs,
                      items: [
                        _SettingsTile(
                          icon: Icons.fingerprint_rounded,
                          iconColor: const Color(0xFF9D174D),
                          iconBg: const Color(0xFFFCE7F3),
                          title: 'Biometric Lock',
                          subtitle: settingsProv.biometricEnabled
                              ? 'Biometric app protection active'
                              : 'Protect app with fingerprint / face',
                          trailing: Switch(
                            value: settingsProv.biometricEnabled,
                            onChanged: (v) {
                              settingsProv.setBiometricEnabled(v, uid: uid);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(v
                                      ? 'Biometric lock enabled'
                                      : 'Biometric lock disabled'),
                                  backgroundColor: AppColors.success,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            activeThumbColor: cs.onPrimary,
                            activeTrackColor: cs.primary,
                          ),
                        ),
                        _SettingsTile(
                          icon: Icons.lock_outline_rounded,
                          iconColor: AppColors.primary,
                          iconBg: AppColors.primaryContainer,
                          title: 'Change Password',
                          subtitle: 'Update your account password',
                          onTap: user != null
                              ? () => _showChangePasswordDialog(user)
                              : null,
                        ),
                        _SettingsTile(
                          icon: Icons.shield_outlined,
                          iconColor: const Color(0xFF16A34A),
                          iconBg: const Color(0xFFDCFCE7),
                          title: 'Privacy Settings',
                          subtitle: 'Manage data & permissions',
                          onTap: _showPrivacySettingsSheet,
                        ),
                        _SettingsTile(
                          icon: Icons.delete_outline_rounded,
                          iconColor: AppColors.error,
                          iconBg: AppColors.errorContainer,
                          title: 'Delete Account',
                          subtitle: 'Permanently remove your account and data',
                          titleColor: AppColors.error,
                          onTap: user != null
                              ? () => _showDeleteAccountDialog(user)
                              : null,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  // ── About App ─────────────────────────────────────────────
                  _sectionLabel('About', cs),
                  _section(
                    child: _SettingsGroup(
                      cs: cs,
                      items: [
                        _SettingsTile(
                          icon: Icons.info_outline_rounded,
                          iconColor: AppColors.primary,
                          iconBg: AppColors.primaryContainer,
                          title: 'App Version',
                          subtitle: 'Nari Suraksha v1.0.0',
                          onTap: _showAboutAppDialog,
                        ),
                        _SettingsTile(
                          icon: Icons.star_outline_rounded,
                          iconColor: const Color(0xFF92400E),
                          iconBg: const Color(0xFFFEF3C7),
                          title: 'Rate the App',
                          subtitle: 'Share your feedback & experience',
                          onTap: _showRateAppDialog,
                        ),
                        _SettingsTile(
                          icon: Icons.share_outlined,
                          iconColor: const Color(0xFF7C3AED),
                          iconBg: const Color(0xFFEDE9FE),
                          title: 'Share App',
                          subtitle: 'Spread safety awareness with loved ones',
                          onTap: _showShareAppSheet,
                        ),
                        _SettingsTile(
                          icon: Icons.description_outlined,
                          iconColor: cs.onSurfaceVariant,
                          iconBg: cs.surfaceContainerHighest,
                          title: 'Licenses & Terms',
                          subtitle: 'Open source licenses & terms of service',
                          onTap: _showLegalSheet,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                  // ── Sign Out button ───────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.lg, AppSpacing.md, 0),
                    sliver: SliverToBoxAdapter(
                      child: DangerButton(
                        label: 'Sign Out',
                        icon: Icons.logout_rounded,
                        onPressed: _confirmLogout,
                      ),
                    ),
                  ),

                  // ── Version footer ────────────────────────────────────────
                  SliverPadding(
                    padding: const EdgeInsets.only(
                        top: AppSpacing.lg, bottom: AppSpacing.xxl),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          'Nari Suraksha · Built with ♥ for women safety',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _section({required Widget child}) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
        sliver: SliverToBoxAdapter(child: child),
      );

  Widget _sectionLabel(String title, ColorScheme cs) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
        sliver: SliverToBoxAdapter(
          child: SectionHeader(title: title, padding: EdgeInsets.zero),
        ),
      );

  // ── Hero section ──────────────────────────────────────────────────────────

  Widget _buildHero(ColorScheme cs, UserModel? user) {
    final name = user?.name ?? 'User';
    final email = user?.email ?? '';
    final phone = user?.phone ?? '';
    final initials = user?.initials ?? 'U';
    final hasPhoto = user?.photoUrl != null && user!.photoUrl!.isNotEmpty;

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
              AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xl),
          child: Column(
            children: [
              // Avatar + edit badge
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.onPrimary.withValues(alpha: 0.30),
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          AppColors.onPrimary.withValues(alpha: 0.18),
                      backgroundImage:
                          hasPhoto ? NetworkImage(user.photoUrl!) : null,
                      child: !hasPhoto
                          ? Text(
                              initials,
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 34,
                              ),
                            )
                          : null,
                    ),
                  ),
                  // Camera / Edit icon
                  GestureDetector(
                    onTap: user != null
                        ? () => _showEditProfileSheet(user)
                        : null,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: cs.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Name
              Text(
                name,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 4),

              // Email
              if (email.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.email_outlined,
                        size: 14,
                        color: AppColors.onPrimary.withValues(alpha: 0.90)),
                    const SizedBox(width: 5),
                    Text(
                      email,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.80),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 4),

              // Phone
              if (phone.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone_outlined,
                        size: 14,
                        color: AppColors.onPrimary.withValues(alpha: 0.90)),
                    const SizedBox(width: 5),
                    Text(
                      phone,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.80),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: AppSpacing.md),

              // Edit profile chip
              GestureDetector(
                onTap: user != null
                    ? () => _showEditProfileSheet(user)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.onPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    border: Border.all(
                      color: AppColors.onPrimary.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded,
                          size: 14, color: AppColors.onPrimary),
                      const SizedBox(width: 6),
                      Text(
                        'Edit Profile',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
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
// _SafetyScoreCard
// ─────────────────────────────────────────────────────────────────────────────

class _SafetyScoreCard extends StatelessWidget {
  const _SafetyScoreCard({
    required this.scoreAnim,
    required this.score,
    required this.contactsCount,
    required this.medicalSet,
    required this.locationReady,
    required this.cs,
  });

  final Animation<double> scoreAnim;
  final double score;
  final int contactsCount;
  final bool medicalSet;
  final bool locationReady;
  final ColorScheme cs;

  static const _green = Color(0xFF16A34A);
  static const _greenBg = Color(0xFFDCFCE7);

  @override
  Widget build(BuildContext context) {
    String description;
    if (score >= 80) {
      description =
          'Your safety profile is well configured. Emergency alerts are primed and ready.';
    } else if (score >= 50) {
      description =
          'Your safety profile is partially ready. Add emergency contacts and medical details for maximum protection.';
    } else {
      description =
          'Please complete your safety setup by adding emergency contacts and medical information.';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _greenBg,
            _greenBg.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: _green.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Circular gauge
          SizedBox(
            width: 90,
            height: 90,
            child: AnimatedBuilder(
              animation: scoreAnim,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: scoreAnim.value,
                    strokeWidth: 8,
                    backgroundColor: _green.withValues(alpha: 0.15),
                    valueColor: const AlwaysStoppedAnimation<Color>(_green),
                    strokeCap: StrokeCap.round,
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${score.round()}',
                        style: AppTextStyles.headlineMedium.copyWith(
                          color: _green,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      Text(
                        '/100',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: _green.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: AppSpacing.md),

          // Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: _green, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Safety Score',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: _green,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: const Color(0xFF166534),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                // Dynamic Stat chips
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _ScoreChip(
                      label: '$contactsCount Contact${contactsCount == 1 ? '' : 's'}',
                      icon: Icons.people_rounded,
                    ),
                    _ScoreChip(
                      label: medicalSet ? 'Medical Set' : 'Medical Pending',
                      icon: Icons.medical_information_rounded,
                    ),
                    _ScoreChip(
                      label: locationReady ? 'GPS Ready' : 'GPS Off',
                      icon: Icons.location_on_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  const _ScoreChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  static const _green = Color(0xFF16A34A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _green),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: _green,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MedicalInfoCard
// ─────────────────────────────────────────────────────────────────────────────

class _MedicalInfoCard extends StatelessWidget {
  const _MedicalInfoCard({
    required this.cs,
    this.user,
    this.onEdit,
  });

  final ColorScheme cs;
  final UserModel? user;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: const Icon(Icons.local_hospital_rounded,
                      color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Medical Information',
                    style: AppTextStyles.titleSmall.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Edit',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: cs.primary),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant),

          // Real Medical Rows
          _MedicalRow(
            icon: Icons.water_drop_rounded,
            iconColor: const Color(0xFFDC2626),
            label: 'Blood Group',
            value: (user?.bloodGroup.isNotEmpty == true)
                ? user!.bloodGroup
                : 'Not set',
            cs: cs,
          ),
          _MedicalRow(
            icon: Icons.warning_amber_rounded,
            iconColor: AppColors.warning,
            label: 'Allergies',
            value: (user?.allergies.isNotEmpty == true)
                ? user!.allergies
                : 'None reported',
            cs: cs,
          ),
          _MedicalRow(
            icon: Icons.medical_information_rounded,
            iconColor: cs.primary,
            label: 'Conditions',
            value: (user?.conditions.isNotEmpty == true)
                ? user!.conditions
                : 'None reported',
            cs: cs,
          ),
          _MedicalRow(
            icon: Icons.medication_rounded,
            iconColor: const Color(0xFF7C3AED),
            label: 'Medications',
            value: (user?.medications.isNotEmpty == true)
                ? user!.medications
                : 'None reported',
            cs: cs,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _MedicalRow extends StatelessWidget {
  const _MedicalRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.cs,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final ColorScheme cs;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(height: 1, color: cs.outlineVariant),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ContactsSummaryCard
// ─────────────────────────────────────────────────────────────────────────────

class _ContactsSummaryCard extends StatelessWidget {
  const _ContactsSummaryCard({
    required this.cs,
    required this.contacts,
    required this.onManage,
  });

  final ColorScheme cs;
  final dynamic contacts;
  final VoidCallback onManage;

  static const _avatarPalettes = [
    (bg: Color(0xFFDBEAFE), fg: Color(0xFF1D4ED8)),
    (bg: Color(0xFFDCFCE7), fg: Color(0xFF16A34A)),
    (bg: Color(0xFFFEF9C3), fg: Color(0xFFCA8A04)),
    (bg: Color(0xFFEDE9FE), fg: Color(0xFF7C3AED)),
    (bg: Color(0xFFFFE4E6), fg: Color(0xFFBE123C)),
  ];

  Future<void> _callPhone(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = contacts as List;
    final preview = list.take(2).toList();
    final remaining = (list.length - 2).clamp(0, 100);

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(Icons.contacts_rounded,
                      color: cs.primary, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emergency Contacts',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        list.isEmpty
                            ? 'No contacts added'
                            : '${list.length} contact${list.length == 1 ? '' : 's'} configured',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onManage,
                  style: TextButton.styleFrom(
                    foregroundColor: cs.primary,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Manage',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: cs.primary),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, color: cs.outlineVariant),

          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  Text(
                    'Add emergency contacts to improve your safety score and enable instant SOS messaging.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: cs.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onManage,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Contact Now'),
                  ),
                ],
              ),
            )
          else ...[
            // Contact previews
            ...preview.asMap().entries.map((entry) {
              final i = entry.key;
              final c = entry.value;
              final palette = _avatarPalettes[i % _avatarPalettes.length];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: 10),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: palette.bg,
                          child: Text(
                            c.initials as String,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: palette.fg,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.name as String,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                (c.relation as String).isNotEmpty
                                    ? '${c.relation} · ${c.phone}'
                                    : (c.phone as String),
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => _callPhone(c.phone as String),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.phone_rounded,
                                color: cs.primary, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < preview.length - 1 || remaining > 0)
                    Divider(height: 1, color: cs.outlineVariant),
                ],
              );
            }),

            // Remaining count footer
            if (remaining > 0) ...[
              InkWell(
                onTap: onManage,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Center(
                    child: Text(
                      '+ $remaining more contact${remaining == 1 ? '' : 's'}',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: cs.primary),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsGroup
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.items, required this.cs});

  final List<_SettingsTile> items;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: items
            .asMap()
            .entries
            .expand((e) => [
                  e.value,
                  if (!e.value.isLast)
                    Divider(height: 1, color: cs.outlineVariant),
                ])
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsTile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(
              bottom: Radius.circular(AppRadius.card))
          : BorderRadius.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: titleColor ?? cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            trailing ??
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}
