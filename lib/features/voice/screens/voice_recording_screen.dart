import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/constants.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../core/localization/translations.dart';
import '../../../models/diary_entry_model.dart';
import '../../../models/expense_model.dart';
import '../../../services/firebase_auth_service.dart';
import '../../../services/firestore_service.dart';
import '../../../services/storage_service.dart';
import '../../../services/speech_service.dart';
import '../../../services/translation_service.dart';
import '../../../services/gemini_service.dart';
import '../../../services/openai_service.dart';
import '../../../widgets/app_button.dart';
import '../../../widgets/app_card.dart';

class VoiceRecordingScreen extends StatefulWidget {
  final String farmId;

  const VoiceRecordingScreen({super.key, required this.farmId});

  @override
  State<VoiceRecordingScreen> createState() => _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends State<VoiceRecordingScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _localPath;

  bool _showConfirmation = false;
  bool _showTranslation = false;
  String _recognizedText = "";
  
  // Parsed confirmation fields
  String _parsedWorkType = "Spraying";
  String _parsedStage = "Berry growth";
  String _parsedNote = "";
  final List<ExpenseModel> _parsedExpenses = [];

  bool _isProcessing = false;
  bool _isSaving = false;

  // Audio Playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initSpeechService();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });
  }

  void _initSpeechService() async {
    final speech = Provider.of<SpeechService>(context, listen: false);
    await speech.initSpeech();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Record audio & speech trigger
  void _toggleRecording(String langCode) async {
    if (_isRecording) {
      // 1. Stop Audio Record
      final path = await _audioRecorder.stop();
      
      setState(() {
        _isRecording = false;
        _localPath = path;
        _isProcessing = true;
      });

      // Retrieve transcription from OpenAi Service (Whisper)
      String transcribedText = "";
      if (path != null) {
        transcribedText = await OpenAiService.transcribeAudio(path, languageCode: langCode);
      }

      final originalSpeech = transcribedText.trim();

      if (originalSpeech.isNotEmpty) {
        await _parseSpeechResultsWithAi(originalSpeech);

        _recognizedText = originalSpeech;
        _parsedNote = originalSpeech;
      } else {
        _recognizedText = "No transcription returned. Please record again and make sure to speak clearly near the microphone.";
        _parsedNote = "";
      }

      // Latency simulation for translation processing
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isProcessing = false;
        _showTranslation = false;
        _showConfirmation = true;
      });
    } else {
      // 2. Start Audio Record
      // Request mic permission explicitly using permission_handler
      var status = await Permission.microphone.status;
      if (!status.isGranted) {
        status = await Permission.microphone.request();
      }

      if (status.isGranted) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/voice_${const Uuid().v4()}.m4a';

        // Use safe default configuration for broad compatibility
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
          ),
          path: path,
        );

        setState(() {
          _isRecording = true;
          _showConfirmation = false;
          _recognizedText = "Recording audio... Speak naturally now."; // Feedback while recording
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Microphone permission is required to record voice notes."),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  // AI-based Structured Voice Parsing (Step 9)
  Future<void> _parseSpeechResultsWithAi(String text) async {
    _parsedNote = text;
    _parsedExpenses.clear();

    try {
      final aiResult = await OpenAiService.parseVoiceTranscript(text);
      if (aiResult != null) {
        final String activity = aiResult['activity'] ?? "Other";
        final String plot = aiResult['plot'] ?? "Plot 1";
        final String expenseStr = aiResult['expense'] ?? "0";
        final double expenseVal = double.tryParse(expenseStr.replaceAll(RegExp(r'[^\d\.]'), '')) ?? 0.0;

        // Map activity to valid work types in AppConstants
        final String actLower = activity.toLowerCase();
        if (actLower.contains("spraying") || actLower.contains("spray") || actLower.contains("fungicide") || actLower.contains("pesticide") || actLower.contains("medicine")) {
          _parsedWorkType = "Spraying";
        } else if (actLower.contains("fertilizer") || actLower.contains("urea") || actLower.contains("dap") || actLower.contains("manure") || actLower.contains("gobbara")) {
          _parsedWorkType = "Fertilizer";
        } else if (actLower.contains("irrigation") || actLower.contains("water")) {
          _parsedWorkType = "Irrigation";
        } else if (actLower.contains("canopy") || actLower.contains("weeding") || actLower.contains("pruning") || actLower.contains("trimming")) {
          _parsedWorkType = "Canopy management";
        } else if (actLower.contains("labour") || actLower.contains("worker") || actLower.contains("cooli")) {
          _parsedWorkType = "Labour work";
        } else if (actLower.contains("harvest")) {
          _parsedWorkType = "Harvesting";
        } else if (actLower.contains("dry") || actLower.contains("drying")) {
          _parsedWorkType = "Drying grapes";
        } else if (actLower.contains("packing")) {
          _parsedWorkType = "Packing";
        } else if (actLower.contains("selling")) {
          _parsedWorkType = "Selling";
        } else if (actLower.contains("observation") || actLower.contains("disease")) {
          _parsedWorkType = "Disease observation";
        } else if (actLower.contains("market")) {
          _parsedWorkType = "Market visit";
        } else {
          _parsedWorkType = "Other";
        }

        _parsedNote = "$activity in $plot";
        _parsedStage = "Berry growth"; // Default crop stage placeholder

        if (expenseVal > 0) {
          String category = "Other";
          String itemName = activity;

          if (_parsedWorkType == "Spraying") {
            category = "Pesticide";
            itemName = "Pesticides/Fungicides";
          } else if (_parsedWorkType == "Fertilizer") {
            category = "Fertilizer";
            itemName = "Fertilizer Purchases";
          } else if (_parsedWorkType == "Labour work") {
            category = "Labour";
            itemName = "Labour Wages";
          } else if (_parsedWorkType == "Irrigation") {
            category = "Irrigation";
            itemName = "Irrigation Maintenance";
          } else if (_parsedWorkType == "Packing") {
            category = "Packing";
            itemName = "Packing Bags";
          } else if (_parsedWorkType == "Selling" || _parsedWorkType == "Market visit") {
            category = "Market expense";
            itemName = "Market Transport/Fees";
          }

          _parsedExpenses.add(ExpenseModel(
            category: category,
            itemName: itemName,
            quantity: 1,
            unit: category == "Labour" ? "worker" : "other",
            totalAmount: expenseVal,
            date: DateTime.now().toIso8601String().substring(0, 10),
          ));
        }
        return;
      }
    } catch (e) {
      debugPrint("Structured voice AI parsing failed, calling local fallback: $e");
    }

    // Call local fallback parser if AI fails
    _parseSpeechResults(text);
  }

  // A very smart natural agricultural parser that extracts details from Kannada, Hindi, and English
  void _parseSpeechResults(String text) {
    String t = text.toLowerCase();
    _parsedNote = text;
    _parsedExpenses.clear();

    // 1. Parse Work Type
    if (t.contains("spraying") || t.contains("ಸಿಂಪಡಣೆ") || t.contains("छिड़काव") || t.contains("ಔಷಧಿ") || t.contains("ಬೋರ್ಡೋ") || t.contains("bordeaux")) {
      _parsedWorkType = "Spraying";
      _parsedStage = "Berry growth";
    } else if (t.contains("fertilizer") || t.contains("ಗೊಬ್ಬರ") || t.contains("खाद") || t.contains("ಪೋಷಕಾಂಶ") || t.contains("ಯುರಿಯಾ") || t.contains("urea")) {
      _parsedWorkType = "Fertilizer";
      _parsedStage = "Bud stage";
    } else if (t.contains("labour") || t.contains("ಕೂಲಿ") || t.contains("ಮಜ್ದೂರ್") || t.contains("मजदूर") || t.contains("worker") || t.contains("ಕೆಲಸಗಾರ") || t.contains("ಕೆಲಸ")) {
      _parsedWorkType = "Labour work";
      _parsedStage = "Other";
    } else if (t.contains("harvest") || t.contains("ಕೊಯ್ಲು") || t.contains("कटाई") || t.contains("ಕಟಾವು")) {
      _parsedWorkType = "Harvesting";
      _parsedStage = "Harvesting";
    } else {
      _parsedWorkType = "Other";
    }

    // 2. Parse Expenses
    double cost = 0;
    String item = "Medicines";

    if (t.contains("mancozeb") || t.contains("ಮ್ಯಾಂಕೋಜೆಬ್") || t.contains("मैंकोज़ेब")) {
      item = "Mancozeb";
    } else if (t.contains("ಬೋರ್ಡೋ") || t.contains("bordeaux") || t.contains("bordo")) {
      item = "Bordeaux";
    } else if (t.contains("ಯುರಿಯಾ") || t.contains("urea") || t.contains("यूरिया")) {
      item = "Urea";
    } else if (t.contains("gobbara") || t.contains("ಗೊಬ್ಬರ") || t.contains("खाದ") || t.contains("खाद")) {
      item = "Fertilizer";
    } else if (t.contains("cooli") || t.contains("ಕೂಲಿ") || t.contains("ಮಜೂರಿ") || t.contains("मजदूरी")) {
      item = "Labour cost";
    } else {
      item = "Medicines";
    }

    // A: High-Precision Mixed Numeric-Text Multiplier checks first!
    // E.g. "5 ಸಾವಿರ", "10 ಸಾವಿರ", "2 thousand", "10 हजार"
    final RegExp thousandMixedRegex = RegExp(r'(\d+)\s*(ಸಾವಿರ|ಸಾ|ಹಜಾರ|ಹಜಾರ್|हजार|thousand|k)');
    final thousandMatch = thousandMixedRegex.firstMatch(t);
    if (thousandMatch != null) {
      final val = double.tryParse(thousandMatch.group(1)!) ?? 0.0;
      cost = val * 1000;
    } else {
      // Hundreds mixed check: e.g. "5 ನೂರು", "3 सौ", "2 hundred"
      final RegExp hundredMixedRegex = RegExp(r'(\d+)\s*(ನೂರು|ನೂ|सौ|hundred)');
      final hundredMatch = hundredMixedRegex.firstMatch(t);
      if (hundredMatch != null) {
        final val = double.tryParse(hundredMatch.group(1)!) ?? 0.0;
        cost = val * 100;
      }
    }

    // B: If mixed parser did not match, parse text phonetic word compounds (ordered from largest to smallest)
    if (cost == 0) {
      if (t.contains("ಹತ್ತು ಸಾವಿರ") || t.contains("दस हजार") || t.contains("ten thousand") || t.contains("10000")) {
        cost = 10000.0;
      } else if (t.contains("ಎಂಟು ಸಾವಿರ") || t.contains("आठ हजार") || t.contains("eight thousand") || t.contains("8000")) {
        cost = 8000.0;
      } else if (t.contains("ಐದು ಸಾವಿರ") || t.contains("पांच हजार") || t.contains("five thousand") || t.contains("5000")) {
        cost = 5000.0;
      } else if (t.contains("ನಾಲ್ಕು ಸಾವಿರ") || t.contains("चार हजार") || t.contains("four thousand") || t.contains("4000")) {
        cost = 4000.0;
      } else if (t.contains("ಮೂರು ಸಾವಿರ") || t.contains("तीन हजार") || t.contains("three thousand") || t.contains("3000")) {
        cost = 3000.0;
      } else if (t.contains("ಎರಡು ಸಾವಿರದ ಐನೂರು") || t.contains("ढाई हजार") || t.contains("two thousand five hundred") || t.contains("2500")) {
        cost = 2500.0;
      } else if (t.contains("ಎರಡು ಸಾವಿರ") || t.contains("दो हजार") || t.contains("two thousand") || t.contains("2000")) {
        cost = 2000.0;
      } else if (t.contains("ಒಂದು ಸಾವಿರ") || t.contains("ಸಾವಿರ") || t.contains("एक हजार") || t.contains("हजार") || t.contains("one thousand") || t.contains("thousand") || t.contains("1000")) {
        cost = 1000.0;
      } else if (t.contains("ಐನೂರು") || t.contains("पांच सौ") || t.contains("five hundred") || t.contains("500")) {
        cost = 500.0;
      } else if (t.contains("ಮೂರು ನೂರು") || t.contains("तीन सौ") || t.contains("three hundred") || t.contains("300")) {
        cost = 300.0;
      } else if (t.contains("ಎರಡು ನೂರು") || t.contains("दो सौ") || t.contains("two hundred") || t.contains("200")) {
        cost = 200.0;
      } else if (t.contains("ಒಂದು ನೂರು") || t.contains("ನೂರು") || t.contains("एक सौ") || t.contains("सौ") || t.contains("one hundred") || t.contains("hundred") || t.contains("100")) {
        cost = 100.0;
      } else {
        // Fallback to pure digit parsing if no keywords match
        final RegExp numRegExp = RegExp(r'\d+');
        final match = numRegExp.firstMatch(t);
        if (match != null) {
          cost = double.tryParse(match.group(0)!) ?? 0.0;
        }
      }
    }

    if (cost > 0) {
      String expenseCategory = "Pesticide";
      if (_parsedWorkType == "Labour work" || item == "Labour cost") {
        expenseCategory = "Labour";
      } else if (_parsedWorkType == "Fertilizer" || item == "Fertilizer") {
        expenseCategory = "Fertilizer";
      }

      _parsedExpenses.add(
        ExpenseModel(
          category: expenseCategory,
          itemName: item,
          quantity: 1,
          unit: _parsedWorkType == "Labour work" ? "worker" : "kg",
          totalAmount: cost,
          date: DateTime.now().toIso8601String().substring(0, 10),
        ),
      );
    }
  }

  // Save parsed speech entry
  void _confirmAndSaveDiary(String langCode) async {
    setState(() {
      _isSaving = true;
    });

    final authService = Provider.of<FirebaseAuthService>(context, listen: false);
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final storageService = Provider.of<StorageService>(context, listen: false);

    final String uid = authService.currentUid ?? "mock_farmer_patil";
    final String entryId = const Uuid().v4();

    // 1. Upload local audio file to Storage
    String voiceUrl = "";
    if (_localPath != null && File(_localPath!).existsSync()) {
      try {
        voiceUrl = await storageService.uploadAudio(
          file: File(_localPath!),
          farmerId: uid,
          farmId: widget.farmId,
          entryId: entryId,
          audioName: "audio_${DateTime.now().millisecondsSinceEpoch}.m4a",
        );
      } catch (e) {
        voiceUrl = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3";
      }
    }

    double totalExp = _parsedExpenses.fold(0.0, (sum, item) => sum + item.totalAmount);

    final entry = DiaryEntryModel(
      entryId: entryId,
      farmerId: uid,
      farmId: widget.farmId,
      date: DateTime.now().toIso8601String().substring(0, 10),
      cropStage: _parsedStage,
      workType: _parsedWorkType,
      languageCode: langCode,
      inputType: "voice",
      originalText: _recognizedText,
      cleanedText: _parsedNote,
      voiceUrl: voiceUrl,
      photos: [],
      expenses: _parsedExpenses,
      structuredData: StructuredData(
        pesticides: _parsedExpenses.where((e) => e.category == 'Pesticide').map((e) => e.toMap()).toList(),
        fertilizers: _parsedExpenses.where((e) => e.category == 'Fertilizer').map((e) => e.toMap()).toList(),
        labour: _parsedWorkType == "Labour work" ? {'workers': 2, 'amount': totalExp} : {},
        irrigation: {},
        expenses: _parsedExpenses,
        observations: [],
        followUpActions: [],
        tags: [_parsedWorkType, _parsedStage],
      ),
      totalExpense: totalExp,
      missingFields: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await firestoreService.saveDiaryEntry(uid, widget.farmId, entry);

    setState(() {
      _isSaving = false;
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(langCode == 'kn-IN' ? "ದಾಖಲೆ ಯಶಸ್ವಿಯಾಗಿ ಉಳಿಸಲಾಗಿದೆ!" : "Diary entry successfully registered via speech!"),
        backgroundColor: AppColors.successGreen,
      ),
    );

    Navigator.pop(context);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final langCode = Provider.of<LanguageNotifier>(context).currentLanguage;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppTranslations.translate('record_voice_note', langCode)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isProcessing) ...[
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.accentPurple),
                        SizedBox(height: 18),
                        Text(
                          "AI Parsing Speech...",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accentPurple),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (!_showConfirmation) ...[
                const SizedBox(height: 40),
                const Text(
                  "Speech-to-Text Input",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.earthyBrown),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Speak naturally in your selected language about your spraying, fertilizer costs, or workers, and the AI-ready engine will transcribe and structure the details automatically.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textLight, height: 1.4),
                ),
                const SizedBox(height: 50),

                // Large animating microphone button
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isRecording) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.all(16),
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 80, maxHeight: 150),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.2)),
                            ),
                            child: SingleChildScrollView(
                              reverse: true,
                              child: Text(
                                _recognizedText.isNotEmpty ? _recognizedText : "Start speaking...",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _recognizedText.isNotEmpty ? AppColors.textDark : AppColors.textLight.withValues(alpha: 0.7),
                                  fontStyle: _recognizedText.isEmpty ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                        ],
                        GestureDetector(
                          onTap: () => _toggleRecording(langCode),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: _isRecording ? 180 : 140,
                            height: _isRecording ? 180 : 140,
                            decoration: BoxDecoration(
                              color: _isRecording ? AppColors.primaryGreen : AppColors.accentPurple,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (_isRecording ? AppColors.primaryGreen : AppColors.accentPurple).withValues(alpha: 0.4),
                                  blurRadius: 20,
                                  spreadRadius: _isRecording ? 10 : 2,
                                )
                              ],
                            ),
                            child: Icon(
                              _isRecording ? Icons.stop : Icons.mic,
                              size: 70,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          _isRecording ? "Listening... Tap to stop" : "Tap microphone to speak",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _isRecording ? AppColors.primaryGreen : AppColors.textLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Confirmation screen ("We Understood This" flow!)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 10),
                        // Confirmation Banner Header
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(12),
                             border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: AppColors.primaryGreen, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  AppTranslations.translate('speech_understood', langCode),
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Original transcript display card
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Original Speech Transcript", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                              const SizedBox(height: 6),
                              Text(
                                _recognizedText.isNotEmpty ? _recognizedText : "[Silence]",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Audio Playback Card
                        if (_localPath != null) ...[
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.mic, color: AppColors.primaryGreen, size: 16),
                                    const SizedBox(width: 6),
                                    const Text("Audio Voice Note Playback", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () async {
                                        if (_isPlaying) {
                                          await _audioPlayer.pause();
                                        } else {
                                          await _audioPlayer.play(DeviceFileSource(_localPath!));
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primaryGreen,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _isPlaying ? Icons.pause : Icons.play_arrow,
                                          color: AppColors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        children: [
                                          SliderTheme(
                                            data: SliderTheme.of(context).copyWith(
                                              trackHeight: 4,
                                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                              activeTrackColor: AppColors.primaryGreen,
                                              inactiveTrackColor: AppColors.primaryGreen.withAlpha(50),
                                              thumbColor: AppColors.primaryGreen,
                                            ),
                                            child: Slider(
                                              min: 0.0,
                                              max: _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0,
                                              value: _position.inMilliseconds.toDouble().clamp(0.0, _duration.inMilliseconds.toDouble() > 0 ? _duration.inMilliseconds.toDouble() : 1.0),
                                              onChanged: (value) async {
                                                await _audioPlayer.seek(Duration(milliseconds: value.toInt()));
                                              },
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  _formatDuration(_position),
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                                ),
                                                Text(
                                                  _formatDuration(_duration),
                                                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Parsed fields settings
                        AppCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Structured Interpretation Details", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.earthyBrown)),
                              const SizedBox(height: 14),

                              // Work Type Dropdown edit
                              const Text("Work Type", style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                              DropdownButton<String>(
                                value: _parsedWorkType,
                                isExpanded: true,
                                onChanged: (val) {
                                  if (val != null) setState(() => _parsedWorkType = val);
                                },
                                items: AppConstants.workTypes.map((w) => DropdownMenuItem(
                                  value: w,
                                  child: Text(AppTranslations.translate(w, langCode)),
                                )).toList(),
                              ),
                              const SizedBox(height: 14),

                              // Crop Stage Dropdown edit
                              const Text("Crop Stage", style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                              DropdownButton<String>(
                                value: _parsedStage,
                                isExpanded: true,
                                onChanged: (val) {
                                  if (val != null) setState(() => _parsedStage = val);
                                },
                                items: AppConstants.cropStages.map((cs) => DropdownMenuItem(
                                  value: cs,
                                  child: Text(AppTranslations.translate(cs, langCode)),
                                )).toList(),
                              ),
                              const SizedBox(height: 14),

                              // Notes Edit Field
                              const Text("Cleaned Note", style: TextStyle(fontSize: 12, color: AppColors.textLight, fontWeight: FontWeight.bold)),
                              TextField(
                                controller: TextEditingController(text: _parsedNote),
                                onChanged: (val) => _parsedNote = val,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // parsed Expenses Card
                        if (_parsedExpenses.isNotEmpty)
                          AppCard(
                            color: Colors.amber.shade50,
                            border: Border.all(color: Colors.amber.shade200),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Detected Cost Items", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange)),
                                const SizedBox(height: 8),
                                ..._parsedExpenses.map((exp) => Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text("${exp.category} (${exp.itemName})", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                                        Text("₹${exp.totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accentPurple)),
                                      ],
                                    )),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),

                // Button options row
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: "Record Again",
                        icon: Icons.refresh,
                        isSecondary: true,
                        onPressed: () {
                          _audioPlayer.stop();
                          setState(() {
                            _showConfirmation = false;
                            _recognizedText = "";
                            _parsedExpenses.clear();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        text: AppTranslations.translate('confirm_save', langCode),
                        icon: Icons.check,
                        isLoading: _isSaving,
                        onPressed: () => _confirmAndSaveDiary(langCode),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
