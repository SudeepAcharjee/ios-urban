import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../../features/auth/viewmodels/auth_viewmodel.dart';

final userLocationProvider = FutureProvider<Position?>((ref) async {
  // Watch user profile for custom location coordinates
  final userData = ref.watch(userDataProvider).value;
  if (userData != null && userData['latitude'] != null && userData['longitude'] != null) {
    return Position(
      latitude: (userData['latitude'] as num).toDouble(),
      longitude: (userData['longitude'] as num).toDouble(),
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }

  try {
    return await LocationService.getCurrentPosition();
  } catch (e) {
    print('Error getting user location: $e');
    return null;
  }
});
