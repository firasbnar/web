import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';

class VerificationPendingScreen extends StatefulWidget {
  final String email;
  const VerificationPendingScreen({super.key, required this.email});

  @override
  State<VerificationPendingScreen> createState() => _VerificationPendingScreenState();
}

class _VerificationPendingScreenState extends State<VerificationPendingScreen> {
  final _api = ApiClient();
  final _emailCtrl = TextEditingController();
  bool _resending = false;
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.email;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await _api.post('/auth/resend-verification', data: {'email': _emailCtrl.text});
      setState(() => _resent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email de vérification renvoyé'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.extractErrorMessage(e)), backgroundColor: AppColors.danger));
      }
    }
    setState(() => _resending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 60),
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Icon(Icons.email_outlined, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 32),
              Text('Vérifiez votre email', style: AppTypography.heading2.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Text(
                'Nous avons envoyé un lien de vérification à',
                style: AppTypography.body1.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  hintText: 'Entrez votre email',
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withAlpha(60)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Le lien expire dans 24 heures', style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600, color: AppColors.primary)),
                          const SizedBox(height: 4),
                          Text('Vérifiez également vos spams.', style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              if (_resent)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 18, color: AppColors.success),
                      const SizedBox(width: 8),
                      Text('Email renvoyé !', style: AppTypography.body2.copyWith(color: AppColors.success)),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: _resending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: Text(_resending ? 'Envoi...' : 'Renvoyer l\'email'),
                  onPressed: _resending ? null : _resend,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Retour à la connexion',
                onPressed: () {
                  context.read<AuthProvider>().logout();
                  context.go('/login');
                },
                outlined: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
