import { create } from 'zustand';
import { supabase } from '@/services/supabase';
import type { Appointment, AppointmentSuggestion } from '@/types/database';
import type { RealtimePostgresChangesPayload } from '@supabase/supabase-js';

interface AppointmentState {
  appointments: Appointment[];
  suggestions: AppointmentSuggestion[];
  isLoading: boolean;
  fetchAppointments: () => Promise<void>;
  fetchSuggestions: (appointmentId: string) => Promise<AppointmentSuggestion[]>;
  handleRealtimeEvent: (payload: RealtimePostgresChangesPayload<Appointment>) => void;
  handleSuggestionEvent: (payload: RealtimePostgresChangesPayload<AppointmentSuggestion>) => void;
}

export const useAppointmentStore = create<AppointmentState>((set, get) => ({
  appointments: [],
  suggestions: [],
  isLoading: false,

  fetchAppointments: async () => {
    set({ isLoading: true });
    const { data, error } = await supabase
      .from('appointments')
      .select('*')
      .order('start_time', { ascending: true });

    if (!error && data) {
      set({ appointments: data });
    }
    set({ isLoading: false });
  },

  fetchSuggestions: async (appointmentId: string) => {
    const { data } = await supabase
      .from('appointment_suggestions')
      .select('*')
      .eq('appointment_id', appointmentId)
      .eq('is_active', true)
      .order('created_at', { ascending: false });

    return data ?? [];
  },

  handleRealtimeEvent: (payload) => {
    const { appointments } = get();
    const eventType = payload.eventType;

    if (eventType === 'INSERT') {
      const newRow = payload.new as Appointment;
      set({ appointments: [...appointments, newRow] });
    } else if (eventType === 'UPDATE') {
      const updated = payload.new as Appointment;
      set({
        appointments: appointments.map((a) =>
          a.id === updated.id ? updated : a
        ),
      });
    } else if (eventType === 'DELETE') {
      const deleted = payload.old as { id: string };
      set({
        appointments: appointments.filter((a) => a.id !== deleted.id),
      });
    }
  },

  handleSuggestionEvent: (payload) => {
    const { suggestions } = get();
    const eventType = payload.eventType;

    if (eventType === 'INSERT') {
      const newSuggestion = payload.new as AppointmentSuggestion;
      set({ suggestions: [...suggestions, newSuggestion] });
    } else if (eventType === 'UPDATE') {
      const updated = payload.new as AppointmentSuggestion;
      set({
        suggestions: suggestions.map((s) =>
          s.id === updated.id ? updated : s
        ),
      });
    }
  },
}));
