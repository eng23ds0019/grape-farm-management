import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  /// Prompts for permissions, fetches current location, and updates both the user's profile
  /// and all their crop records (plots) in Firestore with the precise GPS coordinates.
  static Future<void> checkAndSaveLocation(String farmerId) async {
    debugPrint("LocationService: checkAndSaveLocation called for farmerId: $farmerId");
    if (farmerId.isEmpty) return;

    try {
      // 1. Request/Check Permissions FIRST so user gets prompted
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint("LocationService: Current permission status: $permission");
      
      if (permission == LocationPermission.denied) {
        debugPrint("LocationService: Requesting location permission...");
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("LocationService: Location permissions denied by user.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("LocationService: Location permissions are permanently denied.");
        return;
      }

      debugPrint("LocationService: Permission granted. Checking if GPS/Location services are enabled globally...");
      
      // 2. Now check if GPS is toggled on globally
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint("LocationService: Location services enabled status: $serviceEnabled");
      if (!serviceEnabled) {
        debugPrint("LocationService: GPS is turned off globally. Prompting user to enable it.");
        // Open device settings so user can toggle GPS on
        await Geolocator.openLocationSettings();
        return;
      }

      debugPrint("LocationService: Getting current position...");
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      debugPrint("LocationService: Successfully retrieved location: (${position.latitude}, ${position.longitude})");

      // Save to Firebase Firestore under the user profile
      final db = FirebaseFirestore.instance;
      await db.collection('users').doc(farmerId).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'location': "${position.latitude},${position.longitude}",
      });
      debugPrint("LocationService: Saved GPS coordinates to user profile.");

      // Also save to all crop records (plots) to ensure the disease engine gets it
      final plotsSnap = await db.collection('users').doc(farmerId).collection('cropRecords').get();
      for (final doc in plotsSnap.docs) {
        await doc.reference.update({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'location': "${position.latitude},${position.longitude}",
        });
      }
      debugPrint("LocationService: Saved GPS coordinates to ${plotsSnap.docs.length} crop records (plots).");

    } catch (e) {
      debugPrint("LocationService: Error checking or saving location: $e");
    }
  }
}
