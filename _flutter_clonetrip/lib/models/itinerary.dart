class Itinerary {
  const Itinerary({
    required this.id,
    required this.userId,
    required this.title,
    required this.countryCode,
    this.startDateIso,
    this.endDateIso,
    this.isWishlist = false,
    this.cities = const <String>[],
    this.photoUrls = const <String>[],
    this.totalBudget,
    this.transports = const <Map<String, dynamic>>[],
    this.stays = const <Map<String, dynamic>>[],
    this.activities = const <Map<String, dynamic>>[],
    this.notificationRules = const <Map<String, dynamic>>[],
    this.weatherEnabled = false,
    this.weatherUnits = 'metric',
  });

  final String id;
  final String userId;
  final String title;
  final String countryCode;
  final String? startDateIso;
  final String? endDateIso;
  final bool isWishlist;

  // New optional fields for richer planning
  final List<String> cities; // ordered list of city/stops
  final List<String> photoUrls; // gallery
  final double? totalBudget; // optional trip budget total

  // Sectional data stored as serializable maps
  final List<Map<String, dynamic>> transports; // flights/trains/cars
  final List<Map<String, dynamic>> stays; // hotels/airbnbs/family
  final List<Map<String, dynamic>> activities; // must-dos, wishlists
  final List<Map<String, dynamic>> notificationRules; // local/email/sms rules
  final bool weatherEnabled; // show weather per city/date
  final String weatherUnits; // 'metric' | 'imperial'

  factory Itinerary.fromMap(String id, Map<String, dynamic> data) {
    List<dynamic> list(dynamic v) => (v as List?) ?? const <dynamic>[];
    return Itinerary(
      id: id,
      userId: data['userId'] as String? ?? '',
      title: data['title'] as String? ?? 'Trip',
      countryCode: data['countryCode'] as String? ?? 'US',
      startDateIso: data['startDateIso'] as String?,
      endDateIso: data['endDateIso'] as String?,
      isWishlist: data['isWishlist'] as bool? ?? false,
      cities: list(data['cities']).cast<String>(),
      photoUrls: list(data['photoUrls']).cast<String>(),
      totalBudget: (data['totalBudget'] as num?)?.toDouble(),
      transports: list(
        data['transports'],
      ).map((e) => (e as Map).cast<String, dynamic>()).toList(),
      stays: list(
        data['stays'],
      ).map((e) => (e as Map).cast<String, dynamic>()).toList(),
      activities: list(
        data['activities'],
      ).map((e) => (e as Map).cast<String, dynamic>()).toList(),
      notificationRules: list(
        data['notificationRules'],
      ).map((e) => (e as Map).cast<String, dynamic>()).toList(),
      weatherEnabled: data['weatherEnabled'] as bool? ?? false,
      weatherUnits: data['weatherUnits'] as String? ?? 'metric',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'countryCode': countryCode,
      if (startDateIso != null) 'startDateIso': startDateIso,
      if (endDateIso != null) 'endDateIso': endDateIso,
      'isWishlist': isWishlist,
      if (cities.isNotEmpty) 'cities': cities,
      if (photoUrls.isNotEmpty) 'photoUrls': photoUrls,
      if (totalBudget != null) 'totalBudget': totalBudget,
      if (transports.isNotEmpty) 'transports': transports,
      if (stays.isNotEmpty) 'stays': stays,
      if (activities.isNotEmpty) 'activities': activities,
      if (notificationRules.isNotEmpty) 'notificationRules': notificationRules,
      'weatherEnabled': weatherEnabled,
      'weatherUnits': weatherUnits,
    };
  }
}
