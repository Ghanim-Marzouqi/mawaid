import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/appointment.dart';
import '../models/enums.dart';
import '../constants/strings.dart';
import '../theme/colors.dart';
import '../utils/format_date.dart';
import 'status_badge.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback? onTap;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: _typeColor,
                width: 4,
              ),
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_typeIcon, size: 18, color: _typeColor),
                  const SizedBox(width: 8),
                  Text(
                    _typeLabel,
                    style: TextStyle(
                      color: _typeColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  StatusBadge(status: appointment.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                appointment.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    LucideIcons.clock,
                    size: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    formatTimeRange(
                        appointment.startTime, appointment.endTime),
                    style: const TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(
                    LucideIcons.calendarDays,
                    size: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      formatShortDate(appointment.startTime),
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (appointment.location != null &&
                  appointment.location!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        appointment.location!,
                        style: const TextStyle(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color get _typeColor => switch (appointment.type) {
        AppointmentType.ministry => AppColors.ministry,
        AppointmentType.patient => AppColors.patient,
        AppointmentType.external_ => AppColors.external_,
      };

  IconData get _typeIcon => switch (appointment.type) {
        AppointmentType.ministry => LucideIcons.landmark,
        AppointmentType.patient => LucideIcons.userRound,
        AppointmentType.external_ => LucideIcons.mapPin,
      };

  String get _typeLabel => switch (appointment.type) {
        AppointmentType.ministry => Strings.ministry,
        AppointmentType.patient => Strings.patient,
        AppointmentType.external_ => Strings.external_,
      };
}
