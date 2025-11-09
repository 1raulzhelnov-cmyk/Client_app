import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_places_flutter/model/prediction.dart';
import 'package:http/http.dart' as http;

class MapsService {
  MapsService({
    required this.apiKey,
    http.Client? httpClient,
  }) : _client = httpClient ?? http.Client();

  final String apiKey;
  final http.Client _client;

  Future<List<Prediction>> autocomplete(String input) async {
    final query = input.trim();
    if (query.length < 3 || !_hasValidKey) {
      return const [];
    }
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        <String, String>{
          'input': query,
          'language': 'ru',
          'components': 'country:ru',
          'key': apiKey,
        },
      );
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return const [];
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final predictions = decoded['predictions'] as List<dynamic>? ?? const [];
      return predictions
          .whereType<Map<String, dynamic>>()
          .map(Prediction.fromJson)
          .toList();
    } catch (error, stackTrace) {
      debugPrint('Maps autocomplete error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  Future<LatLng?> getDetails(String placeId) async {
    if (placeId.isEmpty || !_hasValidKey) {
      return null;
    }
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/details/json',
        <String, String>{
          'place_id': placeId,
          'language': 'ru',
          'fields': 'geometry/location,formatted_address',
          'key': apiKey,
        },
      );
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return null;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final result = decoded['result'] as Map<String, dynamic>? ?? const {};
      final geometry =
          result['geometry'] as Map<String, dynamic>? ?? const {};
      final location =
          geometry['location'] as Map<String, dynamic>? ?? const {};
      final lat = location['lat'] as num?;
      final lng = location['lng'] as num?;
      if (lat == null || lng == null) {
        return null;
      }
      return LatLng(lat.toDouble(), lng.toDouble());
    } catch (error, stackTrace) {
      debugPrint('Maps details error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }

  bool get _hasValidKey => apiKey.trim().isNotEmpty;
}
