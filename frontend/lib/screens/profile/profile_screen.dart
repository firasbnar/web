import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_back_arrow.dart';
import '../../widgets/app_button.dart';
import '../../providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiClient();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  String _language = 'fr';
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _deletingAccount = false;
  bool _uploadingImage = false;
  bool _showOldPass = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _language = context.locale.languageCode;
      final user = context.read<AuthProvider>().user;
      if (user != null) {
        _nameCtrl.text = user.fullName;
        _phoneCtrl.text = user.phone ?? '';
      }
      setState(() {});
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

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
    if (picked == null) return;
    setState(() => _uploadingImage = true);
    try {
      final res = await _api.uploadFile('/users/me/profile-picture', picked);
      final url = res['data']?['profilePictureUrl'] as String?;
      if (url != null && mounted) {
        context.read<AuthProvider>().updateAvatar(url);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile.profile_picture_updated'.tr()), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
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
        content: Text(ok ? 'profile.profile_updated'.tr() : ap.error ?? 'common.error'.tr()),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ));
      setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final current = _oldPassCtrl.text;
    final newPass = _newPassCtrl.text;
    final confirm = _confirmPassCtrl.text;
    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.password_mismatch'.tr()), backgroundColor: AppColors.danger));
      return;
    }
    if (newPass.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.password_min_length'.tr()), backgroundColor: AppColors.danger));
      return;
    }
    if (current.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('profile.enter_current_password'.tr()), backgroundColor: AppColors.danger));
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await _api.put('/users/me/password', data: {
        'currentPassword': current,
        'newPassword': newPass,
        'confirmPassword': confirm,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('profile.password_changed'.tr()), backgroundColor: AppColors.success));
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiClient.extractErrorMessage(e)), backgroundColor: AppColors.danger));
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('profile.delete_account_title'.tr()),
        content: Text('profile.delete_account_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text('common.confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _deletingAccount = true);
    final ap = context.read<AuthProvider>();
    await ap.deleteAccount();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final initials = (user?.fullName.isNotEmpty == true ? user!.fullName[0] : '?').toUpperCase();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(leading: const AppBackArrow(), title: Text('profile.title'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAvatarCard(user, initials),
            const SizedBox(height: 16),
            _buildProfileEditCard(),
            const SizedBox(height: 16),
            _buildPasswordChangeCard(),
            const SizedBox(height: 24),
            _buildLogoutAndDelete(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarCard(dynamic user, String initials) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF7C4DFF)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primary.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.white.withAlpha(50),
                backgroundImage: user?.avatarUrl != null && user!.avatarUrl!.isNotEmpty
                    ? NetworkImage(user.avatarUrl!) : null,
                child: user?.avatarUrl == null || user!.avatarUrl!.isEmpty
                    ? Text(initials, style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700))
                    : null,
              ),
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: _uploadImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 4)],
                    ),
                    child: _uploadingImage
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.camera_alt, size: 18, color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(user?.fullName ?? 'menu.profile'.tr(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 4),
          Text(user?.email ?? '', style: TextStyle(fontSize: 14, color: Colors.white.withAlpha(200))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(user?.role ?? 'USER', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileEditCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('profile.edit_profile'.tr(), style: AppTypography.heading4),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'profile.full_name'.tr(),
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneCtrl,
            decoration: InputDecoration(
              labelText: 'profile.phone'.tr(),
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),
          Text('profile.language'.tr(), style: AppTypography.body2.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(children: [
            _langOption('FR', 'fr'),
            const SizedBox(width: 12),
            _langOption('EN', 'en'),
            const SizedBox(width: 12),
            _langOption('AR', 'ar'),
          ]),
          const SizedBox(height: 20),
          AppButton(label: 'common.save'.tr(), loading: _savingProfile, onPressed: _saveProfile),
        ],
      ),
    );
  }

  Widget _buildPasswordChangeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('profile.password_change'.tr(), style: AppTypography.heading4),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _oldPassCtrl,
            obscureText: !_showOldPass,
            decoration: InputDecoration(
              labelText: 'profile.current_password'.tr(),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_showOldPass ? Icons.visibility : Icons.visibility_off, size: 20),
                onPressed: () => setState(() => _showOldPass = !_showOldPass),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _newPassCtrl,
            obscureText: !_showNewPass,
            decoration: InputDecoration(
              labelText: 'profile.new_password'.tr(),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_showNewPass ? Icons.visibility : Icons.visibility_off, size: 20),
                onPressed: () => setState(() => _showNewPass = !_showNewPass),
              ),
              helperText: 'profile.password_min_length'.tr(),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmPassCtrl,
            obscureText: !_showConfirmPass,
            decoration: InputDecoration(
              labelText: 'profile.confirm_password'.tr(),
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                icon: Icon(_showConfirmPass ? Icons.visibility : Icons.visibility_off, size: 20),
                onPressed: () => setState(() => _showConfirmPass = !_showConfirmPass),
              ),
            ),
          ),
          const SizedBox(height: 20),
          AppButton(label: 'profile.password_change'.tr(), loading: _savingPassword, onPressed: _changePassword),
        ],
      ),
    );
  }

  Widget _buildLogoutAndDelete() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              context.read<AuthProvider>().logout();
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: Text('profile.logout'.tr(), style: const TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: _deletingAccount ? null : _confirmDeleteAccount,
          child: _deletingAccount
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text('profile.delete_account'.tr(), style: AppTypography.body2.copyWith(color: AppColors.danger)),
        ),
      ],
    );
  }

  Widget _langOption(String label, String value) {
    final selected = _language == value;
    return GestureDetector(
      onTap: () async {
        setState(() => _language = value);
        await _api.storage.saveLocaleCode(value);
        await context.setLocale(Locale(value));
      },
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
