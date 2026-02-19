import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/strings.dart';
import '../../models/enums.dart';
import '../../providers/appointment_provider.dart';
import '../../theme/colors.dart';
import '../../utils/format_date.dart';
import '../../widgets/status_badge.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const AppointmentDetailScreen({super.key, required this.id});

  @override
  ConsumerState<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState
    extends ConsumerState<AppointmentDetailScreen> {
  bool _actionLoading = false;

  Future<void> _approveAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(Strings.confirmApprove),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Strings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Strings.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      await ref.read(appointmentProvider.notifier).approveAppointment(widget.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.appointmentApproved),
            backgroundColor: AppColors.confirmed,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.genericError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _rejectAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(Strings.confirmReject),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Strings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(Strings.confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      await ref.read(appointmentProvider.notifier).rejectAppointment(widget.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.appointmentRejected),
            backgroundColor: AppColors.confirmed,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.genericError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _actionLoading = false);
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
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isMinistry = appointment.type == AppointmentType.ministry;
    final isPending = appointment.status == AppointmentStatus.pending;
    final canAct = !isMinistry && isPending;

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.appointmentDetails),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowRight),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _DetailRow(
                icon: _typeIcon(appointment.type),
                iconColor: _typeColor(appointment.type),
                label: _typeLabel(appointment.type),
                child: StatusBadge(status: appointment.status),
              ),
              const Divider(height: 32),
              Text(
                appointment.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                icon: LucideIcons.calendar,
                iconColor: AppColors.onSurfaceVariant,
                label: formatDate(appointment.startTime),
              ),
              const SizedBox(height: 8),
              _DetailRow(
                icon: LucideIcons.clock,
                iconColor: AppColors.onSurfaceVariant,
                label: formatTimeRange(appointment.startTime, appointment.endTime),
              ),
              if (appointment.location != null &&
                  appointment.location!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _DetailRow(
                  icon: LucideIcons.mapPin,
                  iconColor: AppColors.onSurfaceVariant,
                  label: appointment.location!,
                ),
              ],
              if (appointment.notes != null &&
                  appointment.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  Strings.notes,
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(appointment.notes!),
              ],
              if (canAct) ...[
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _actionLoading ? null : _approveAppointment,
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: const Text(Strings.approve),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.confirmed,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _actionLoading ? null : _rejectAppointment,
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: const Text(Strings.reject),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.rejected,
                    side: const BorderSide(color: AppColors.rejected),
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _actionLoading
                      ? null
                      : () => context.push('/manager/suggest/${widget.id}'),
                  icon: const Icon(LucideIcons.clockArrowUp, size: 16),
                  label: const Text(Strings.suggestAlternative),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.suggested,
                    side: const BorderSide(color: AppColors.suggested),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _typeColor(AppointmentType type) => switch (type) {
        AppointmentType.ministry => AppColors.ministry,
        AppointmentType.patient => AppColors.patient,
        AppointmentType.external_ => AppColors.external_,
      };

  IconData _typeIcon(AppointmentType type) => switch (type) {
        AppointmentType.ministry => LucideIcons.landmark,
        AppointmentType.patient => LucideIcons.userRound,
        AppointmentType.external_ => LucideIcons.mapPin,
      };

  String _typeLabel(AppointmentType type) => switch (type) {
        AppointmentType.ministry => Strings.ministry,
        AppointmentType.patient => Strings.patient,
        AppointmentType.external_ => Strings.external_,
      };
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget? child;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 14)),
        if (child != null) ...[
          const Spacer(),
          child!,
        ],
      ],
    );
  }
}
