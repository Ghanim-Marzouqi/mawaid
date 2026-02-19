import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../constants/strings.dart';
import '../theme/colors.dart';
import '../utils/format_date.dart';

class ConflictDialog extends StatelessWidget {
  final List<Map<String, dynamic>> conflicts;
  final bool hasMinistryConflict;

  const ConflictDialog({
    super.key,
    required this.conflicts,
    required this.hasMinistryConflict,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: Icon(
        LucideIcons.triangleAlert,
        color: hasMinistryConflict ? AppColors.error : AppColors.pending,
        size: 40,
      ),
      title: Text(
        hasMinistryConflict ? Strings.conflictMinistry : Strings.conflictWarning,
        textAlign: TextAlign.center,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final conflict in conflicts)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    conflict['type'] == 'ministry'
                        ? LucideIcons.landmark
                        : LucideIcons.clock,
                    size: 16,
                    color: AppColors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          conflict['title'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          formatTimeRange(
                            DateTime.parse(conflict['start_time']),
                            DateTime.parse(conflict['end_time']),
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(Strings.cancel),
        ),
        if (!hasMinistryConflict)
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(Strings.conflictProceed),
          ),
      ],
    );
  }
}

/// Returns true if user wants to proceed, false otherwise.
/// Returns null if dismissed.
Future<bool?> showConflictDialog(
  BuildContext context,
  List<Map<String, dynamic>> conflicts,
) {
  final hasMinistry = conflicts.any(
    (c) => c['type'] == 'ministry' && c['status'] == 'confirmed',
  );

  return showDialog<bool>(
    context: context,
    builder: (_) => ConflictDialog(
      conflicts: conflicts,
      hasMinistryConflict: hasMinistry,
    ),
  );
}
