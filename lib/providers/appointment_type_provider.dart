import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/appointment_type.dart';
import '../services/supabase_service.dart';
import '../theme/colors.dart';

class AppointmentTypeState {
  final List<AppointmentTypeModel> types;
  final bool isLoading;
  final String? error;

  const AppointmentTypeState({
    this.types = const [],
    this.isLoading = false,
    this.error,
  });

  AppointmentTypeState copyWith({
    List<AppointmentTypeModel>? types,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return AppointmentTypeState(
      types: types ?? this.types,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AppointmentTypeNotifier extends Notifier<AppointmentTypeState> {
  @override
  AppointmentTypeState build() => const AppointmentTypeState();

  Future<void> fetchTypes() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final data = await supabase
          .from('appointment_types')
          .select()
          .order('created_at');
      final types =
          (data as List).map((e) => AppointmentTypeModel.fromJson(e)).toList();
      state = state.copyWith(types: types, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createType(String name) async {
    final colorIndex = state.types.length % AppColors.typePalette.length;
    await supabase.from('appointment_types').insert({
      'name': name,
      'color_index': colorIndex,
      'created_by': supabase.auth.currentUser!.id,
    });
    await fetchTypes();
  }

  Future<void> updateType(String id, String name) async {
    await supabase
        .from('appointment_types')
        .update({'name': name})
        .eq('id', id);
    await fetchTypes();
  }

  Future<void> deleteType(String id) async {
    await supabase.from('appointment_types').delete().eq('id', id);
    await fetchTypes();
  }

  void handleRealtimeEvent(Map<String, dynamic> payload) {
    fetchTypes();
  }
}

final appointmentTypeProvider =
    NotifierProvider<AppointmentTypeNotifier, AppointmentTypeState>(
        AppointmentTypeNotifier.new);
