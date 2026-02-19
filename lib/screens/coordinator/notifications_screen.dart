import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/strings.dart';
import '../../providers/notification_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/notification_item.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(notificationProvider.notifier).fetchNotifications(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.notifications),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllAsRead(),
              child: const Text('قراءة الكل'),
            ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.wifiOff, size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: 16),
                      const Text(Strings.networkError),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(notificationProvider.notifier).fetchNotifications(),
                        child: const Text(Strings.retry),
                      ),
                    ],
                  ),
                )
              : state.notifications.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.bellOff, size: 48, color: AppColors.onSurfaceVariant),
                          SizedBox(height: 12),
                          Text(
                            Strings.noNotifications,
                            style: TextStyle(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => ref.read(notificationProvider.notifier).fetchNotifications(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.notifications.length,
                        itemBuilder: (context, index) {
                          final notification = state.notifications[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: NotificationItem(
                              notification: notification,
                              onTap: () {
                                ref
                                    .read(notificationProvider.notifier)
                                    .markAsRead(notification.id);
                                if (notification.appointmentId != null) {
                                  context.push(
                                    '/coordinator/appointment/${notification.appointmentId}',
                                  );
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
