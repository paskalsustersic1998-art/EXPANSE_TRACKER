class ParticipantModel {
  final int id;
  final String email;

  const ParticipantModel({required this.id, required this.email});

  factory ParticipantModel.fromJson(Map<String, dynamic> json) {
    return ParticipantModel(
      id: json['id'] as int,
      email: json['email'] as String,
    );
  }
}

class TripModel {
  final int id;
  final String name;
  final String? description;
  final int createdBy;
  final DateTime createdAt;
  final List<ParticipantModel> participants;

  const TripModel({
    required this.id,
    required this.name,
    this.description,
    required this.createdBy,
    required this.createdAt,
    required this.participants,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdBy: json['created_by'] as int,
      createdAt: DateTime.parse(json['created_at'] as String),
      participants: (json['participants'] as List<dynamic>)
          .map((p) => ParticipantModel.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }
}
