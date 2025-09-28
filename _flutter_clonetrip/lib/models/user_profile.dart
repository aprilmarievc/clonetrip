class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.countryCode,
    this.nextDestination,
    this.recentTrip,
  });

  final String id;
  final String displayName;
  final String countryCode;
  final String? nextDestination;
  final String? recentTrip;

  factory UserProfile.fromMap(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      displayName: data['displayName'] as String? ?? 'Traveler',
      countryCode: data['countryCode'] as String? ?? 'US',
      nextDestination: data['nextDestination'] as String?,
      recentTrip: data['recentTrip'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'countryCode': countryCode,
      if (nextDestination != null) 'nextDestination': nextDestination,
      if (recentTrip != null) 'recentTrip': recentTrip,
    };
  }
}
