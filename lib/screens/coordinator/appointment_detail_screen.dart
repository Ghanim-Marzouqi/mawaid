import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/strings.dart';
import '../../models/appointment_suggestion.dart';
import '../../models/enums.dart';
import '../../providers/appointment_provider.dart';
import '../../theme/colors.dart';
import '../../utils/format_date.dart';
import '../../widgets/conflict_dialog.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/suggestion_card.dart';

class AppointmentDetailScreen extends ConsumerStatefulWidget {
  final String id;

  const AppointmentDetailScreen({super.key, required this.id});

  @override
  ConsumerState<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState
    extends ConsumerState<AppointmentDetailScreen> {
  AppointmentSuggestion? _suggestion;
  bool _loadingSuggestion = false;
  bool _actionLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
  }

  Future<void> _loadSuggestion() async {
    setState(() => _loadingSuggestion = true);
    try {
      final suggestion = await ref
          .read(appointmentProvider.notifier)
          .fetchActiveSuggestion(widget.id);
      if (mounted) {
        setState(() {
          _suggestion = suggestion;
          _loadingSuggestion = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingSuggestion = false);
    }
  }

  Future<void> _acceptSuggestion() async {
    if (_suggestion == null) return;
    setState(() => _actionLoading = true);
    try {
      // Check conflicts for the suggested time
      final conflicts = await ref
          .read(appointmentProvider.notifier)
          .checkConflicts(
            startTime: _suggestion!.suggestedStart,
            endTime: _suggestion!.suggestedEnd,
            excludeId: widget.id,
          );

      if (conflicts.isNotEmpty && mounted) {
        final proceed = await showConflictDialog(context, conflicts);
        if (proceed != true) {
          setState(() => _actionLoading = false);
          return;
        }
      }

      await ref.read(appointmentProvider.notifier).acceptSuggestion(
            appointmentId: widget.id,
            suggestion: _suggestion!,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.suggestionAccepted),
            backgroundColor: AppColors.confirmed,
          ),
        );
        _loadSuggestion();
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

  Future<void> _rejectSuggestion() async {
    if (_suggestion == null) return;
    setState(() => _actionLoading = true);
    try {
      await ref.read(appointmentProvider.notifier).rejectSuggestion(
            appointmentId: widget.id,
            suggestionId: _suggestion!.id,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.suggestionRejected),
            backgroundColor: AppColors.confirmed,
          ),
        );
        _loadSuggestion();
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

  Future<void> _cancelAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(Strings.confirmCancel),
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
      await ref.read(appointmentProvider.notifier).cancelAppointment(widget.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.appointmentCancelled),
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

  Future<void> _deleteAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(Strings.confirmDelete),
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
      await ref.read(appointmentProvider.notifier).deleteAppointment(widget.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.appointmentDeleted),
            backgroundColor: AppColors.confirmed,
          ),
        );
        context.go('/coordinator');
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
    final canCancel = !isMinistry &&
        (appointment.status == AppointmentStatus.pending ||
            appointment.status == AppointmentStatus.confirmed);
    final canDelete = !isMinistry &&
        appointment.status == AppointmentStatus.pending;

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
              if (appointment.status == AppointmentStatus.suggested &&
                  !_loadingSuggestion) ...[
                const SizedBox(height: 24),
                if (_suggestion != null)
                  SuggestionCard(
                    suggestion: _suggestion!,
                    onAccept: _actionLoading ? null : _acceptSuggestion,
                    onReject: _actionLoading ? null : _rejectSuggestion,
                  )
                else
                  const Text(
                    'لا يوجد اقتراح نشط',
                    style: TextStyle(color: AppColors.onSurfaceVariant),
                  ),
              ],
              if (_loadingSuggestion)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              const SizedBox(height: 24),
              if (canCancel)
                OutlinedButton.icon(
                  onPressed: _actionLoading ? null : _cancelAppointment,
                  icon: const Icon(LucideIcons.x, size: 16),
                  label: const Text(Strings.cancel),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                ),
              if (canDelete) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _actionLoading ? null : _deleteAppointment,
                  icon: const Icon(LucideIcons.trash2, size: 16),
                  label: const Text(Strings.delete),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
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
