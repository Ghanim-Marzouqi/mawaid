import 'enums.dart';

class Appointment {
  final String id;
  final String title;
  final AppointmentType type;
  final AppointmentStatus status;
  final DateTime startTime;
  final DateTime endTime;
  final String? location;
  final String? notes;
  final String createdBy;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Appointment({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.startTime,
    required this.endTime,
    this.location,
    this.notes,
    required this.createdBy,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
        id: json['id'],
        title: json['title'],
        type: AppointmentTypeX.fromDb(json['type']),
        status: AppointmentStatusX.fromDb(json['status']),
        startTime: DateTime.parse(json['start_time']),
        endTime: DateTime.parse(json['end_time']),
        location: json['location'],
        notes: json['notes'],
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
        'type': type.toDb(),
        'start_time': startTime.toUtc().toIso8601String(),
        'end_time': endTime.toUtc().toIso8601String(),
        'location': location,
        'notes': notes,
      };

  Appointment copyWith({
    String? id,
    String? title,
    AppointmentType? type,
    AppointmentStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    String? location,
    String? notes,
    String? createdBy,
    String? reviewedBy,
    DateTime? reviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Appointment(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
