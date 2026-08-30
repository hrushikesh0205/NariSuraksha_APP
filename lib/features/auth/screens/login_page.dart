import 'package:flutter/material.dart';
import 'package:nari_suraksha/core/services/auth_service.dart';
import 'package:nari_suraksha/core/theme/app_colors.dart';
import 'package:nari_suraksha/core/theme/app_text_styles.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/user_provider.dart';
import 'package:provider/provider.dart';

/// Premium sign-in screen — bright, minimal, warm, friendly.
///
/// Navigation logic: pushes `/home` on success, `/register` for new users.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signInWithEmailPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // Seed UserProvider with the freshly-loaded user model
      context.read<UserProvider>().updateLocalUser(user);

      // Subscribe ContactProvider to this user's contacts
      context.read<ContactProvider>().subscribe(user.uid);

      Navigator.pushReplacementNamed(context, '/home');
    } catch (e, st) {
      debugPrint('🔥 LoginPage._handleSignIn error: $e\n$st');
      if (!mounted) return;
      setState(() => _errorMessage = AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleForgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email address above first.');
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reset link sent to $email'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = AuthService.friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // ── Warm gold logo badge ────────────────────────────────────
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryContainer,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 46,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── Heading ─────────────────────────────────────────────────
                Text(
                  'Welcome back 👋',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.onBackground,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xs),

                Text(
                  'Sign in to stay protected',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Card form ───────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.xxl),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Email
                      _WarmTextField(
                        controller: _emailCtrl,
                        label: 'Email address',
                        hint: 'you@example.com',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        cs: cs,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // Password
                      _WarmTextField(
                        controller: _passwordCtrl,
                        label: 'Password',
                        hint: '••••••••',
                        icon: Icons.lock_outline_rounded,
                        obscure: true,
                        cs: cs,
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _handleForgotPassword,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryDark,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Forgot password?',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      // Error message
                      if (_errorMessage != null) ...[
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
                                  _errorMessage!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.md),

                      // Sign In button
                      _GoldButton(
                        label: _isLoading ? 'Signing in…' : 'Sign In',
                        isLoading: _isLoading,
                        onPressed: _isLoading ? null : _handleSignIn,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── Divider ─────────────────────────────────────────────────
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.outlineVariant)),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm),
                      child: Text(
                        'or',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.outlineVariant)),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                // ── Register link ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account? ",
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, '/register'),
                      child: Text(
                        'Register',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primaryDark,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared local widgets
// ─────────────────────────────────────────────────────────────────────────────

class _WarmTextField extends StatelessWidget {
  const _WarmTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.cs,
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final ColorScheme cs;
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTextStyles.bodySmall
            .copyWith(color: AppColors.onSurfaceVariant),
        hintStyle: AppTextStyles.bodyMedium
            .copyWith(color: AppColors.onSurfaceVariant.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: AppColors.primaryDark, size: 20),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.40),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
      ),
    );
  }
}
