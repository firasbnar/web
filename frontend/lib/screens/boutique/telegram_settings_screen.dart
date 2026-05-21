import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';

class TelegramSettingsScreen extends StatefulWidget {
  const TelegramSettingsScreen({super.key});
  @override
  State<TelegramSettingsScreen> createState() => _TelegramSettingsScreenState();
}

class _TelegramSettingsScreenState extends State<TelegramSettingsScreen> {
  final _chatIdCtrl = TextEditingController();
  bool _enabled = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final bp = context.read<BoutiqueProvider>();
    final boutique = bp.activeBoutique;
    if (boutique != null) {
      _chatIdCtrl.text = boutique.telegramChatId ?? '';
      _enabled = boutique.telegramEnabled;
    }
  }

  @override
  void dispose() {
    _chatIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final chatId = _chatIdCtrl.text.trim();

    if (chatId.isNotEmpty) {
      final digitsOnly = chatId.replaceAll(RegExp(r'[^0-9]'), '');
      if (digitsOnly.isEmpty) {
        _showError('L\'ID Chat Telegram doit être un nombre valide');
        return;
      }
      if (digitsOnly != chatId) {
        _chatIdCtrl.text = digitsOnly;
      }
    }

    setState(() => _saving = true);
    final bp = context.read<BoutiqueProvider>();
    final success = await bp.saveTelegramSettings(chatId, _enabled);
    if (mounted) {
      setState(() => _saving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paramètres Telegram mis à jour'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        _showError(bp.error ?? 'Erreur lors de la sauvegarde');
      }
    }
  }

  Future<void> _toggleEnabled() async {
    if (!_enabled && _chatIdCtrl.text.trim().isEmpty) {
      _showError('Veuillez d\'abord saisir un ID Chat Telegram');
      return;
    }
    setState(() => _saving = true);
    final bp = context.read<BoutiqueProvider>();
    final newValue = !_enabled;
    final success = await bp.saveTelegramSettings(_chatIdCtrl.text.trim(), newValue);
    if (mounted) {
      if (success) {
        setState(() => _enabled = newValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Telegram ${newValue ? 'activé' : 'désactivé'}'), backgroundColor: AppColors.success),
        );
      } else {
        _showError(bp.error ?? 'Erreur lors de la sauvegarde');
      }
      setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BoutiqueProvider>();
    final boutique = bp.activeBoutique;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Telegram')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (boutique != null) ...[
              Text(boutique.name, style: AppTypography.heading2),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _enabled ? AppColors.success : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _enabled ? 'Actif' : 'Inactif',
                    style: AppTypography.body2.copyWith(
                      color: _enabled ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),
            Text('Configuration Telegram', style: AppTypography.heading3),
            const SizedBox(height: 8),
            Text(
              'Entrez l\'ID de votre chat Telegram pour recevoir les notifications de nouvelles commandes.',
              style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _chatIdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'ID Chat Telegram',
                hintText: '123456789',
                border: OutlineInputBorder(),
                helperText: 'Obtenez cet ID depuis @userinfobot sur Telegram',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: _enabled ? 'Désactiver' : 'Activer',
                    onPressed: _saving ? null : _toggleEnabled,
                    color: _enabled ? AppColors.danger : AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Sauvegarder les paramètres',
                    loading: _saving,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
