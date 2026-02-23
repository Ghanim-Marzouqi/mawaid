import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/strings.dart';
import '../../providers/appointment_provider.dart';
import '../../widgets/appointment_form.dart';
import '../../widgets/conflict_dialog.dart';

class CreateAppointmentScreen extends ConsumerStatefulWidget {
  const CreateAppointmentScreen({super.key});

  @override
  ConsumerState<CreateAppointmentScreen> createState() =>
      _CreateAppointmentScreenState();
}

class _CreateAppointmentScreenState
    extends ConsumerState<CreateAppointmentScreen> {
  bool _isLoading = false;

  Future<void> _handleSubmit(AppointmentFormData data) async {
    // Draft submit skips time validation and conflict check
    if (!data.isDraft) {
      if (data.startTime == null || data.endTime == null) return;
    }

    setState(() => _isLoading = true);

    try {
      // Check conflicts only for non-draft appointments with times
      if (!data.isDraft && data.startTime != null && data.endTime != null) {
        final conflicts = await ref
            .read(appointmentProvider.notifier)
            .checkConflicts(
              startTime: data.startTime!,
              endTime: data.endTime!,
            );

        if (conflicts.isNotEmpty && mounted) {
          final proceed = await showConflictDialog(context, conflicts);
          if (proceed != true) {
            setState(() => _isLoading = false);
            return;
          }
        }
      }

      await ref.read(appointmentProvider.notifier).createAppointment(
            title: data.title,
            typeId: data.typeId,
            startTime: data.startTime,
            endTime: data.endTime,
            location: data.location,
            notes: data.notes,
            requiresApproval: data.requiresApproval,
            isDraft: data.isDraft,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                data.isDraft ? Strings.draftCreated : Strings.appointmentCreated),
            backgroundColor: const Color(0xFF2E7D32),
          ),
        );
        context.go('/coordinator');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.genericError),
            backgroundColor: Color(0xFFB3261E),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Strings.newAppointment)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: AppointmentForm(
            isLoading: _isLoading,
            onSubmit: _handleSubmit,
          ),
        ),
      ),
    );
  }
}
