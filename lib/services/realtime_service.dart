import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  final SupabaseClient _supabase;
  RealtimeChannel? _channel;

  RealtimeService(this._supabase);

  void subscribe({
    required String userId,
    required void Function(PostgresChangePayload payload) onAppointmentChange,
    required void Function(PostgresChangePayload payload) onNotificationInsert,
    required void Function(PostgresChangePayload payload) onSuggestionChange,
  }) {
    _channel = _supabase
        .channel('app-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointments',
          callback: onAppointmentChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_id',
            value: userId,
          ),
          callback: onNotificationInsert,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'appointment_suggestions',
          callback: onSuggestionChange,
        )
        .subscribe();
  }

  void dispose() {
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
      _channel = null;
    }
  }
}
