import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'manual_location_screen.dart';
import 'notification_request_screen.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/custom_toast.dart';
import '../../../core/services/preference_service.dart';

class LocationRequestScreen extends ConsumerStatefulWidget {
  const LocationRequestScreen({super.key});

  @override
  ConsumerState<LocationRequestScreen> createState() => _LocationRequestScreenState();
}

class _LocationRequestScreenState extends ConsumerState<LocationRequestScreen> {
  String? _fetchedAddress;
  bool _isAllowing = false;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2029C5);
    final Size size = MediaQuery.of(context).size;
    final double hScale = size.height / 812.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              // Location Illustration
              Container(
                width: 180 * hScale.clamp(0.8, 1.2),
                height: 180 * hScale.clamp(0.8, 1.2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.location_on,
                    size: 80 * hScale.clamp(0.8, 1.2),
                    color: primaryColor,
                  ),
                ),
              ),
              
              SizedBox(height: 50 * hScale),
              
              Text(
                'What is Your Location?',
                style: TextStyle(
                  fontSize: 26 * hScale.clamp(0.9, 1.1),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              
              SizedBox(height: 15 * hScale),
              
              if (_fetchedAddress != null)
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: primaryColor.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.my_location, color: primaryColor, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _fetchedAddress!,
                          style: TextStyle(
                            fontSize: 14 * hScale.clamp(0.9, 1.1),
                            color: const Color(0xFF374151),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  'To Find Nearby Service Provider.',
                  style: TextStyle(
                    fontSize: 16 * hScale.clamp(0.9, 1.1),
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: (_isAllowing || ref.watch(authViewModelProvider).isLoading)
                    ? null
                    : () async {
                        if (_fetchedAddress != null) {
                          // Already fetched, navigate to next
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const NotificationRequestScreen()),
                          );
                          return;
                        }

                        try {
                          setState(() => _isAllowing = true);
                          
                          // 1. Get Coordinates
                          final Position? position = await LocationService.getCurrentPosition();
                          if (position == null) {
                            if (mounted) {
                              CustomToast.error(context, 'Could not get location');
                              setState(() => _isAllowing = false);
                            }
                            return;
                          }

                          // 2. Get Readable Address
                          final String? address = await LocationService.getAddressFromLatLng(position);
                          final String finalAddress = address ?? 'Unknown Address';

                          // 3. Save to Firestore
                          await ref.read(authViewModelProvider.notifier).updateProfile({
                            'location': finalAddress,
                            'latitude': position.latitude,
                            'longitude': position.longitude,
                          });
                          
                          // 4. Save to Local Preferences
                          await PreferenceService.saveLocation(
                            finalAddress,
                            position.latitude,
                            position.longitude,
                          );
                          
                          if (mounted) {
                            setState(() {
                              _fetchedAddress = finalAddress;
                              _isAllowing = false;
                            });
                            CustomToast.success(context, 'Location updated successfully!');
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _isAllowing = false);
                            CustomToast.error(context, e.toString());
                          }
                        }
                      },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: primaryColor.withOpacity(0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: (_isAllowing || ref.watch(authViewModelProvider).isLoading)
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'Allowing...',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : Text(
                        _fetchedAddress != null ? 'Next' : 'Allow Location Access',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
              
              const SizedBox(height: 15),
              
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManualLocationScreen()),
                  );
                },
                child: Text(
                  'Enter Location Manually',
                  style: TextStyle(
                    fontSize: 16 * hScale.clamp(0.9, 1.1),
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
