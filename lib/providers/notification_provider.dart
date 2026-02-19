import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notification.dart';
import '../services/supabase_service.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;
  final int unreadCount;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
    this.unreadCount = 0,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
    int? unreadCount,
    bool clearError = false,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  @override
  NotificationState build() => const NotificationState();

  Future<void> fetchNotifications() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await supabase
          .from('notifications')
          .select()
          .order('created_at', ascending: false);
      final notifications =
          (data as List).map((e) => AppNotification.fromJson(e)).toList();
      final unreadCount = notifications.where((n) => !n.isRead).length;
      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
        unreadCount: unreadCount,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
    await fetchNotifications();
  }

  Future<void> markAllAsRead() async {
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('is_read', false);
    await fetchNotifications();
  }

  void handleRealtimeInsert(Map<String, dynamic> payload) {
    fetchNotifications();
  }
}

final notificationProvider =
    NotifierProvider<NotificationNotifier, NotificationState>(
        NotificationNotifier.new);
