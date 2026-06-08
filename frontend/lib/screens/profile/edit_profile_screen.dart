import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_back_button.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _api = ApiClient();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _language = 'fr';
  bool _loading = false;
  bool _saving = false;

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
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await _api.get('/auth/profile');
      if (!mounted) return;
      final data = res['data'];
      _nameCtrl.text = data['fullName'] ?? '';
      _phoneCtrl.text = data['phone'] ?? '';
      _language = data['language'] ?? 'fr';
    } catch (_) {
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await _api.put('/auth/profile', data: {
        'fullName': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'language': _language,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('profile.profile_updated'.tr()), backgroundColor: AppColors.success));
      if (!context.mounted) return;
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('common.error'.tr(args: [e.toString()])), backgroundColor: AppColors.danger));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppBackButton(),
        title: Text('profile.edit_profile'.tr()),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('profile.title'.tr(), style: AppTypography.heading3),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(labelText: 'profile.full_name'.tr(), border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneCtrl,
                    decoration: InputDecoration(labelText: 'profile.phone'.tr(), border: const OutlineInputBorder(), hintText: 'profile.phone'.tr()),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _language,
                    decoration: InputDecoration(labelText: 'profile.language'.tr(), border: const OutlineInputBorder()),
                    items: [
                      DropdownMenuItem(value: 'fr', child: Text('profile.french'.tr())),
                      DropdownMenuItem(value: 'en', child: Text('profile.english'.tr())),
                      DropdownMenuItem(value: 'ar', child: Text('profile.arabic'.tr())),
                    ],
                    onChanged: (v) => setState(() => _language = v ?? 'fr'),
                  ),
                  const SizedBox(height: 24),
                  AppButton(label: 'common.save'.tr(), onPressed: _saving ? null : _save, loading: _saving),
                ],
              ),
            ),
    );
  }
}
