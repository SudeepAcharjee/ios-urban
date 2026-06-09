import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';

final userLocationProvider = FutureProvider<Position?>((ref) async {
  try {
    return await LocationService.getCurrentPosition();
  } catch (e) {
    print('Error getting user location: $e');
    return null;
  }
});
