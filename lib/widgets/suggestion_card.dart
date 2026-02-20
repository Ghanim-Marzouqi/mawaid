import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/appointment_suggestion.dart';
import '../constants/strings.dart';
import '../theme/colors.dart';
import '../utils/format_date.dart';

class SuggestionCard extends StatelessWidget {
  final AppointmentSuggestion suggestion;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const SuggestionCard({
    super.key,
    required this.suggestion,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.primary.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  LucideIcons.clockArrowUp,
                  size: 18,
                  color: AppColors.suggested,
                ),
                const SizedBox(width: 8),
                Text(
                  Strings.suggestAlternative,
                  style: const TextStyle(
                    color: AppColors.suggested,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(LucideIcons.calendar, size: 14, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  formatDate(suggestion.suggestedStart),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.clock, size: 14, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  formatTimeRange(suggestion.suggestedStart, suggestion.suggestedEnd),
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
            if (suggestion.message != null && suggestion.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                suggestion.message!,
                style: const TextStyle(
                  color: AppColors.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ],
            if (onAccept != null || onReject != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (onAccept != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        icon: const Icon(LucideIcons.check, size: 16),
                        label: const Text(Strings.acceptSuggestion),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.confirmed,
                        ),
                      ),
                    ),
                  if (onAccept != null && onReject != null)
                    const SizedBox(width: 8),
                  if (onReject != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(LucideIcons.x, size: 16),
                        label: const Text(Strings.rejectSuggestion),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.rejected,
                          side: const BorderSide(color: AppColors.rejected),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
