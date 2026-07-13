import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class StorageService extends ChangeNotifier {
  bool _useMock = true;

  bool get useMock => _useMock;

  void setMockMode(bool val) {
    _useMock = val;
    notifyListeners();
  }

  /// Saves a crop photo or bill file to the local app documents directory.
  /// Returns the absolute local file path.
  Future<String> uploadFile({
    required File file,
    required String farmerId,
    required String farmId,
    required String category, // "diary" | "bills"
    required String entryOrBillId,
    required String fileName,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localFolder = Directory('${appDir.path}/$category/$entryOrBillId');
      if (!await localFolder.exists()) {
        await localFolder.create(recursive: true);
      }
      final savedFile = await file.copy('${localFolder.path}/$fileName');
      debugPrint("StorageService: Saved file locally to ${savedFile.path}");
      return savedFile.path;
    } catch (e) {
      debugPrint("StorageService: Failed to save file locally: $e");
      // Fallback to the original file path if copy fails
      return file.path;
    }
  }

  /// Saves voice notes audio file locally.
  Future<String> uploadAudio({
    required File file,
    required String farmerId,
    required String farmId,
    required String entryId,
    required String audioName,
  }) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localFolder = Directory('${appDir.path}/voice/$entryId');
      if (!await localFolder.exists()) {
        await localFolder.create(recursive: true);
      }
      final savedFile = await file.copy('${localFolder.path}/$audioName');
      debugPrint("StorageService: Saved audio locally to ${savedFile.path}");
      return savedFile.path;
    } catch (e) {
      debugPrint("StorageService: Failed to save audio locally: $e");
      return file.path;
    }
  }
}
