import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/app_back_arrow.dart';
import '../../widgets/empty_state.dart';
import '../../providers/notifications_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsProvider>().loadNotifications(refresh: true);
    });
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'notifications.just_now'.tr();
    if (diff.inMinutes < 60) return 'notifications.minutes_ago'.tr(args: [diff.inMinutes.toString()]);
    if (diff.inHours < 24) return 'notifications.hours_ago'.tr(args: [diff.inHours.toString()]);
    return 'notifications.days_ago'.tr(args: [diff.inDays.toString()]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const AppBackArrow(),
        title: Text('notifications.title'.tr()),
        actions: [
          TextButton(
            onPressed: () => context.read<NotificationsProvider>().markAllAsRead(),
            child: Text('notifications.mark_all_read'.tr()),
          ),
        ],
      ),
      body: Consumer<NotificationsProvider>(
        builder: (_, np, __) {
          if (np.loading) return const Center(child: CircularProgressIndicator());
          if (np.notifications.isEmpty) {
            return EmptyState(
            icon: Icons.notifications_none,
            title: 'notifications.empty_title'.tr(),
            subtitle: 'notifications.empty_body'.tr(),
          );
          }
          return RefreshIndicator(
            onRefresh: () => np.loadNotifications(refresh: true),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: np.notifications.length,
              itemBuilder: (_, i) {
                final notif = np.notifications[i];
                return GestureDetector(
                  onTap: () {
                    if (!notif.isRead) np.markAsRead(notif.id);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: notif.isRead ? AppColors.border : AppColors.primary,
                        width: notif.isRead ? 1 : 2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!notif.isRead)
                          Container(
                            margin: const EdgeInsets.only(top: 6, right: 12),
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notif.title, style: AppTypography.body2.copyWith(fontWeight: FontWeight.w600)),
                              if (notif.body != null) ...[
                                const SizedBox(height: 4),
                                Text(notif.body!, style: AppTypography.caption),
                              ],
                              const SizedBox(height: 4),
                              Text(_timeAgo(notif.createdAt), style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
