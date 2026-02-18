import { create } from 'zustand';
import { supabase } from '@/services/supabase';
import type { Notification } from '@/types/database';

interface NotificationState {
  notifications: Notification[];
  unreadCount: number;
  isLoading: boolean;
  fetchNotifications: () => Promise<void>;
  handleNewNotification: (notification: Notification) => void;
  markAsRead: (notificationId: string) => Promise<void>;
}

export const useNotificationStore = create<NotificationState>((set, get) => ({
  notifications: [],
  unreadCount: 0,
  isLoading: false,

  fetchNotifications: async () => {
    set({ isLoading: true });
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .order('created_at', { ascending: false });

    if (!error && data) {
      const rows = data as Notification[];
      const unreadCount = rows.filter((n) => !n.is_read).length;
      set({ notifications: rows, unreadCount });
    }
    set({ isLoading: false });
  },

  handleNewNotification: (notification: Notification) => {
    const { notifications, unreadCount } = get();
    set({
      notifications: [notification, ...notifications],
      unreadCount: unreadCount + 1,
    });
  },

  markAsRead: async (notificationId: string) => {
    const { error } = await supabase
      .from('notifications')
      .update({ is_read: true })
      .eq('id', notificationId);

    if (!error) {
      const { notifications, unreadCount } = get();
      set({
        notifications: notifications.map((n) =>
          n.id === notificationId ? { ...n, is_read: true } : n
        ),
        unreadCount: Math.max(0, unreadCount - 1),
      });
    }
  },
}));
