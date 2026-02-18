import { useEffect } from 'react';
import { supabase } from '@/services/supabase';
import { useAuthStore } from '@/stores/authStore';
import { useAppointmentStore } from '@/stores/appointmentStore';
import { useNotificationStore } from '@/stores/notificationStore';

export function useRealtimeSubscriptions() {
  const userId = useAuthStore((s) => s.profile?.id);

  useEffect(() => {
    if (!userId) return;

    const channel = supabase
      .channel('app-realtime')
      // Appointments: all changes
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'appointments' },
        (payload) => {
          useAppointmentStore.getState().handleRealtimeEvent(payload as any);
        }
      )
      // Notifications: filtered to current user
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `recipient_id=eq.${userId}`,
        },
        (payload) => {
          useNotificationStore
            .getState()
            .handleNewNotification(payload.new as any);
        }
      )
      // Suggestions: all changes
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'appointment_suggestions' },
        (payload) => {
          useAppointmentStore
            .getState()
            .handleSuggestionEvent(payload as any);
        }
      )
      .subscribe();

    return () => {
      supabase.removeChannel(channel);
    };
  }, [userId]);
}
