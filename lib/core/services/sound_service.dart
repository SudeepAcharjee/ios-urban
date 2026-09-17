import 'package:flutter/foundation.dart';

class SoundService {
  // static final AudioPlayer _player = AudioPlayer();
  static bool _isInitialized = false;

  static void initialize() {
    if (_isInitialized) return;
    try {
      /*
      _player.setAudioContext(
        ...
      );
      */
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing SoundService: $e');
    }
  }

  /// Plays the urgent tone sound loop for new booking notifications
  static Future<void> playBookingAlertSound() async {
    try {
      initialize();
      /*
      await _player.stop();
      _player.audioCache.prefix = '';
      await _player.play(AssetSource('images/sound/mixkit-urgent-simple-tone-loop-2976.wav'));
      */
      debugPrint('Booking alert sound requested, but sound is currently disabled.');
    } catch (e) {
      debugPrint('Error playing booking alert sound: $e');
    }
  }

  /// Stops any currently playing alert sound
  static Future<void> stopSound() async {
    try {
      // await _player.stop();
      debugPrint('Stop sound requested, but sound is currently disabled.');
    } catch (e) {
      debugPrint('Error stopping sound: $e');
    }
  }
}
