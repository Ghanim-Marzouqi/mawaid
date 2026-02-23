enum UserRole { coordinator, manager }

enum AppointmentStatus { pending, confirmed, rejected, suggested, cancelled, draft }

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
