import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

import 'analytics_service.dart';
import 'firebase_service.dart';

enum MediaFolder { photos, voice, bills }

class MediaService {
  MediaService(this.firebase, this.analytics);

  final FirebaseService firebase;
  final AnalyticsService analytics;
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickPhoto({ImageSource source = ImageSource.camera}) async {
    await Permission.camera.request();
    return _picker.pickImage(source: source, imageQuality: 78, maxWidth: 1600);
  }

  Future<String> uploadFarmFile({
    required String farmerId,
    required String farmId,
    required XFile file,
    required MediaFolder folder,
  }) async {
    final extension = p.extension(file.path).replaceAll('.', '');
    final name = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final path = 'users/$farmerId/farms/$farmId/${folder.name}/$name';
    final ref = firebase.storage.ref(path);
    final task = await ref.putFile(
      File(file.path),
      SettableMetadata(
        customMetadata: {
          'farmerId': farmerId,
          'farmId': farmId,
          'folder': folder.name,
        },
      ),
    );
    final url = await task.ref.getDownloadURL();
    if (folder == MediaFolder.photos) {
      await analytics.logEvent('photo_uploaded', farmerId: farmerId);
      await analytics.incrementGlobal('totalUploadedPhotos');
    }
    return url;
  }

  Reference farmFolder(String farmerId, String farmId, MediaFolder folder) {
    return firebase.storage.ref('users/$farmerId/farms/$farmId/${folder.name}');
  }
}
