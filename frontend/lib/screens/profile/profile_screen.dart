import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  String _language = 'fr';
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _deletingAccount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        _nameCtrl.text = user.fullName;
        _phoneCtrl.text = user.phone ?? '';
        _language = user.language ?? 'fr';
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    final ap = context.read<AuthProvider>();
    final ok = await ap.updateProfile({
      'fullName': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'language': _language,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Profil mis à jour' : ap.error ?? 'Erreur'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
      setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;
    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Les mots de passe ne correspondent pas'), backgroundColor: AppColors.danger));
      return;
    }
    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le mot de passe doit contenir au moins 6 caractères'), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _savingPassword = true);
    final ap = context.read<AuthProvider>();
    final ok = await ap.changePassword(_oldPassCtrl.text, newPass);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Mot de passe modifié' : ap.error ?? 'Erreur'),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
      if (ok) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      }
      setState(() => _savingPassword = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: const Text('Êtes-vous sûr de vouloir supprimer votre compte? Cette action est irréversible.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Confirmer la suppression'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deletingAccount = true);
    final ap = context.read<AuthProvider>();
    await ap.deleteAccount();
    if (mounted) {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {},
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primarySurface,
                      child: Text(
                        (user?.fullName.isNotEmpty == true ? user!.fullName[0] : '?').toUpperCase(),
                        style: const TextStyle(fontSize: 32, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(user?.fullName ?? 'Utilisateur', style: AppTypography.heading3),
                  Text(user?.email ?? '', style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Modifier le profil', style: AppTypography.heading4),
                  const SizedBox(height: 16),
                  TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nom complet')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Téléphone'), keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),
                  Text('Langue', style: AppTypography.body2),
                  const SizedBox(height: 8),
                  Row(children: [
                    _langOption('FR', 'fr'),
                    const SizedBox(width: 12),
                    _langOption('EN', 'en'),
                    const SizedBox(width: 12),
                    _langOption('AR', 'ar'),
                  ]),
                  const SizedBox(height: 16),
                  AppButton(label: 'Enregistrer', loading: _savingProfile, onPressed: _saveProfile),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Changer mot de passe', style: AppTypography.heading4),
                  const SizedBox(height: 16),
                  TextFormField(controller: _oldPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Ancien mot de passe')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau mot de passe')),
                  const SizedBox(height: 12),
                  TextFormField(controller: _confirmPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmer')),
                  const SizedBox(height: 16),
                  AppButton(label: 'Changer le mot de passe', loading: _savingPassword, onPressed: _changePassword),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  context.read<AuthProvider>().logout();
                  context.go('/login');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Se déconnecter', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _deletingAccount ? null : _confirmDeleteAccount,
              child: _deletingAccount
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Supprimer mon compte', style: AppTypography.body2.copyWith(color: AppColors.danger)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _langOption(String label, String value) {
    final selected = _language == value;
    return GestureDetector(
      onTap: () => setState(() => _language = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        )),
      ),
    );
  }
}
