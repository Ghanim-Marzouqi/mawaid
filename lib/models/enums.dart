enum UserRole { coordinator, manager }

enum AppointmentType { ministry, patient, external_ }

enum AppointmentStatus { pending, confirmed, rejected, suggested, cancelled }

enum NotificationType {
  newAppointment,
  appointmentConfirmed,
  appointmentRejected,
  alternativeSuggested,
  suggestionAccepted,
  suggestionRejected,
  appointmentCancelled,
  ministryAutoConfirmed,
}

extension AppointmentTypeX on AppointmentType {
  String toDb() => switch (this) {
        AppointmentType.ministry => 'ministry',
        AppointmentType.patient => 'patient',
        AppointmentType.external_ => 'external',
      };

  static AppointmentType fromDb(String v) => switch (v) {
        'ministry' => AppointmentType.ministry,
        'patient' => AppointmentType.patient,
        'external' => AppointmentType.external_,
        _ => throw ArgumentError('Unknown AppointmentType: $v'),
      };
}

extension AppointmentStatusX on AppointmentStatus {
  String toDb() => name;

  static AppointmentStatus fromDb(String v) =>
      AppointmentStatus.values.firstWhere((e) => e.name == v);
}

extension NotificationTypeX on NotificationType {
  String toDb() => switch (this) {
        NotificationType.newAppointment => 'new_appointment',
        NotificationType.appointmentConfirmed => 'appointment_confirmed',
        NotificationType.appointmentRejected => 'appointment_rejected',
        NotificationType.alternativeSuggested => 'alternative_suggested',
        NotificationType.suggestionAccepted => 'suggestion_accepted',
        NotificationType.suggestionRejected => 'suggestion_rejected',
        NotificationType.appointmentCancelled => 'appointment_cancelled',
        NotificationType.ministryAutoConfirmed => 'ministry_auto_confirmed',
      };

  static NotificationType fromDb(String v) => switch (v) {
        'new_appointment' => NotificationType.newAppointment,
        'appointment_confirmed' => NotificationType.appointmentConfirmed,
        'appointment_rejected' => NotificationType.appointmentRejected,
        'alternative_suggested' => NotificationType.alternativeSuggested,
        'suggestion_accepted' => NotificationType.suggestionAccepted,
        'suggestion_rejected' => NotificationType.suggestionRejected,
        'appointment_cancelled' => NotificationType.appointmentCancelled,
        'ministry_auto_confirmed' => NotificationType.ministryAutoConfirmed,
        _ => throw ArgumentError('Unknown NotificationType: $v'),
      };
}
