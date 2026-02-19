class AppointmentSuggestion {
  final String id;
  final String appointmentId;
  final String suggestedBy;
  final DateTime suggestedStart;
  final DateTime suggestedEnd;
  final String? message;
  final bool isActive;
  final DateTime createdAt;

  const AppointmentSuggestion({
    required this.id,
    required this.appointmentId,
    required this.suggestedBy,
    required this.suggestedStart,
    required this.suggestedEnd,
    this.message,
    required this.isActive,
    required this.createdAt,
  });

  factory AppointmentSuggestion.fromJson(Map<String, dynamic> json) =>
      AppointmentSuggestion(
        id: json['id'],
        appointmentId: json['appointment_id'],
        suggestedBy: json['suggested_by'],
        suggestedStart: DateTime.parse(json['suggested_start']),
        suggestedEnd: DateTime.parse(json['suggested_end']),
        message: json['message'],
        isActive: json['is_active'],
        createdAt: DateTime.parse(json['created_at']),
      );

  Map<String, dynamic> toJsonForInsert() => {
        'appointment_id': appointmentId,
        'suggested_start': suggestedStart.toUtc().toIso8601String(),
        'suggested_end': suggestedEnd.toUtc().toIso8601String(),
        'message': message,
      };
}
