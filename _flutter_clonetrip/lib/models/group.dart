class GroupModel {
  const GroupModel({
    required this.id,
    required this.name,
    required this.memberUserIds,
    required this.itineraryIds,
  });

  final String id;
  final String name;
  final List<String> memberUserIds;
  final List<String> itineraryIds;

  factory GroupModel.fromMap(String id, Map<String, dynamic> data) {
    return GroupModel(
      id: id,
      name: data['name'] as String? ?? 'Group',
      memberUserIds:
          (data['memberUserIds'] as List?)?.cast<String>() ?? const [],
      itineraryIds: (data['itineraryIds'] as List?)?.cast<String>() ?? const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'memberUserIds': memberUserIds,
      'itineraryIds': itineraryIds,
    };
  }
}
