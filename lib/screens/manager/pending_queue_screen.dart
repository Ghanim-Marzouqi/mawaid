import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/strings.dart';
import '../../models/enums.dart';
import '../../providers/appointment_provider.dart';
import '../../theme/colors.dart';
import '../../utils/format_date.dart';
import '../../widgets/appointment_card.dart';

class PendingQueueScreen extends ConsumerStatefulWidget {
  const PendingQueueScreen({super.key});

  @override
  ConsumerState<PendingQueueScreen> createState() => _PendingQueueScreenState();
}

class _PendingQueueScreenState extends ConsumerState<PendingQueueScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(appointmentProvider.notifier).fetchAppointments(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appointmentProvider);
    final now = toMuscat(DateTime.now().toUtc());

    final pendingAppointments = state.appointments
        .where((a) => a.status == AppointmentStatus.pending)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final todayAppointments = state.appointments.where((a) {
      final start = toMuscat(a.startTime);
      return start.year == now.year &&
          start.month == now.month &&
          start.day == now.day &&
          a.status != AppointmentStatus.cancelled &&
          a.status != AppointmentStatus.rejected;
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final suggestedCount = state.appointments
        .where((a) => a.status == AppointmentStatus.suggested)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text(Strings.pendingQueue)),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.wifiOff, size: 48, color: AppColors.onSurfaceVariant),
                      const SizedBox(height: 16),
                      const Text(Strings.networkError),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(appointmentProvider.notifier).fetchAppointments(),
                        child: const Text(Strings.retry),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(appointmentProvider.notifier).fetchAppointments(),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              label: Strings.pendingCount,
                              count: pendingAppointments.length,
                              color: AppColors.pending,
                              icon: LucideIcons.clock,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              label: Strings.suggested,
                              count: suggestedCount,
                              color: AppColors.suggested,
                              icon: LucideIcons.lightbulb,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // --- Today's schedule ---
                      Row(
                        children: [
                          Text(
                            Strings.todaySchedule,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${todayAppointments.length} مواعيد',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatDate(DateTime.now()),
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (todayAppointments.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Column(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  LucideIcons.calendarOff,
                                  size: 24,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                Strings.noAppointments,
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ...todayAppointments.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppointmentCard(
                              appointment: a,
                              onTap: () => context.push('/manager/appointment/${a.id}'),
                            ),
                          ),
                        ),

                      // --- Pending queue ---
                      if (pendingAppointments.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              Strings.pendingCount,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.pending.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${pendingAppointments.length}',
                                style: const TextStyle(
                                  color: AppColors.pending,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...pendingAppointments.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AppointmentCard(
                              appointment: a,
                              onTap: () => context.push('/manager/appointment/${a.id}'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
