// Union types matching Supabase enums
export type UserRole = 'coordinator' | 'manager';
export type AppointmentType = 'ministry' | 'patient' | 'external';
export type AppointmentStatus = 'pending' | 'confirmed' | 'rejected' | 'suggested' | 'cancelled';
export type NotificationType =
  | 'new_appointment'
  | 'appointment_confirmed'
  | 'appointment_rejected'
  | 'alternative_suggested'
  | 'suggestion_accepted'
  | 'suggestion_rejected'
  | 'appointment_cancelled'
  | 'ministry_auto_confirmed';

// Row types
export interface Profile {
  id: string;
  role: UserRole;
  full_name: string;
  push_token: string | null;
  created_at: string;
  updated_at: string;
}

export interface Appointment {
  id: string;
  title: string;
  type: AppointmentType;
  status: AppointmentStatus;
  start_time: string;
  end_time: string;
  location: string | null;
  notes: string | null;
  created_by: string;
  reviewed_by: string | null;
  reviewed_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface AppointmentSuggestion {
  id: string;
  appointment_id: string;
  suggested_by: string;
  suggested_start: string;
  suggested_end: string;
  message: string | null;
  is_active: boolean;
  created_at: string;
}

export interface Notification {
  id: string;
  recipient_id: string;
  type: NotificationType;
  title: string;
  body: string;
  appointment_id: string | null;
  is_read: boolean;
  created_at: string;
}

// Supabase Database type interface for typed client
export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: Profile;
        Insert: Omit<Profile, 'created_at' | 'updated_at'>;
        Update: Partial<Omit<Profile, 'id' | 'created_at' | 'updated_at'>>;
      };
      appointments: {
        Row: Appointment;
        Insert: Omit<Appointment, 'id' | 'created_at' | 'updated_at' | 'status' | 'reviewed_by' | 'reviewed_at'> & {
          id?: string;
          status?: AppointmentStatus;
          reviewed_by?: string | null;
          reviewed_at?: string | null;
        };
        Update: Partial<Omit<Appointment, 'id' | 'created_at' | 'updated_at'>>;
      };
      appointment_suggestions: {
        Row: AppointmentSuggestion;
        Insert: Omit<AppointmentSuggestion, 'id' | 'created_at' | 'is_active'> & {
          id?: string;
          is_active?: boolean;
        };
        Update: Partial<Omit<AppointmentSuggestion, 'id' | 'created_at'>>;
      };
      notifications: {
        Row: Notification;
        Insert: Omit<Notification, 'id' | 'created_at' | 'is_read'> & {
          id?: string;
          is_read?: boolean;
        };
        Update: Partial<Omit<Notification, 'id' | 'created_at'>>;
      };
    };
    Functions: {
      check_appointment_overlap: {
        Args: {
          p_start_time: string;
          p_end_time: string;
          p_exclude_id?: string | null;
        };
        Returns: {
          id: string;
          title: string;
          type: AppointmentType;
          status: AppointmentStatus;
          start_time: string;
          end_time: string;
        }[];
      };
    };
    Enums: {
      user_role: UserRole;
      appointment_type: AppointmentType;
      appointment_status: AppointmentStatus;
      notification_type: NotificationType;
    };
  };
}
