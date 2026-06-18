import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/google_sign_in_button.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  final String? initialEmail;
  const LoginScreen({super.key, this.initialEmail});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailCtrl.text = widget.initialEmail!.trim().toLowerCase();
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AuthProvider>();
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;
    final success = await provider.login(email, password);

    if (!mounted) return;
    if (success) {
      if (provider.mustChangePassword) {
        context.go('/change-password');
      } else if (provider.role == 'ADMIN') {
        context.go('/admin');
      } else {
        context.go('/home');
      }
      return;
    }

    final errorMessage = provider.error ?? 'auth.invalid_credentials'.tr();
    final lowerMessage = errorMessage.toLowerCase();
    if (lowerMessage.contains('vérifier') || lowerMessage.contains('verifier')) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMessage),
        action: SnackBarAction(
          label: 'auth.resend'.tr(),
          onPressed: () {
            context.go('/verify-email', extra: _emailCtrl.text.trim());
          },
        ),
        duration: const Duration(seconds: 8),
        backgroundColor: AppColors.warning,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 60),
                const Icon(Icons.store, size: 60, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('MakeWebsite', style: AppTypography.heading1.copyWith(color: AppColors.primary)),
                const SizedBox(height: 40),
                AppTextField(
                  controller: _emailCtrl,
                  label: 'auth.email'.tr(),
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || v.isEmpty ? 'auth.email_required'.tr() : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordCtrl,
                  label: 'auth.password'.tr(),
                  prefixIcon: Icons.lock_outlined,
                  obscureText: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'auth.password_required'.tr() : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: Text('auth.forgot_password'.tr(), style: AppTypography.body2.copyWith(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) => AppButton(
                    label: 'auth.login'.tr(),
                    loading: auth.loading,
                    onPressed: _login,
                  ),
                ),
                const SizedBox(height: 12),
                GoogleSignInButton(
                  onSuccess: () {
                    if (!mounted) return;
                    final provider = context.read<AuthProvider>();
                    if (provider.mustChangePassword) {
                      context.go('/change-password');
                    } else if (provider.role == 'ADMIN') {
                      context.go('/admin');
                    } else {
                      context.go('/home');
                    }
                  },
                  onError: (error) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(error),
                      backgroundColor: AppColors.danger,
                    ));
                  },
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: Text('auth.create_account'.tr(), style: AppTypography.body2.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => context.go('/verify-email'),
                  child: Text('auth.verify_email'.tr(), style: AppTypography.body2.copyWith(color: AppColors.primary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
