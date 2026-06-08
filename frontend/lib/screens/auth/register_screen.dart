import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      _nameCtrl.text.trim(),
      _emailCtrl.text.trim().toLowerCase(),
      _passwordCtrl.text,
      null,
      'fr',
    );
    if (mounted) {
      if (ok) {
        if (auth.emailVerificationRequired) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('register.verification_sent'.tr()),
            backgroundColor: AppColors.success,
          ));
          context.go('/verify-email', extra: _emailCtrl.text.trim().toLowerCase());
        } else if (auth.isAuthenticated) {
          context.go(auth.role == 'ADMIN' ? '/admin' : '/home');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(auth.error ?? 'common.operation_failed'.tr()),
          backgroundColor: AppColors.danger,
        ));
      }
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
                const SizedBox(height: 40),
                const Icon(Icons.store, size: 60, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('register.title'.tr(), style: AppTypography.heading1.copyWith(color: AppColors.primary)),
                const SizedBox(height: 40),
                AppTextField(
                  controller: _nameCtrl,
                  label: 'register.full_name'.tr(),
                  prefixIcon: Icons.person_outlined,
                  validator: (v) => v == null || v.trim().isEmpty ? 'auth.full_name_required'.tr() : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _emailCtrl,
                  label: 'register.email'.tr(),
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'auth.email_required'.tr();
                    if (!v.contains('@')) return 'auth.email_invalid'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordCtrl,
                  label: 'register.password'.tr(),
                  prefixIcon: Icons.lock_outlined,
                  obscureText: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 8) return 'auth.password_min_length'.tr();
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirmCtrl,
                  label: 'register.confirm_password'.tr(),
                  prefixIcon: Icons.lock_outlined,
                  obscureText: _obscureConfirm,
                  suffix: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  validator: (v) {
                    if (v != _passwordCtrl.text) return 'auth.password_mismatch'.tr();
                    return null;
                  },
                  onSubmitted: (_) => _register(),
                ),
                const SizedBox(height: 8),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) {
                    if (auth.error != null) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(auth.error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 16),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) => AppButton(
                    label: 'register.submit'.tr(),
                    loading: auth.loading,
                    onPressed: _register,
                    icon: Icons.person_add,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: Text(
                    'auth.already_have_account'.tr(),
                    style: AppTypography.body2.copyWith(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
