class AppNotification {
  final String id;
  final String recipientId;
  final String type;
  final String title;
  final String body;
  final String? appointmentId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.body,
    this.appointmentId,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'],
        recipientId: json['recipient_id'],
        type: json['type'],
        title: json['title'],
        body: json['body'],
        appointmentId: json['appointment_id'],
        isRead: json['is_read'],
        createdAt: DateTime.parse(json['created_at']),
      );
}
