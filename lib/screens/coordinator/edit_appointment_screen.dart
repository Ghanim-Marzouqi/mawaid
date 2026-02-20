import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/strings.dart';
import '../../providers/appointment_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/appointment_form.dart';
import '../../widgets/conflict_dialog.dart';

class EditAppointmentScreen extends ConsumerStatefulWidget {
  final String id;

  const EditAppointmentScreen({super.key, required this.id});

  @override
  ConsumerState<EditAppointmentScreen> createState() =>
      _EditAppointmentScreenState();
}

class _EditAppointmentScreenState
    extends ConsumerState<EditAppointmentScreen> {
  bool _isLoading = false;

  Future<void> _handleSubmit(AppointmentFormData data) async {
    if (data.startTime == null || data.endTime == null) return;

    setState(() => _isLoading = true);

    try {
      final conflicts = await ref
          .read(appointmentProvider.notifier)
          .checkConflicts(
            startTime: data.startTime!,
            endTime: data.endTime!,
            excludeId: widget.id,
          );

      if (conflicts.isNotEmpty && mounted) {
        final proceed = await showConflictDialog(context, conflicts);
        if (proceed != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      await ref.read(appointmentProvider.notifier).updateAppointment(
            widget.id,
            {
              'title': data.title,
              'start_time': data.startTime!.toUtc().toIso8601String(),
              'end_time': data.endTime!.toUtc().toIso8601String(),
              'location': data.location,
              'notes': data.notes,
            },
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.appointmentUpdated),
            backgroundColor: AppColors.confirmed,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.genericError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentProvider);
    final appointment = state.appointments
        .where((a) => a.id == widget.id)
        .firstOrNull;

    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(Strings.editAppointment),
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowRight),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.editAppointment),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowRight),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: AppointmentForm(
            isEditing: true,
            isLoading: _isLoading,
            initialData: AppointmentFormData(
              title: appointment.title,
              type: appointment.type,
              startTime: appointment.startTime,
              endTime: appointment.endTime,
              location: appointment.location,
              notes: appointment.notes,
            ),
            onSubmit: _handleSubmit,
          ),
        ),
      ),
    );
  }
}
