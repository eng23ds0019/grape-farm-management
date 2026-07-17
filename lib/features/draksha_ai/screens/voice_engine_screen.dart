import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../services/firestore_service.dart';
import '../../../services/speech_service.dart';
import '../../../services/weather_service.dart';
import '../../../services/disease_prediction_service.dart';
import '../services/draksha_api_client.dart';

class VoiceEngineScreen extends StatefulWidget {
  final String selectedFarmId;

  const VoiceEngineScreen({super.key, required this.selectedFarmId});

  @override
  State<VoiceEngineScreen> createState() => _VoiceEngineScreenState();
}

class _VoiceEngineScreenState extends State<VoiceEngineScreen> with SingleTickerProviderStateMixin {
  late AnimationController _micPulseController;
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isListening = false;
  bool _isProcessing = false;
  String _statusText = "Tap the microphone to speak";

  @override
  void initState() {
    super.initState();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
      lowerBound: 1.0,
      upperBound: 1.5,
    );

    _flutterTts.setStartHandler(() {
      setState(() => _statusText = "Draksha AI is speaking...");
    });
    
    _flutterTts.setCompletionHandler(() {
      setState(() => _statusText = "Tap the microphone to speak");
      _micPulseController.stop();
    });
  }

  @override
  void dispose() {
    _micPulseController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _speak(String text, String langCode) async {
    await _flutterTts.stop();
    await _flutterTts.setLanguage(langCode);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _micPulseController.repeat(reverse: true);
    await _flutterTts.speak(text);
  }

  void _dispatchDiseaseAlert(String farmerId, String risk, String disease, String spray) async {
    final alertId = const Uuid().v4();
    final alertData = {
      'alertId': alertId,
      'disease': disease,
      'riskLevel': risk,
      'recommendedSpray': spray,
      'explanation': "Draksha AI detected high risk factors during orchestration.",
      'createdAt': DateTime.now().toIso8601String(),
      'read': false,
    };

    // Save to Firestore
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(farmerId)
          .collection('alerts')
          .doc(alertId)
          .set(alertData);
    } catch (e) {
      debugPrint("Failed to save alert: $e");
    }

    // Trigger Notification Popup (ensuring it pops up locally)
    final String title = risk == 'High' ? "⚠️ Disease Alert: $disease" : "🔔 Disease Advisory: $disease";
    final String body = "Risk Level: $risk\nRecommended Spray: $spray";
    
    await DiseasePredictionService.showSystemNotification(
      title: title,
      body: body,
      payload: jsonEncode(alertData),
    );
  }

  void _toggleListening() async {
    final speechService = Provider.of<SpeechService>(context, listen: false);
    final langCode = Provider.of<LanguageNotifier>(context, listen: false).currentLanguage;
    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    
    await _flutterTts.stop();

    if (_isListening) {
      // Stop listening manually
      _micPulseController.stop();
      setState(() {
        _isListening = false;
        _statusText = "Processing...";
        _isProcessing = true;
      });
      
      final text = await speechService.stopListening();
      if (text.isNotEmpty) {
        _processVoiceQuery(text, firestoreService, langCode);
      } else {
        setState(() {
          _isProcessing = false;
          _statusText = "Tap the microphone to speak";
        });
      }
    } else {
      // Start listening
      await speechService.initSpeech();
      _micPulseController.repeat(reverse: true);
      setState(() {
        _isListening = true;
        _statusText = "Listening...";
      });

      await speechService.startListening(
        languageCode: langCode,
        onResult: (text, confidence, isFinal) {
          if (isFinal && text.trim().isNotEmpty) {
            _micPulseController.stop();
            setState(() {
              _isListening = false;
              _isProcessing = true;
              _statusText = "Reasoning...";
            });
            _processVoiceQuery(text, firestoreService, langCode);
          }
        },
        onTimeout: () {
          _micPulseController.stop();
          setState(() {
            _isListening = false;
            _statusText = "Tap the microphone to speak";
          });
        },
      );
    }
  }

  void _processVoiceQuery(String query, FirestoreService firestoreService, String langCode) async {
    final farmerId = firestoreService.cachedFarmer?.farmerId ?? "";
    if (farmerId.isEmpty) {
      setState(() => _isProcessing = false);
      _speak("Please log in to access your farm memory.", langCode);
      return;
    }

    final weather = await WeatherService.getCurrentWeather("Nashik");

    final result = await DrakshaApiClient.sendVoiceQuery(
      uid: farmerId,
      query: query,
      weatherContext: weather.toString(),
    );

    setState(() => _isProcessing = false);
    
    final risk = result['diseaseRisk'] as String?;
    final disease = result['diseaseName'] as String?;
    final spray = result['recommendedSpray'] as String?;

    if ((risk == "High" || risk == "Medium") && disease != null && disease != "None") {
      _dispatchDiseaseAlert(farmerId, risk, disease, spray ?? "Consult Agrivisor");
    }

    final responseText = result['response'] as String? ?? "Error generating voice response.";
    await _speak(responseText, langCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: const Text("Draksha AI Manager"),
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            AnimatedBuilder(
              animation: _micPulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _micPulseController.value,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening 
                          ? AppColors.errorRed.withOpacity(0.2) 
                          : AppColors.primaryGreen.withOpacity(0.2),
                    ),
                    padding: const EdgeInsets.all(40),
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onTap: _isProcessing ? null : _toggleListening,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isListening ? AppColors.errorRed : AppColors.primaryGreen,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  padding: const EdgeInsets.all(30),
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              _statusText,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: AppColors.primaryGreen),
            ],
            const Spacer(),
            const Padding(
              padding: EdgeInsets.all(20.0),
              child: Text(
                "Draksha AI is securely reasoning with your Farm Memory and Grape Knowledge Base.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            )
          ],
        ),
      ),
    );
  }
}
