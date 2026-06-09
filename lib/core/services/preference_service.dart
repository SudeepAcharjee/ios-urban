import 'package:shared_preferences/shared_preferences.dart';

class PreferenceService {
  static const String _keyLocation = 'last_location';
  static const String _keyLatitude = 'last_latitude';
  static const String _keyLongitude = 'last_longitude';

  static const String _keyOnboardingComplete = 'onboarding_complete';

  // Save location data
  static Future<void> saveLocation(String address, double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocation, address);
    await prefs.setDouble(_keyLatitude, lat);
    await prefs.setDouble(_keyLongitude, lng);
  }

  // Get last saved address
  static Future<String?> getSavedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLocation);
  }

  // Get last saved coordinates
  static Future<Map<String, double>?> getSavedCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyLatitude);
    final lng = prefs.getDouble(_keyLongitude);
    
    if (lat != null && lng != null) {
      return {'latitude': lat, 'longitude': lng};
    }
    return null;
  }

  // Onboarding Status
  static Future<void> setOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingComplete, true);
  }

  static Future<bool> isOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  // Clear saved data
  static Future<void> clearLocation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLocation);
    await prefs.remove(_keyLatitude);
    await prefs.remove(_keyLongitude);
  }
}
