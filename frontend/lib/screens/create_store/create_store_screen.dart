import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api_client.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';

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
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _slugCtrl.dispose();
    _descCtrl.dispose();
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
      });
      if (!mounted) return;
      await context.read<BoutiqueProvider>().loadBoutiques();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Boutique créée'), backgroundColor: AppColors.success));
      if (!context.mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle boutique')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Créer votre boutique', style: AppTypography.heading2),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nom de la boutique', border: OutlineInputBorder()),
              onChanged: (_) => _generateSlug(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _slugCtrl,
              decoration: InputDecoration(
                labelText: 'URL (slug)',
                border: const OutlineInputBorder(),
                hintText: 'ma-boutique',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.auto_fix_high, size: 18),
                  onPressed: _generateSlug,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: 'Description (optionnel)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(labelText: 'Devise', border: OutlineInputBorder()),
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
              decoration: const InputDecoration(labelText: 'Langue', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'ar', child: Text('العربية')),
              ],
              onChanged: (v) => setState(() => _language = v ?? 'fr'),
            ),
            const SizedBox(height: 32),
            AppButton(label: 'Créer la boutique', onPressed: _saving ? null : _create, loading: _saving),
          ],
        ),
      ),
    );
  }
}
