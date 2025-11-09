import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';

class MapsService {
  MapsService({
    required GooglePlace googlePlace,
  }) : _googlePlace = googlePlace;

  final GooglePlace _googlePlace;

  Future<List<AutocompletePrediction>> autocomplete(String input) async {
    final query = input.trim();
    if (query.length < 3) {
      return const [];
    }
    try {
      final response = await _googlePlace.autocomplete.get(
        query,
        language: 'ru',
        components: [Component('country', 'ru')],
      );
      return response?.predictions ?? const [];
    } catch (error, stackTrace) {
      debugPrint('Maps autocomplete error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return const [];
    }
  }

  Future<LatLng?> getDetails(String placeId) async {
    if (placeId.isEmpty) {
      return null;
    }
    try {
      final response = await _googlePlace.details.get(
        placeId,
        language: 'ru',
        fields: 'geometry/location,formatted_address',
      );
      final location = response?.result?.geometry?.location;
      final lat = location?.lat;
      final lng = location?.lng;
      if (lat == null || lng == null) {
        return null;
      }
      return LatLng(lat, lng);
    } catch (error, stackTrace) {
      debugPrint('Maps details error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    }
  }
}
