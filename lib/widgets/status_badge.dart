import 'package:flutter/material.dart';
import '../models/enums.dart';
import '../constants/strings.dart';
import '../theme/colors.dart';

class StatusBadge extends StatelessWidget {
  final AppointmentStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label,
        style: TextStyle(
          color: _color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Color get _color => switch (status) {
        AppointmentStatus.pending => AppColors.pending,
        AppointmentStatus.confirmed => AppColors.confirmed,
        AppointmentStatus.rejected => AppColors.rejected,
        AppointmentStatus.suggested => AppColors.suggested,
        AppointmentStatus.cancelled => AppColors.cancelled,
      };

  String get _label => switch (status) {
        AppointmentStatus.pending => Strings.pending,
        AppointmentStatus.confirmed => Strings.confirmed,
        AppointmentStatus.rejected => Strings.rejected,
        AppointmentStatus.suggested => Strings.suggested,
        AppointmentStatus.cancelled => Strings.cancelled,
      };
}
