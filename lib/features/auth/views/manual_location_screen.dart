import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:toastification/toastification.dart';
import 'notification_request_screen.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../../../core/services/location_service.dart';
import '../../../core/utils/custom_toast.dart';

class ManualLocationScreen extends ConsumerWidget {
  const ManualLocationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const primaryColor = Color(0xFF2029C5);
    final Size size = MediaQuery.of(context).size;
    final double hScale = size.height / 812.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Enter Your Location',
          style: TextStyle(
            color: Colors.black, 
            fontSize: 18 * hScale.clamp(0.9, 1.1), 
            fontWeight: FontWeight.bold
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8 * hScale.clamp(0.8, 1.2)),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Icon(Icons.arrow_back, color: Colors.black, size: 20 * hScale.clamp(0.8, 1.2)),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(25.0 * hScale.clamp(0.8, 1.2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TextField(
                style: TextStyle(fontSize: 16 * hScale.clamp(0.9, 1.1)),
                decoration: InputDecoration(
                  hintText: 'Golden Avenue',
                  hintStyle: TextStyle(color: const Color(0xFF1A1A1A), fontSize: 16 * hScale.clamp(0.9, 1.1)),
                  prefixIcon: Icon(Icons.search, color: const Color(0xFF1A1A1A), size: 24 * hScale.clamp(0.8, 1.2)),
                  suffixIcon: Icon(Icons.cancel, color: primaryColor, size: 20 * hScale.clamp(0.8, 1.2)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 15 * hScale.clamp(0.8, 1.2)),
                ),
              ),
            ),
            
            SizedBox(height: 25 * hScale),
            
            // Use current location
            GestureDetector(
              onTap: () async {
                try {
                  CustomToast.show(context: context, message: 'Fetching location...', type: ToastificationType.info);
                  
                  final Position? position = await LocationService.getCurrentPosition();
                  if (position == null) return;

                  final String? address = await LocationService.getAddressFromLatLng(position);

                  await ref.read(authViewModelProvider.notifier).updateProfile({
                    'location': address ?? 'Current Location',
                    'latitude': position.latitude,
                    'longitude': position.longitude,
                  });
                  
                  if (context.mounted) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const NotificationRequestScreen()),
                    );
                  }
                } catch (e) {
                  if (context.mounted) CustomToast.error(context, e.toString());
                }
              },
              child: Row(
                children: [
                  Icon(Icons.near_me, color: primaryColor, size: 24 * hScale.clamp(0.8, 1.2)),
                  SizedBox(width: 12 * hScale),
                  Text(
                    'Use my current location',
                    style: TextStyle(
                      fontSize: 16 * hScale.clamp(0.9, 1.1),
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 30 * hScale),
            const Divider(),
            SizedBox(height: 20 * hScale),
            
            Text(
              'SEARCH RESULT',
              style: TextStyle(
                fontSize: 12 * hScale.clamp(0.9, 1.1),
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade400,
                letterSpacing: 1.2,
              ),
            ),
            
            SizedBox(height: 20 * hScale),
            
            // Search result item
            _buildResultItem(
              context,
              ref,
              title: 'Golden Avenue',
              subtitle: '8502 Preston Rd. Ingl..',
              hScale: hScale,
              primaryColor: primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultItem(BuildContext context, WidgetRef ref, {required String title, required String subtitle, required double hScale, required Color primaryColor}) {
    return GestureDetector(
      onTap: () async {
        try {
          await ref.read(authViewModelProvider.notifier).updateProfile({
            'location': '$title, $subtitle',
            'manualEntry': true,
          });
          
          CustomToast.success(context, 'Location set successfully!');
          
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const NotificationRequestScreen()),
            );
          }
        } catch (e) {
          if (context.mounted) CustomToast.error(context, e.toString());
        }
      },
      child: Row(
        children: [
          Icon(Icons.location_on, color: primaryColor, size: 24 * hScale.clamp(0.8, 1.2)),
          SizedBox(width: 15 * hScale),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16 * hScale.clamp(0.9, 1.1),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              SizedBox(height: 4 * hScale),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14 * hScale.clamp(0.9, 1.1),
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
