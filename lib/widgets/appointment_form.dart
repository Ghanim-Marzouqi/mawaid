import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../constants/strings.dart';
import '../providers/appointment_type_provider.dart';
import '../theme/colors.dart';

class AppointmentFormData {
  String title;
  String? typeId;
  DateTime? startTime;
  DateTime? endTime;
  String? location;
  String? notes;
  bool requiresApproval;
  bool isDraft;

  AppointmentFormData({
    this.title = '',
    this.typeId,
    this.startTime,
    this.endTime,
    this.location,
    this.notes,
    this.requiresApproval = true,
    this.isDraft = false,
  });
}

class AppointmentForm extends ConsumerStatefulWidget {
  final AppointmentFormData? initialData;
  final bool isEditing;
  final bool isLoading;
  final void Function(AppointmentFormData data) onSubmit;

  const AppointmentForm({
    super.key,
    this.initialData,
    this.isEditing = false,
    this.isLoading = false,
    required this.onSubmit,
  });

  @override
  ConsumerState<AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends ConsumerState<AppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  String? _typeId;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  DateTime? _startTime;
  DateTime? _endTime;
  late bool _requiresApproval;
  bool _isDraft = false;
  bool _draftRequiresConfirmation = true;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _titleController = TextEditingController(text: data?.title ?? '');
    _locationController = TextEditingController(text: data?.location ?? '');
    _notesController = TextEditingController(text: data?.notes ?? '');
    _typeId = data?.typeId;
    _startTime = data?.startTime;
    _endTime = data?.endTime;
    _requiresApproval = data?.requiresApproval ?? true;
    _isDraft = data?.isDraft ?? false;
    _startTimeController = TextEditingController(text: _formatPicked(_startTime));
    _endTimeController = TextEditingController(text: _formatPicked(_endTime));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
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
        _startTimeController.text = _formatPicked(_startTime);
        if (_endTime == null || _endTime!.isBefore(picked)) {
          _endTime = picked.add(const Duration(hours: 1));
        }
        _endTimeController.text = _formatPicked(_endTime);
      } else {
        _endTime = picked;
        _endTimeController.text = _formatPicked(_endTime);
      }
    });
  }

  String _formatPicked(DateTime? dt) {
    if (dt == null) return '';
    final d = dt;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    if (!_isDraft && (_startTime == null || _endTime == null)) return;

    widget.onSubmit(AppointmentFormData(
      title: _titleController.text.trim(),
      typeId: _typeId,
      startTime: _isDraft ? null : _startTime,
      endTime: _isDraft ? null : _endTime,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      requiresApproval: _isDraft ? _draftRequiresConfirmation : _requiresApproval,
      isDraft: _isDraft,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final typeState = ref.watch(appointmentTypeProvider);
    final types = typeState.types;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: Strings.title,
              prefixIcon: Icon(LucideIcons.type),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return Strings.requiredField;
              }
              if (value.length > 200) return Strings.titleTooLong;
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Dynamic type dropdown
          DropdownButtonFormField<String>(
            initialValue: _typeId,
            decoration: const InputDecoration(
              labelText: Strings.appointmentType,
              prefixIcon: Icon(LucideIcons.tag),
            ),
            items: types
                .map((t) => DropdownMenuItem(
                      value: t.id,
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.typeColor(t.colorIndex),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(t.name),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() => _typeId = value);
            },
            validator: (value) {
              if (value == null) return Strings.requiredField;
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Requires approval toggle (always visible, disabled when draft)
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: Text(
                Strings.requiresApproval,
                style: TextStyle(
                  fontSize: 14,
                  color: _isDraft ? AppColors.onSurfaceVariant.withValues(alpha: 0.5) : null,
                ),
              ),
              value: _isDraft ? true : _requiresApproval,
              onChanged: _isDraft
                  ? null
                  : (value) {
                      setState(() => _requiresApproval = value);
                    },
              secondary: Icon(
                (_isDraft || _requiresApproval) ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
                color: _isDraft
                    ? AppColors.onSurfaceVariant.withValues(alpha: 0.4)
                    : (_requiresApproval ? AppColors.primary : AppColors.cancelled),
                size: 20,
              ),
              dense: true,
            ),
          ),
          // Draft toggle (create mode only)
          if (!widget.isEditing) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text(
                  Strings.managerSetsTime,
                  style: TextStyle(fontSize: 14),
                ),
                value: _isDraft,
                onChanged: (value) {
                  setState(() => _isDraft = value);
                },
                secondary: Icon(
                  _isDraft ? LucideIcons.calendarClock : LucideIcons.calendar,
                  color: _isDraft ? AppColors.draft : AppColors.onSurfaceVariant,
                  size: 20,
                ),
                dense: true,
              ),
            ),
          ],
          // Review time toggle (only when draft is on, same level)
          if (_isDraft) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text(
                  Strings.draftRequiresConfirmation,
                  style: TextStyle(fontSize: 14),
                ),
                value: _draftRequiresConfirmation,
                onChanged: (value) {
                  setState(() => _draftRequiresConfirmation = value);
                },
                secondary: Icon(
                  _draftRequiresConfirmation ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
                  color: _draftRequiresConfirmation ? AppColors.draft : AppColors.cancelled,
                  size: 20,
                ),
                dense: true,
              ),
            ),
          ],
          if (!_isDraft) ...[
            const SizedBox(height: 16),
            _DateTimeField(
              label: Strings.startTime,
              controller: _startTimeController,
              icon: LucideIcons.calendarClock,
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
              controller: _endTimeController,
              icon: LucideIcons.calendarClock,
              onTap: () => _pickDateTime(isStart: false),
              validator: (_) {
                if (_endTime == null) return Strings.requiredField;
                if (_startTime != null) {
                  if (!_endTime!.isAfter(_startTime!)) {
                    return Strings.startMustBeBeforeEnd;
                  }
                  if (_endTime!.difference(_startTime!).inMinutes < 5) {
                    return Strings.minDuration;
                  }
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 16),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: Strings.location,
              prefixIcon: Icon(LucideIcons.mapPin),
            ),
            validator: (value) {
              if (value != null && value.length > 500) {
                return Strings.locationTooLong;
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: Strings.notes,
              prefixIcon: Icon(LucideIcons.notepadText),
            ),
            maxLines: 3,
            validator: (value) {
              if (value != null && value.length > 1000) {
                return Strings.notesTooLong;
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: widget.isLoading ? null : _handleSubmit,
            child: widget.isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(widget.isEditing ? Strings.save : Strings.create),
          ),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final VoidCallback onTap;
  final String? Function(String?)? validator;

  const _DateTimeField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(LucideIcons.chevronDown),
      ),
      onTap: onTap,
      validator: validator,
    );
  }
}
