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
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.confirmCancel),
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
      builder: (dialogContext) => AlertDialog(
        title: const Text(Strings.confirmDelete),
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

    final td = appointment.typeData;
    final typeColor = td != null ? AppColors.typeColor(td.colorIndex) : AppColors.draft;
    final typeIcon = td != null ? LucideIcons.tag : LucideIcons.circleQuestionMark;
    final typeLabel = td?.name ?? Strings.appointmentType;

    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.appointmentDetails),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowRight),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.pencil, size: 20),
            tooltip: Strings.edit,
            onPressed: () => context.push('/coordinator/edit/${widget.id}'),
          ),
        ],
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

              // --- Suggestion section ---
              if (appointment.status == AppointmentStatus.suggested &&
                  !_loadingSuggestion) ...[
                const SizedBox(height: 16),
                if (_suggestion != null)
                  SuggestionCard(
                    suggestion: _suggestion!,
                    onAccept: _actionLoading ? null : _acceptSuggestion,
                    onReject: _actionLoading ? null : _rejectSuggestion,
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.suggested.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.suggested.withValues(alpha: 0.15),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.info,
                            size: 16, color: AppColors.suggested),
                        SizedBox(width: 8),
                        Text(
                          'لا يوجد اقتراح نشط',
                          style: TextStyle(
                            color: AppColors.suggested,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (_loadingSuggestion)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),

              // --- Actions (always available) ---
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _actionLoading ? null : _cancelAppointment,
                        icon: const Icon(LucideIcons.x, size: 16),
                        label: const Text(Strings.cancel),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed:
                            _actionLoading ? null : _deleteAppointment,
                        icon: const Icon(LucideIcons.trash2, size: 16),
                        label: const Text(Strings.delete),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
