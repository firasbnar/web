import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/app_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  const ResetPasswordScreen({super.key, this.token});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _api = ApiClient();
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final token = widget.token;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'Lien de réinitialisation invalide');
      return;
    }
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    if (password.length < 8) {
      setState(() => _error = 'Le mot de passe doit contenir au moins 8 caractères');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Les mots de passe ne correspondent pas');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await _api.resetPassword(token, password, confirm);
      setState(() { _success = true; _loading = false; });
    } catch (e) {
      setState(() {
        _error = ApiClient.extractErrorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Nouveau mot de passe'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Icon(Icons.lock_outline, size: 56, color: AppColors.primary.withAlpha(180)),
              const SizedBox(height: 20),
              Text('Choisir un mot de passe', style: AppTypography.heading1),
              const SizedBox(height: 8),
              Text(
                'Votre nouveau mot de passe doit contenir au moins 8 caractères.',
                style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              if (_success) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.success.withAlpha(60)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 48, color: AppColors.success),
                      const SizedBox(height: 12),
                      Text(
                        'Mot de passe réinitialisé avec succès !',
                        style: AppTypography.body1.copyWith(color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Vous pouvez maintenant vous connecter avec votre nouveau mot de passe.',
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                AppButton(
                  label: 'Se connecter',
                  onPressed: () => context.go('/login'),
                ),
              ] else ...[
                AppTextField(
                  controller: _passwordCtrl,
                  label: 'Nouveau mot de passe',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: _obscurePassword,
                  suffix: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirmCtrl,
                  label: 'Confirmer le mot de passe',
                  prefixIcon: Icons.lock_outlined,
                  obscureText: _obscureConfirm,
                  suffix: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                ],
                const SizedBox(height: 24),
                AppButton(
                  label: 'Réinitialiser',
                  loading: _loading,
                  onPressed: _submit,
                  icon: Icons.lock_open,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
