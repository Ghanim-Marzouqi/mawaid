import 'appointment_type.dart';
import 'enums.dart';

class Appointment {
  final String id;
  final String title;
  final String? typeId;
  final AppointmentTypeModel? typeData;
  final AppointmentStatus status;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? location;
  final String? notes;
  final bool requiresApproval;
  final String createdBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Appointment({
    required this.id,
    required this.title,
    this.typeId,
    this.typeData,
    required this.status,
    this.startTime,
    this.endTime,
    this.location,
    this.notes,
    this.requiresApproval = true,
    required this.createdBy,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDraft => status == AppointmentStatus.draft;

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'],
        title: json['title'],
        typeId: json['type_id'],
        typeData: json['appointment_types'] != null
            ? AppointmentTypeModel.fromJson(json['appointment_types'])
            : null,
        status: AppointmentStatusX.fromDb(json['status']),
        startTime: json['start_time'] != null
            ? DateTime.parse(json['start_time'])
            : null,
        endTime: json['end_time'] != null
            ? DateTime.parse(json['end_time'])
            : null,
        location: json['location'],
        notes: json['notes'],
        requiresApproval: json['requires_approval'] ?? true,
        createdBy: json['created_by'],
        reviewedBy: json['reviewed_by'],
        reviewedAt: json['reviewed_at'] != null
            ? DateTime.parse(json['reviewed_at'])
            : null,
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );

  Map<String, dynamic> toJsonForInsert() => {
        'title': title,
        'type_id': typeId,
        if (startTime != null)
          'start_time': startTime!.toUtc().toIso8601String(),
        if (endTime != null)
          'end_time': endTime!.toUtc().toIso8601String(),
        'location': location,
        'notes': notes,
        'requires_approval': requiresApproval,
      };

  Appointment copyWith({
    String? id,
    String? title,
    String? typeId,
    AppointmentTypeModel? typeData,
    AppointmentStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? notes,
    bool? requiresApproval,
    String? createdBy,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      title: title ?? this.title,
      typeId: typeId ?? this.typeId,
      typeData: typeData ?? this.typeData,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      requiresApproval: requiresApproval ?? this.requiresApproval,
      createdBy: createdBy ?? this.createdBy,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
