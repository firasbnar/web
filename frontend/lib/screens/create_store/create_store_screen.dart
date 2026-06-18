import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_back_arrow.dart';

class CreateStoreScreen extends StatefulWidget {
  const CreateStoreScreen({super.key});

  @override
  State<CreateStoreScreen> createState() => _CreateStoreScreenState();
}

class _CreateStoreScreenState extends State<CreateStoreScreen> {
  final _api = ApiClient();
  final _nameCtrl = TextEditingController();
  final _slugCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _currency = 'TND';
  String _language = 'fr';
  String _category = '';
  final _countryCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.read<AuthProvider>().canCreateBoutique && mounted) {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
    _countryCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  void _generateSlug() {
    final name = _nameCtrl.text.trim().toLowerCase();
    _slugCtrl.text = name.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await _api.post('/boutiques', data: {
        'name': _nameCtrl.text.trim(),
        'slug': _slugCtrl.text.trim().isNotEmpty ? _slugCtrl.text.trim() : _nameCtrl.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-'),
        'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
        'currency': _currency,
        'language': _language,
        'category': _category.isNotEmpty ? _category : null,
        'country': _countryCtrl.text.trim().isNotEmpty ? _countryCtrl.text.trim() : null,
        'city': _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : null,
      });
      if (!mounted) return;
      await context.read<BoutiqueProvider>().loadBoutiques();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('common.success'.tr()), backgroundColor: AppColors.success));
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('common.error'.tr(args: [e.toString()])), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const AppBackArrow(), title: Text('store_catalog.title'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('store_catalog.title'.tr(), style: AppTypography.heading2),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: 'boutique.name'.tr(), border: const OutlineInputBorder()),
              onChanged: (_) => _generateSlug(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _slugCtrl,
              decoration: InputDecoration(
                labelText: 'boutique.slug'.tr(),
                border: const OutlineInputBorder(),
                hintText: 'boutique.slug_help'.tr(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  onPressed: _generateSlug,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              decoration: InputDecoration(labelText: 'boutique.description'.tr(), border: const OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'boutique.categories'.tr(), border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: '', child: Text('common.select'.tr())),
                const DropdownMenuItem(value: 'Mode', child: Text('Mode')),
                const DropdownMenuItem(value: 'Alimentation', child: Text('Alimentation')),
                const DropdownMenuItem(value: 'Électronique', child: Text('Électronique')),
                const DropdownMenuItem(value: 'Maison', child: Text('Maison')),
                const DropdownMenuItem(value: 'Beauté', child: Text('Beauté')),
                const DropdownMenuItem(value: 'Sports', child: Text('Sports')),
                const DropdownMenuItem(value: 'Autre', child: Text('Autre')),
              ],
              onChanged: (v) => setState(() => _category = v ?? ''),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: InputDecoration(labelText: 'boutique.currency'.tr(), border: const OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'TND', child: Text('TND - Dinar tunisien')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR - Euro')),
                DropdownMenuItem(value: 'USD', child: Text('USD - Dollar US')),
              ],
              onChanged: (v) => setState(() => _currency = v ?? 'TND'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _language,
              decoration: InputDecoration(labelText: 'boutique.language'.tr(), border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: 'fr', child: Text('profile.french'.tr())),
                DropdownMenuItem(value: 'en', child: Text('profile.english'.tr())),
                DropdownMenuItem(value: 'ar', child: Text('profile.arabic'.tr())),
              ],
              onChanged: (v) => setState(() => _language = v ?? 'fr'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countryCtrl,
              decoration: InputDecoration(labelText: 'boutique.countries'.tr(), border: const OutlineInputBorder(), hintText: 'boutique.country_hint'.tr()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _cityCtrl,
              decoration: InputDecoration(labelText: 'boutique.city'.tr(), border: const OutlineInputBorder(), hintText: 'boutique.city_hint'.tr()),
            ),
            const SizedBox(height: 32),
            AppButton(label: 'common.save'.tr(), onPressed: _saving ? null : _create, loading: _saving),
          ],
        ),
      ),
    );
  }
}
