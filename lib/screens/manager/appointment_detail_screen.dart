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
  AppointmentSuggestion? _suggestion;

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
  }

  Future<void> _loadSuggestion() async {
    try {
      final suggestion = await ref
          .read(appointmentProvider.notifier)
          .fetchActiveSuggestion(widget.id);
      if (mounted) setState(() => _suggestion = suggestion);
    } catch (_) {}
  }

  Future<void> _approveAppointment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.confirmApprove),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(Strings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.confirmReject),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(Strings.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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

    final td = appointment.typeData;
    final typeColor = td != null ? AppColors.typeColor(td.colorIndex) : AppColors.draft;
    final typeIcon = td != null ? LucideIcons.tag : LucideIcons.circleQuestionMark;
    final typeLabel = td?.name ?? Strings.appointmentType;
    final isPending = appointment.status == AppointmentStatus.pending;
    final isDraft = appointment.isDraft;

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
              // --- Header card with type + status ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      typeColor.withValues(alpha: 0.08),
                      typeColor.withValues(alpha: 0.02),
                    ],
                    begin: AlignmentDirectional.topStart,
                    end: AlignmentDirectional.bottomEnd,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: typeColor.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(typeIcon, size: 20, color: typeColor),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              color: typeColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: appointment.status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      appointment.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // --- Requires approval indicator ---
              if (!appointment.requiresApproval)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.confirmed.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.confirmed.withValues(alpha: 0.15)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.shieldOff, size: 16, color: AppColors.confirmed),
                        const SizedBox(width: 8),
                        const Text(
                          'لا يتطلب موافقة المدير',
                          style: TextStyle(fontSize: 13, color: AppColors.confirmed),
                        ),
                      ],
                    ),
                  ),
                ),

              // --- Date & time card ---
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  children: [
                    if (appointment.startTime != null) ...[
                      _InfoRow(
                        icon: LucideIcons.calendarDays,
                        label: 'التاريخ',
                        value: formatDate(appointment.startTime!),
                      ),
                      Divider(
                        height: 24,
                        color: Colors.grey.withValues(alpha: 0.15),
                      ),
                      _InfoRow(
                        icon: LucideIcons.clock,
                        label: 'الوقت',
                        value: formatTimeRange(
                            appointment.startTime!, appointment.endTime!),
                      ),
                    ] else if (_suggestion != null) ...[
                      _InfoRow(
                        icon: LucideIcons.calendarDays,
                        label: 'التاريخ (مقترح)',
                        value: formatDate(_suggestion!.suggestedStart),
                      ),
                      Divider(
                        height: 24,
                        color: Colors.grey.withValues(alpha: 0.15),
                      ),
                      _InfoRow(
                        icon: LucideIcons.clock,
                        label: 'الوقت (مقترح)',
                        value: formatTimeRange(
                            _suggestion!.suggestedStart, _suggestion!.suggestedEnd),
                      ),
                    ] else
                      _InfoRow(
                        icon: LucideIcons.clock,
                        label: 'الوقت',
                        value: Strings.timeNotSet,
                      ),
                    if (appointment.location != null &&
                        appointment.location!.isNotEmpty) ...[
                      Divider(
                        height: 24,
                        color: Colors.grey.withValues(alpha: 0.15),
                      ),
                      _InfoRow(
                        icon: LucideIcons.mapPin,
                        label: Strings.location,
                        value: appointment.location!,
                      ),
                    ],
                  ],
                ),
              ),

              // --- Notes section ---
              if (appointment.notes != null &&
                  appointment.notes!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(LucideIcons.notepadText,
                              size: 16,
                              color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            Strings.notes,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        appointment.notes!,
                        style: const TextStyle(fontSize: 14, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],

              // --- Draft: Set Time button ---
              if (isDraft) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.draft.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.draft.withValues(alpha: 0.15),
                    ),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _actionLoading
                          ? null
                          : () => context.push('/manager/draft/${widget.id}'),
                      icon: const Icon(LucideIcons.calendarClock, size: 16),
                      label: const Text(Strings.setTime),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],

              // --- Actions for pending appointments ---
              if (isPending) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _actionLoading ? null : _approveAppointment,
                          icon: const Icon(LucideIcons.check, size: 16),
                          label: const Text(Strings.approve),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.confirmed,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed:
                              _actionLoading ? null : _rejectAppointment,
                          icon: const Icon(LucideIcons.x, size: 16),
                          label: const Text(Strings.reject),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.rejected,
                            side: const BorderSide(color: AppColors.rejected),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _actionLoading
                              ? null
                              : () =>
                                  context.push('/manager/suggest/${widget.id}'),
                          icon:
                              const Icon(LucideIcons.clockArrowUp, size: 16),
                          label: const Text(Strings.suggestAlternative),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.suggested,
                            side:
                                const BorderSide(color: AppColors.suggested),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // --- Metadata ---
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _MetaRow(
                      label: 'تاريخ الإنشاء',
                      value: formatDateTime(appointment.createdAt),
                    ),
                    if (appointment.reviewedAt != null) ...[
                      const SizedBox(height: 6),
                      _MetaRow(
                        label: 'تاريخ المراجعة',
                        value: formatDateTime(appointment.reviewedAt!),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
