import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'gemini_service.dart';
import 'openai_service.dart';

class SpeechService extends ChangeNotifier {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final AudioRecorder _audioRecorder = AudioRecorder();
  
  bool _isAvailable = false;
  bool _isListening = false;
  String _lastWords = "";
  double _confidence = 1.0;
  
  String? _recordingPath;
  bool _recordAudioActive = false;
  Function(String text, double confidence, bool isFinal)? _activeOnResult;
  String? _currentLanguageCode;

  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  double get confidence => _confidence;

  /// Initializes speech recognition
  Future<bool> initSpeech() async {
    try {
      if (kIsWeb) {
        _isAvailable = false;
        return false;
      }
      
      // Request mic permission
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }

      if (status.isGranted) {
        // Initialize native speech to text engine with fallback safety
        try {
          _isAvailable = await _speech.initialize(
            onError: (val) => debugPrint("SpeechService: Native STT error $val"),
            onStatus: (val) => debugPrint("SpeechService: Native STT status $val"),
          );
        } catch (e_init) {
          debugPrint("SpeechService: Native STT initialize exception: $e_init");
          _isAvailable = false;
        }
        debugPrint("SpeechService: Native STT initialization status: $_isAvailable");
      } else {
        _isAvailable = false;
      }
      return status.isGranted;
    } catch (e) {
      _isAvailable = false;
      return false;
    }
  }

  /// Starts listening for speech in preferred language
  Future<void> startListening({
    required String languageCode,
    required Function(String text, double confidence, bool isFinal) onResult,
    required Function() onTimeout,
    bool recordAudio = true,
  }) async {
    _lastWords = "";
    _activeOnResult = onResult;
    _currentLanguageCode = languageCode;
    notifyListeners();

    if (!_isAvailable) {
      _isListening = true;
      notifyListeners();

      if (recordAudio) {
        try {
          if (await _audioRecorder.hasPermission()) {
            final directory = await getTemporaryDirectory();
            _recordingPath = '${directory.path}/speech_temp_${const Uuid().v4()}.m4a';
            
            await _audioRecorder.start(
              const RecordConfig(encoder: AudioEncoder.aacLc),
              path: _recordingPath!,
            );
            _recordAudioActive = true;
            debugPrint("SpeechService: Started recording for Gemini transcription at $_recordingPath");
          }
        } catch (e) {
          debugPrint("SpeechService: Failed to start audio recording: $e");
          _recordAudioActive = false;
        }
      }
      return;
    }

    _isListening = true;
    _recordAudioActive = false;
    notifyListeners();

    // Map locale identifier (e.g. kn-IN -> kn_IN)
    final formattedLocale = languageCode.replaceAll('-', '_');

    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          localeId: formattedLocale,
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
        ),
        onResult: (result) {
          _lastWords = result.recognizedWords;
          _confidence = result.confidence;
          if (result.finalResult) {
            _isListening = false;
          }
          notifyListeners();
          onResult(_lastWords, _confidence, result.finalResult);
        },
      );
    } catch (e_listen) {
      debugPrint("SpeechService: Native listen failed: $e_listen. Falling back to recording.");
      _isAvailable = false;
      _isListening = false;
      notifyListeners();
      // Retry in fallback mode
      await startListening(
        languageCode: languageCode,
        onResult: onResult,
        onTimeout: onTimeout,
        recordAudio: recordAudio,
      );
    }
  }

  /// Manually stops listening and returns final transcribed text
  Future<String> stopListening() async {
    if (_isListening) {
      if (_recordAudioActive && _recordingPath != null) {
        try {
          final path = await _audioRecorder.stop();
          _recordAudioActive = false;
          
          if (path != null) {
            debugPrint("SpeechService: Stopped recording. Transcribing file: $path");
            final text = await OpenAiService.transcribeAudio(path, languageCode: _currentLanguageCode);
            if (text.isNotEmpty) {
              _lastWords = text;
              _confidence = 0.99;
              notifyListeners();
              if (_activeOnResult != null) {
                _activeOnResult!(_lastWords, _confidence, true);
              }
            }
            // Clean up temp file
            final file = File(path);
            if (await file.exists()) {
              await file.delete();
            }
          }
        } catch (e) {
          debugPrint("SpeechService: Error stopping recording or transcribing: $e");
        }
      } else if (_isAvailable) {
        await _speech.stop();
        // Wait up to 600ms for native finalResult callback to update _lastWords
        int elapsed = 0;
        while (_isListening && elapsed < 600) {
          await Future.delayed(const Duration(milliseconds: 50));
          elapsed += 50;
        }
      }

      _isListening = false;
      notifyListeners();
    }
    return _lastWords;
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }
}
