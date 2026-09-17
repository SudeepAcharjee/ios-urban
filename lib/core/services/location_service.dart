import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw 'Location services are disabled. Please enable them and click the button again.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied, we cannot request permissions.';
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  static Future<String?> getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        final parts = [
          place.name,
          place.subLocality,
          place.locality,
          place.postalCode
        ].where((part) => part != null && part.isNotEmpty).toList();
        
        return parts.join(", ");
      }
      return null;
    } catch (e) {
      print('Geocoding Error: $e');
      return null;
    }
  }

  static Future<String?> getAddressFromCoordinates(double latitude, double longitude) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        final parts = [
          place.name,
          place.subLocality,
          place.locality,
          place.postalCode
        ].where((part) => part != null && part.isNotEmpty).toList();
        
        return parts.join(", ");
      }
      return null;
    } catch (e) {
      print('Geocoding Error: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    try {
      if (query.trim().isEmpty) return [];
      List<Location> locations = await locationFromAddress(query);
      List<Map<String, dynamic>> results = [];
      for (var loc in locations.take(5)) {
        try {
          List<Placemark> placemarks = await placemarkFromCoordinates(
            loc.latitude,
            loc.longitude,
          );
          if (placemarks.isNotEmpty) {
            Placemark place = placemarks[0];
            final addressParts = [
              place.name,
              place.subLocality,
              place.locality,
              place.administrativeArea,
              place.postalCode,
              place.country
            ].where((part) => part != null && part.isNotEmpty).toSet().toList();
            
            results.add({
              'displayAddress': addressParts.join(", "),
              'latitude': loc.latitude,
              'longitude': loc.longitude,
              'houseNumber': place.name ?? '',
              'address': [place.street, place.subLocality].where((e) => e != null && e.isNotEmpty).join(", "),
              'city': place.locality ?? '',
              'state': place.administrativeArea ?? '',
              'zip': place.postalCode ?? '',
            });
          }
        } catch (_) {
          // Individual reverse geocode error
        }
      }
      return results;
    } catch (e) {
      print('Search Geocoding Error: $e');
      return [];
    }
  }
}

