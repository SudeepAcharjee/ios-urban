import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/providers/location_provider.dart';
import '../models/service_model.dart';

final servicesProvider = StreamProvider<List<ServiceModel>>((ref) async* {
  Position? userLocation;
  try {
    userLocation = await ref.watch(userLocationProvider.future);
  } catch (e) {
    userLocation = null;
  }

  yield* FirebaseFirestore.instance
      .collection('services')
      .snapshots()
      .map((snapshot) {
    final allServices = snapshot.docs
        .map((doc) => ServiceModel.fromFirestore(doc))
        .toList();

    if (userLocation == null) {
      return allServices;
    }

    return allServices.where((service) {
      // If admin hasn't set location/radius, show it to everyone
      if (service.latitude == null || service.longitude == null || service.radius == null) {
        return true;
      }

      final double distanceInMeters = Geolocator.distanceBetween(
        userLocation!.latitude,
        userLocation.longitude,
        service.latitude!,
        service.longitude!,
      );

      final double distanceInKm = distanceInMeters / 1000;
      return distanceInKm <= service.radius!;
    }).toList();
  });
});

final servicesByCategoryProvider = StreamProvider.family<List<ServiceModel>, String>((ref, category) async* {
  Position? userLocation;
  try {
    userLocation = await ref.watch(userLocationProvider.future);
  } catch (e) {
    userLocation = null;
  }

  yield* FirebaseFirestore.instance
      .collection('services')
      .snapshots()
      .map((snapshot) {
    final allServices = snapshot.docs
        .map((doc) => ServiceModel.fromFirestore(doc))
        .toList();

    // Filter by category in-memory to handle variations (e.g. AC vs AC Repair)
    final categoryLower = category.trim().toLowerCase();
    final filteredByCategory = allServices.where((service) {
      final serviceCatLower = service.category.trim().toLowerCase();
      return serviceCatLower == categoryLower ||
             serviceCatLower.contains(categoryLower) ||
             categoryLower.contains(serviceCatLower) ||
             (serviceCatLower.contains('ac') && categoryLower.contains('ac'));
    }).toList();

    if (userLocation == null) {
      return filteredByCategory;
    }

    return filteredByCategory.where((service) {
      if (service.latitude == null || service.longitude == null || service.radius == null) {
        return true;
      }

      final double distanceInMeters = Geolocator.distanceBetween(
        userLocation!.latitude,
        userLocation.longitude,
        service.latitude!,
        service.longitude!,
      );

      final double distanceInKm = distanceInMeters / 1000;
      return distanceInKm <= service.radius!;
    }).toList();
  });
});
