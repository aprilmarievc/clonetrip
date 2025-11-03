import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class FlightStatus {
  FlightStatus({this.departIso, this.arriveIso, this.status});

  final String? departIso; // ISO8601 (YYYY-MM-DDTHH:MM:SS)
  final String? arriveIso; // ISO8601 (YYYY-MM-DDTHH:MM:SS)
  final String? status; // e.g., scheduled, delayed
}

// Configure your deployed Functions base URL, e.g.:
// const String _functionsBase = 'https://us-central1-YOUR_PROJECT.cloudfunctions.net';
const String _functionsBase = '';

class FlightStatusService {
  static Future<FlightStatus?> fetch({
    required String flightNumber,
    required String dateYmd, // YYYY-MM-DD (local date)
  }) async {
    if (_functionsBase.isEmpty) {
      // Not configured; no-op.
      debugPrint('FlightStatusService: functions base URL not set.');
      return null;
    }
    final uri = Uri.parse('$_functionsBase/flightStatus')
        .replace(queryParameters: {
      'flight': flightNumber,
      'date': dateYmd,
    });
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final data = json.decode(res.body) as Map<String, dynamic>;
      return FlightStatus(
        departIso: data['departIso'] as String?,
        arriveIso: data['arriveIso'] as String?,
        status: data['status'] as String?,
      );
    } catch (e) {
      debugPrint('FlightStatusService error: $e');
      return null;
    }
  }
}


