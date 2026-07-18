import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  /// Prompts for permissions, fetches current location, and updates both the user's profile
  /// and all their crop records (plots) in Firestore with the precise GPS coordinates.
  static Future<void> checkAndSaveLocation(String farmerId) async {
    if (farmerId.isEmpty) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("LocationService: Location services are disabled.");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("LocationService: Location permissions denied.");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("LocationService: Location permissions are permanently denied.");
        return;
      }

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
