import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../constants/strings.dart';
import '../../providers/appointment_provider.dart';
import '../../theme/colors.dart';
import '../../widgets/conflict_dialog.dart';

class SuggestScreen extends ConsumerStatefulWidget {
  final String id;

  const SuggestScreen({super.key, required this.id});

  @override
  ConsumerState<SuggestScreen> createState() => _SuggestScreenState();
}

class _SuggestScreenState extends ConsumerState<SuggestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  DateTime? _startTime;
  DateTime? _endTime;
  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_startTime ?? now)
        : (_endTime ?? _startTime?.add(const Duration(hours: 1)) ?? now);

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(2030, 12, 31),
      locale: const Locale('ar', 'OM'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      initialEntryMode: TimePickerEntryMode.dialOnly,
    );
    if (time == null || !mounted) return;

    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    setState(() {
      if (isStart) {
        _startTime = picked;
        if (_endTime == null || _endTime!.isBefore(picked)) {
          _endTime = picked.add(const Duration(hours: 1));
        }
      } else {
        _endTime = picked;
      }
    });
  }

  String _formatPicked(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) return;

    setState(() => _isLoading = true);

    try {
      // Check conflicts
      final conflicts = await ref
          .read(appointmentProvider.notifier)
          .checkConflicts(
            startTime: _startTime!,
            endTime: _endTime!,
            excludeId: widget.id,
          );

      if (conflicts.isNotEmpty && mounted) {
        final proceed = await showConflictDialog(context, conflicts);
        if (proceed != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      await ref.read(appointmentProvider.notifier).suggestAlternative(
            appointmentId: widget.id,
            suggestedStart: _startTime!,
            suggestedEnd: _endTime!,
            message: _messageController.text.trim().isEmpty
                ? null
                : _messageController.text.trim(),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.suggestionSent),
            backgroundColor: AppColors.confirmed,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(Strings.genericError),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.suggestAlternative),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowRight),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _DateTimeField(
                  label: Strings.startTime,
                  value: _formatPicked(_startTime),
                  onTap: () => _pickDateTime(isStart: true),
                  validator: (_) {
                    if (_startTime == null) return Strings.requiredField;
                    if (_endTime != null && !_startTime!.isBefore(_endTime!)) {
                      return Strings.startMustBeBeforeEnd;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _DateTimeField(
                  label: Strings.endTime,
                  value: _formatPicked(_endTime),
                  onTap: () => _pickDateTime(isStart: false),
                  validator: (_) {
                    if (_endTime == null) return Strings.requiredField;
                    if (_startTime != null) {
                      if (!_endTime!.isAfter(_startTime!)) {
                        return Strings.startMustBeBeforeEnd;
                      }
                      if (_endTime!.difference(_startTime!).inMinutes < 15) {
                        return Strings.minDuration;
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    labelText: Strings.message,
                    prefixIcon: Icon(LucideIcons.messageSquare),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value != null && value.length > 500) {
                      return Strings.messageTooLong;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleSubmit,
                  icon: _isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.clockArrowUp, size: 16),
                  label: const Text(Strings.suggestAlternative),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.suggested,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;
  final String? Function(String?)? validator;

  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(LucideIcons.calendarClock),
        suffixIcon: const Icon(LucideIcons.chevronDown),
      ),
      onTap: onTap,
      validator: validator,
    );
  }
}
