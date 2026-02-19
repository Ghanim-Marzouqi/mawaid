import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/enums.dart';
import '../constants/strings.dart';


class AppointmentFormData {
  String title;
  AppointmentType type;
  DateTime? startTime;
  DateTime? endTime;
  String? location;
  String? notes;

  AppointmentFormData({
    this.title = '',
    this.type = AppointmentType.patient,
    this.startTime,
    this.endTime,
    this.location,
    this.notes,
  });
}

class AppointmentForm extends StatefulWidget {
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
  State<AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<AppointmentForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _locationController;
  late final TextEditingController _notesController;
  late AppointmentType _type;
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;
    _titleController = TextEditingController(text: data?.title ?? '');
    _locationController = TextEditingController(text: data?.location ?? '');
    _notesController = TextEditingController(text: data?.notes ?? '');
    _type = data?.type ?? AppointmentType.patient;
    _startTime = data?.startTime;
    _endTime = data?.endTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
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
    final d = dt;
    return '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;
    if (_startTime == null || _endTime == null) return;

    widget.onSubmit(AppointmentFormData(
      title: _titleController.text.trim(),
      type: _type,
      startTime: _startTime,
      endTime: _endTime,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
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
          if (!widget.isEditing)
            DropdownButtonFormField<AppointmentType>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: Strings.appointmentType,
                prefixIcon: Icon(LucideIcons.tag),
              ),
              items: const [
                DropdownMenuItem(
                  value: AppointmentType.ministry,
                  child: Text(Strings.ministry),
                ),
                DropdownMenuItem(
                  value: AppointmentType.patient,
                  child: Text(Strings.patient),
                ),
                DropdownMenuItem(
                  value: AppointmentType.external_,
                  child: Text(Strings.external_),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
          if (!widget.isEditing) const SizedBox(height: 16),
          _DateTimeField(
            label: Strings.startTime,
            value: _formatPicked(_startTime),
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
            value: _formatPicked(_endTime),
            icon: LucideIcons.calendarClock,
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
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final String? Function(String?)? validator;

  const _DateTimeField({
    required this.label,
    required this.value,
    required this.icon,
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
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(LucideIcons.chevronDown),
      ),
      onTap: onTap,
      validator: validator,
    );
  }
}
