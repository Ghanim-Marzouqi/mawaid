import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/appointment.dart';
import '../models/appointment_suggestion.dart';
import '../models/enums.dart';
import '../services/supabase_service.dart';

class AppointmentState {
  final List<Appointment> appointments;
  final bool isLoading;
  final String? error;

  const AppointmentState({
    this.appointments = const [],
    this.isLoading = false,
    this.error,
  });

  AppointmentState copyWith({
    List<Appointment>? appointments,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AppointmentState(
      appointments: appointments ?? this.appointments,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AppointmentNotifier extends Notifier<AppointmentState> {
  @override
  AppointmentState build() => const AppointmentState();

  Future<void> fetchAppointments() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await supabase
          .from('appointments')
          .select()
          .order('start_time');
      final appointments =
          (data as List).map((e) => Appointment.fromJson(e)).toList();
      state = state.copyWith(appointments: appointments, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<Appointment> createAppointment({
    required String title,
    required AppointmentType type,
    required DateTime startTime,
    required DateTime endTime,
    String? location,
    String? notes,
  }) async {
    final data = await supabase
        .from('appointments')
        .insert({
          'title': title,
          'type': type.toDb(),
          'start_time': startTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          'location': location,
          'notes': notes,
          'created_by': supabase.auth.currentUser!.id,
        })
        .select()
        .single();
    final appointment = Appointment.fromJson(data);
    state = state.copyWith(
      appointments: [...state.appointments, appointment],
    );
    return appointment;
  }

  Future<void> updateAppointment(
    String id,
    Map<String, dynamic> updates,
  ) async {
    await supabase.from('appointments').update(updates).eq('id', id);
    await fetchAppointments();
  }

  Future<void> approveAppointment(String id) async {
    await supabase.from('appointments').update({
      'status': 'confirmed',
      'reviewed_by': supabase.auth.currentUser!.id,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    await fetchAppointments();
  }

  Future<void> rejectAppointment(String id) async {
    await supabase.from('appointments').update({
      'status': 'rejected',
      'reviewed_by': supabase.auth.currentUser!.id,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
    await fetchAppointments();
  }

  Future<void> suggestAlternative({
    required String appointmentId,
    required DateTime suggestedStart,
    required DateTime suggestedEnd,
    String? message,
  }) async {
    await supabase.from('appointment_suggestions').insert({
      'appointment_id': appointmentId,
      'suggested_by': supabase.auth.currentUser!.id,
      'suggested_start': suggestedStart.toUtc().toIso8601String(),
      'suggested_end': suggestedEnd.toUtc().toIso8601String(),
      'message': message,
    });
    await supabase
        .from('appointments')
        .update({'status': 'suggested'})
        .eq('id', appointmentId);
    await fetchAppointments();
  }

  Future<void> acceptSuggestion({
    required String appointmentId,
    required AppointmentSuggestion suggestion,
  }) async {
    await supabase.from('appointments').update({
      'start_time': suggestion.suggestedStart.toUtc().toIso8601String(),
      'end_time': suggestion.suggestedEnd.toUtc().toIso8601String(),
      'status': 'confirmed',
    }).eq('id', appointmentId);
    await supabase
        .from('appointment_suggestions')
        .update({'is_active': false})
        .eq('id', suggestion.id);
    await fetchAppointments();
  }

  Future<void> rejectSuggestion({
    required String appointmentId,
    required String suggestionId,
  }) async {
    await supabase
        .from('appointments')
        .update({'status': 'pending'})
        .eq('id', appointmentId);
    await supabase
        .from('appointment_suggestions')
        .update({'is_active': false})
        .eq('id', suggestionId);
    await fetchAppointments();
  }

  Future<void> cancelAppointment(String id) async {
    await supabase
        .from('appointments')
        .update({'status': 'cancelled'})
        .eq('id', id);
    await fetchAppointments();
  }

  Future<void> deleteAppointment(String id) async {
    await supabase.from('appointments').delete().eq('id', id);
    await fetchAppointments();
  }

  Future<List<Map<String, dynamic>>> checkConflicts({
    required DateTime startTime,
    required DateTime endTime,
    String? excludeId,
  }) async {
    final result = await supabase.rpc('check_appointment_overlap', params: {
      'p_start_time': startTime.toUtc().toIso8601String(),
      'p_end_time': endTime.toUtc().toIso8601String(),
      'p_exclude_id': excludeId,
    });
    return List<Map<String, dynamic>>.from(result);
  }

  Future<AppointmentSuggestion?> fetchActiveSuggestion(
      String appointmentId) async {
    final data = await supabase
        .from('appointment_suggestions')
        .select()
        .eq('appointment_id', appointmentId)
        .eq('is_active', true)
        .maybeSingle();
    if (data == null) return null;
    return AppointmentSuggestion.fromJson(data);
  }

  void handleRealtimeEvent(Map<String, dynamic> payload) {
    fetchAppointments();
  }
}

final appointmentProvider =
    NotifierProvider<AppointmentNotifier, AppointmentState>(
        AppointmentNotifier.new);
