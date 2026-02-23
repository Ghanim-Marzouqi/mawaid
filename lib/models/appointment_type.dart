class AppointmentTypeModel {
  final String id;
  final String name;
  final int colorIndex;
  final String createdBy;
  final DateTime createdAt;

  const AppointmentTypeModel({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.createdBy,
    required this.createdAt,
  });

  factory AppointmentTypeModel.fromJson(Map<String, dynamic> json) =>
      AppointmentTypeModel(
        id: json['id'],
        name: json['name'],
        colorIndex: json['color_index'] ?? 0,
        createdBy: json['created_by'],
        createdAt: DateTime.parse(json['created_at']),
      );

  Map<String, dynamic> toJsonForInsert() => {
        'name': name,
        'color_index': colorIndex,
      };
}
