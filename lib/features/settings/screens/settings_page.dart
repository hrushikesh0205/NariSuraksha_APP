import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:nari_suraksha/core/routes/app_routes.dart';
import 'package:nari_suraksha/core/services/location_service.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/core/widgets/widgets.dart';
import 'package:nari_suraksha/providers/profile_provider.dart';
import 'package:nari_suraksha/providers/settings_provider.dart';
import 'package:nari_suraksha/providers/user_provider.dart';

/// Fully functional App Settings screen.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final LocationService _locationService = LocationService();
  bool _isLocationReady = false;

  @override
  void initState() {
    super.initState();
    _checkLocation();
  }

  Future<void> _checkLocation() async {
    try {
      final res = await _locationService.checkPermission();
      if (mounted) {
        setState(() {
          _isLocationReady = res is LocationPermissionGranted;
        });
      }
    } catch (_) {}
  }

  void _showChangePasswordDialog(BuildContext context, String? email) {
    if (email == null || email.isEmpty) return;
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
                                .sendPasswordResetEmail(email);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      err ?? 'Reset email sent to $email'),
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

  void _showThemeDialog(BuildContext context, SettingsProvider settings, String? uid) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final options = [
          (mode: ThemeMode.system, label: 'System default', icon: Icons.phone_android_rounded),
          (mode: ThemeMode.light, label: 'Light mode', icon: Icons.light_mode_outlined),
          (mode: ThemeMode.dark, label: 'Dark mode', icon: Icons.dark_mode_outlined),
        ];

        return AlertDialog(
          title: const Text('Appearance Theme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((opt) {
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
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer2<SettingsProvider, UserProvider>(
      builder: (context, settings, userProv, _) {
        final user = userProv.user;
        final uid = user?.uid ?? userProv.currentUid;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
            centerTitle: true,
          ),
          body: ListView(
            children: [
              // ── Safety & Permissions ────────────────────────────────────────────
              const _SectionHeader(label: 'Safety & Permissions'),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined,
                    color: AppColors.primary),
                title: const Text('Push Notifications'),
                subtitle: const Text('Emergency alerts and reminders'),
                value: settings.notificationsEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (v) =>
                    settings.setNotificationsEnabled(v, uid: uid),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.location_on_outlined,
                    color: AppColors.primary),
                title: const Text('Background Location'),
                subtitle: Text(_isLocationReady
                    ? 'Share location with emergency contacts'
                    : 'Location permission needed'),
                value: settings.locationSharingEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (v) async {
                  if (v && !_isLocationReady) {
                    final res = await _locationService.requestPermission();
                    setState(() {
                      _isLocationReady = res is LocationPermissionGranted;
                    });
                  }
                  settings.setLocationSharingEnabled(v, uid: uid);
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.mic_outlined,
                    color: AppColors.primary),
                title: const Text('Voice SOS Detection'),
                subtitle: const Text('Trigger SOS by speaking emergency keywords'),
                value: settings.voiceSosEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (v) => settings.setVoiceSosEnabled(v, uid: uid),
              ),
              ListTile(
                leading: const Icon(Icons.record_voice_over_outlined,
                    color: AppColors.primary),
                title: const Text('Configure Voice SOS'),
                subtitle: const Text('Test keywords, microphone & status'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.voiceSos),
              ),

              // ── Appearance ───────────────────────────────────────────────────────
              const _SectionHeader(label: 'Appearance'),
              ListTile(
                leading: const Icon(Icons.dark_mode_outlined,
                    color: AppColors.primary),
                title: const Text('Theme Mode'),
                subtitle: Text(settings.themeModeLabel),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showThemeDialog(context, settings, uid),
              ),

              // ── Security ─────────────────────────────────────────────────────────
              const _SectionHeader(label: 'Security'),
              SwitchListTile(
                secondary: const Icon(Icons.fingerprint_rounded,
                    color: AppColors.primary),
                title: const Text('Biometric Lock'),
                subtitle: const Text('Require fingerprint / face to open app'),
                value: settings.biometricEnabled,
                activeThumbColor: AppColors.primary,
                onChanged: (v) {
                  settings.setBiometricEnabled(v, uid: uid);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(v
                          ? 'Biometric lock enabled'
                          : 'Biometric lock disabled'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.key_outlined, color: AppColors.primary),
                title: const Text('Change Password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _showChangePasswordDialog(context, user?.email),
              ),

              // ── About ────────────────────────────────────────────────────────────
              const _SectionHeader(label: 'About'),
              ListTile(
                leading:
                    const Icon(Icons.info_outline, color: AppColors.primary),
                title: const Text('App Version'),
                trailing: Text(
                  '1.0.0',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined,
                    color: AppColors.primary),
                title: const Text('Privacy & Device Settings'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await openAppSettings();
                  _checkLocation();
                },
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined,
                    color: AppColors.primary),
                title: const Text('Open Source Licenses'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'Nari Suraksha',
                    applicationVersion: '1.0.0',
                  );
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// ── Private helper ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          fontSize: 12,
        ),
      ),
    );
  }
}
