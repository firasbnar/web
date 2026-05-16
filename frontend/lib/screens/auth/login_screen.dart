import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AuthProvider>();
    final success = await provider.login(_emailCtrl.text.trim(), _passwordCtrl.text);
    if (mounted) {
      if (success) {
        if (provider.role == 'ADMIN') {
          context.go('/admin');
        } else {
          context.go('/home');
        }
      } else if (provider.error != null) {
        if (provider.error!.contains('vérifier') || provider.error!.contains('email')) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${provider.error!} → '),
            action: SnackBarAction(
              label: 'Renvoyer',
              onPressed: () {
                context.go('/verify-email', extra: _emailCtrl.text.trim());
              },
            ),
            duration: const Duration(seconds: 8),
            backgroundColor: AppColors.warning,
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.error!)));
        }
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
                const SizedBox(height: 60),
                const Icon(Icons.store, size: 60, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('MakeWebsite', style: AppTypography.heading1.copyWith(color: AppColors.primary)),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                  validator: (v) => v == null || v.isEmpty ? 'Email requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty ? 'Mot de passe requis' : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text('Mot de passe oublié?', style: AppTypography.body2.copyWith(color: AppColors.primary)),
                  ),
                ),
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) => AppButton(
                    label: 'Se connecter',
                    loading: auth.loading,
                    onPressed: _login,
                  ),
                ),
                const SizedBox(height: 12),
                Consumer<AuthProvider>(
                  builder: (_, auth, __) => SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.login),
                      label: Text(auth.loading ? 'Connexion...' : 'Continuer avec Google'),
                      onPressed: auth.loading ? null : () async {
                        final ok = await auth.loginWithGoogle();
                        if (ok && mounted) {
                          final role = context.read<AuthProvider>().role;
                          if (role == 'ADMIN') {
                            context.go('/admin');
                          } else {
                            context.go('/home');
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text("Pas de compte?", style: AppTypography.body2),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: Text('Créer un compte', style: AppTypography.body2.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
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
