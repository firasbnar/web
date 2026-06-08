import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_back_arrow.dart';
import '../../providers/boutique_provider.dart';
import '../../providers/messages_provider.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});
  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final bp = context.read<BoutiqueProvider>();
    if (bp.activeBoutique != null) {
      context.read<MessagesProvider>().loadConversations(bp.activeBoutique!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(leading: const AppBackArrow(), title: Text('messages.title'.tr()), centerTitle: true),
      body: Consumer<MessagesProvider>(
        builder: (_, mp, __) {
          if (mp.loadingConversations) {
            return const Center(child: CircularProgressIndicator());
          }
          if (mp.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(mp.error!, style: AppTypography.body2, textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _load, child: Text('common.retry'.tr())),
                ],
              ),
            );
          }
          if (mp.conversations.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.message_outlined, size: 64, color: AppColors.textHint.withAlpha(60)),
                  const SizedBox(height: 16),
                  Text('messages.no_conversations'.tr(), style: AppTypography.body2.copyWith(color: AppColors.textHint)),
                  const SizedBox(height: 8),
                  Text('common.no_data'.tr(), style: AppTypography.caption),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: mp.conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final c = mp.conversations[i];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primarySurface,
                    child: Text(c.customerName[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  ),
                  title: Row(
                    children: [
                      Expanded(child: Text(c.customerName, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600))),
                      if (c.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${c.unreadCount}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(c.lastMessagePreview ?? '', style: AppTypography.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (c.lastMessageAt != null) ...[
                        const SizedBox(height: 4),
                        Text(_formatTime(c.lastMessageAt!), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                      ],
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
                  onTap: () => context.push('/messages/${c.id}', extra: c),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
