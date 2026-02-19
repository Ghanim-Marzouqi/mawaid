class Profile {
  final String id;
  final String role;
  final String fullName;
  final String? pushToken;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.role,
    required this.fullName,
    this.pushToken,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'],
        role: json['role'],
        fullName: json['full_name'],
        pushToken: json['push_token'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
      );
}
