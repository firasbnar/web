import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/api_client.dart';
import '../../core/env_config.dart';
import '../../providers/boutique_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_button.dart';
import '../../utils/format_utils.dart';

class TelegramSettingsScreen extends StatefulWidget {
  const TelegramSettingsScreen({super.key});
  @override
  State<TelegramSettingsScreen> createState() => _TelegramSettingsScreenState();
}

class _TelegramSettingsScreenState extends State<TelegramSettingsScreen> {
  bool _loading = false;
  bool _verifying = false;
  bool _testing = false;

  String? _botUsername;
  String? _connectionCode;
  String? _expiresAt;
  String? _error;

  Future<void> _startConnection() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiClient();
      final res = await api.post('/telegram/connect/start');
      final data = res['data'] as Map?;
      if (data != null) {
        setState(() {
          _botUsername = data['botUsername'] as String? ?? EnvConfig.telegramBotUsername;
          _connectionCode = data['connectionCode'] as String?;
          _expiresAt = data['expiresAt'] as String?;
        });
      }
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _verifyConnection() async {
    setState(() { _verifying = true; _error = null; });
    try {
      final api = ApiClient();
      final res = await api.post('/telegram/connect/verify');
      final success = res['success'] == true;
      if (success) {
        final bp = context.read<BoutiqueProvider>();
        await bp.loadBoutiques();
        _botUsername = null;
        _connectionCode = null;
        _expiresAt = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('common.success'.tr()), backgroundColor: AppColors.success),
          );
        }
      } else {
        final msg = res['message'] as String? ?? 'telegram.code_not_found'.tr();
        _error = msg;
      }
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    }
    if (mounted) setState(() => _verifying = false);
  }

  Future<void> _disconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('telegram.disconnect'.tr()),
        content: Text('telegram.disconnect_confirm'.tr()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('common.cancel'.tr())),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('telegram.disconnect'.tr(), style: const TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() { _loading = true; _error = null; });
    try {
      final api = ApiClient();
      await api.delete('/telegram/disconnect');
      final bp = context.read<BoutiqueProvider>();
      await bp.loadBoutiques();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('common.success'.tr()), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _testNotification() async {
    setState(() { _testing = true; _error = null; });
    try {
      final bp = context.read<BoutiqueProvider>();
      final res = await bp.testTelegramNotification();
      final message = res?['message'] as String? ?? 'common.success'.tr();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      _error = ApiClient.extractErrorMessage(e);
    }
    if (mounted) setState(() => _testing = false);
  }

  void _copyCode() {
    if (_connectionCode == null) return;
    Clipboard.setData(ClipboardData(text: _connectionCode!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('common.success'.tr()), backgroundColor: AppColors.success),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bp = context.watch<BoutiqueProvider>();
    final bout = bp.activeBoutique;
    final connected = bout?.telegramChatId != null && bout!.telegramChatId!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('menu.telegram'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bout != null) ...[
              Text(bout.name, style: AppTypography.heading2),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: connected ? AppColors.success : AppColors.textHint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    connected ? 'telegram.connected'.tr() : 'telegram.disconnected'.tr(),
                    style: AppTypography.body2.copyWith(
                      color: connected ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 32),

            if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 14)),
              ),
              const SizedBox(height: 16),
            ],

            if (connected) _buildConnectedUi() else if (_connectionCode != null) _buildVerificationUi() else _buildNotConnectedUi(),
          ],
        ),
      ),
    );
  }

  Widget _buildNotConnectedUi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('menu.telegram'.tr(), style: AppTypography.heading3),
        const SizedBox(height: 12),
        Text(
          'telegram.description'.tr(),
          style: AppTypography.body2.copyWith(color: AppColors.textSecondary, height: 1.5),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            label: 'telegram.connect'.tr(),
            loading: _loading,
            onPressed: _startConnection,
            icon: Icons.telegram,
            color: const Color(0xFF0098C7),
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationUi() {
    final expiresAt = FormatUtils.tryParseDateTime(_expiresAt);
    final expiresAtFormatted = FormatUtils.dateTime(context, expiresAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('telegram.connect'.tr(), style: AppTypography.heading3),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.telegram, color: Color(0xFF0098C7), size: 28),
                  const SizedBox(width: 8),
                  Text('@$_botUsername', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0098C7))),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0098C7).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text('telegram.your_code'.tr(), style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _copyCode,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(_connectionCode ?? '', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3)),
                            const SizedBox(width: 8),
                            const Icon(Icons.copy, size: 18, color: AppColors.textHint),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('telegram.instructions'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 8),
              _instructionStep(1, 'telegram.step1'.tr()),
              _instructionStep(2, 'telegram.step2'.tr(args: [_botUsername ?? EnvConfig.telegramBotUsername])),
              _instructionStep(3, 'telegram.step3'.tr()),
              _instructionStep(4, 'telegram.step4'.tr(args: [_connectionCode ?? ''])),
              _instructionStep(5, 'telegram.step5'.tr()),
              const SizedBox(height: 8),
              if (expiresAtFormatted.isNotEmpty)
                Text('telegram.expires'.tr(args: [expiresAtFormatted]), style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'telegram.verify'.tr(),
                loading: _verifying,
                onPressed: _verifyConnection,
                color: const Color(0xFF0098C7),
                icon: Icons.telegram,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'telegram.new_code'.tr(),
                loading: _loading,
                onPressed: _startConnection,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConnectedUi() {
    final bp = context.read<BoutiqueProvider>();
    final bout = bp.activeBoutique;
    final chatId = bout?.telegramChatId ?? '';
    final masked = chatId.length > 4 ? '${chatId.substring(0, 2)}****${chatId.substring(chatId.length - 2)}' : chatId;
    final displayUsername = _botUsername ?? EnvConfig.telegramBotUsername;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('telegram.connected_title'.tr(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('@$displayUsername', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    if (masked.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text('ID: $masked', style: const TextStyle(color: AppColors.textHint, fontSize: 12)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text('boutique.notifications'.tr(), style: AppTypography.heading3),
        const SizedBox(height: 8),
        Text(
          'telegram.notifications_desc'.tr(),
          style: AppTypography.body2.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        _notificationItem('telegram.notif_new_orders_title'.tr(), 'telegram.notif_new_orders_desc'.tr()),
        _notificationItem('telegram.notif_status_title'.tr(), 'telegram.notif_status_desc'.tr()),
        _notificationItem('telegram.notif_low_stock_title'.tr(), 'telegram.notif_low_stock_desc'.tr()),
        _notificationItem('telegram.notif_out_of_stock_title'.tr(), 'telegram.notif_out_of_stock_desc'.tr()),
        _notificationItem('telegram.notif_new_reviews_title'.tr(), 'telegram.notif_new_reviews_desc'.tr()),
        _notificationItem('telegram.notif_payments_title'.tr(), 'telegram.notif_payments_desc'.tr()),
        _notificationItem('telegram.notif_messages_title'.tr(), 'telegram.notif_messages_desc'.tr()),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'telegram.test'.tr(),
                loading: _testing,
                onPressed: _testNotification,
                color: const Color(0xFF0098C7),
                icon: Icons.telegram,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'telegram.disconnect'.tr(),
                loading: _loading,
                onPressed: _disconnect,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _instructionStep(int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22, height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0098C7),
              shape: BoxShape.circle,
            ),
            child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _notificationItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 18, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
