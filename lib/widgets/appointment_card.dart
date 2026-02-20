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
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Color accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: _typeColor,
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(12),
                    bottomStart: Radius.circular(12),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child:
                                Icon(_typeIcon, size: 13, color: _typeColor),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _typeLabel,
                            style: TextStyle(
                              color: _typeColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            LucideIcons.clock,
                            size: 13,
                            color: AppColors.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            formatTimeRange(
                                appointment.startTime, appointment.endTime),
                            style: TextStyle(
                              color: AppColors.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            LucideIcons.calendarDays,
                            size: 13,
                            color: AppColors.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              formatShortDate(appointment.startTime),
                              style: TextStyle(
                                color: AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                                fontSize: 12,
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
                            Icon(
                              LucideIcons.mapPin,
                              size: 13,
                              color: AppColors.onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                appointment.location!,
                                style: TextStyle(
                                  color: AppColors.onSurfaceVariant
                                      .withValues(alpha: 0.6),
                                  fontSize: 12,
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
              // Chevron
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: Icon(
                  LucideIcons.chevronLeft,
                  size: 16,
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.3),
                ),
              ),
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
        AppointmentType.external_ => LucideIcons.building2,
      };

  String get _typeLabel => switch (appointment.type) {
        AppointmentType.ministry => Strings.ministry,
        AppointmentType.patient => Strings.patient,
        AppointmentType.external_ => Strings.external_,
      };
}
