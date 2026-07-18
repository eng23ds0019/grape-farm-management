import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/colors.dart';
import '../../../core/localization/language_notifier.dart';
import '../../../services/firestore_service.dart';
import '../../../services/speech_service.dart';
import '../../../services/location_service.dart';
import '../services/draksha_api_client.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final String? base64Image;
  
  ChatMessage({required this.text, required this.isUser, this.base64Image});
}

class VoiceEngineScreen extends StatefulWidget {
  final String selectedFarmId;

  const VoiceEngineScreen({super.key, required this.selectedFarmId});

  @override
  State<VoiceEngineScreen> createState() => _VoiceEngineScreenState();
}

class _VoiceEngineScreenState extends State<VoiceEngineScreen> with SingleTickerProviderStateMixin {
  late AnimationController _micPulseController;
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  
  bool _isListening = false;
  bool _isProcessing = false;
  bool _voiceMode = false;
  String _statusText = "Online";
  File? _selectedImage;
  String? _selectedImageBase64;
  
  final List<ChatMessage> _messages = [];

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
      if (_voiceMode) {
        setState(() => _statusText = "Draksha AI is speaking...");
      }
    });
    
    _flutterTts.setCompletionHandler(() {
      setState(() => _statusText = "Online");
      _micPulseController.stop();
    });
    
    // Add a welcome message
    _messages.add(ChatMessage(
      text: "Hello! I am Draksha AI, your Vineyard Manager. How can I assist you with your plot today?",
      isUser: false,
    ));

    // Request and update coordinates on opening assistant
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLocationUpdate();
    });
  }

  Future<void> _initLocationUpdate() async {
    try {
      final firestoreService = Provider.of<FirestoreService>(context, listen: false);
      final farmerId = firestoreService.cachedFarmer?.farmerId ?? "";
      if (farmerId.isNotEmpty) {
        await LocationService.checkAndSaveLocation(farmerId);
        // Refresh local cache to ensure latest coords are saved/synced
        await firestoreService.syncOfflineData(farmerId);
      }
    } catch (e) {
      debugPrint("VoiceEngineScreen location update error: $e");
    }
  }

  @override
  void dispose() {
    _micPulseController.dispose();
    _flutterTts.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _speak(String text, String langCode) async {
    if (!_voiceMode) return;
    
    await _flutterTts.stop();
    await _flutterTts.setLanguage(langCode);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _micPulseController.repeat(reverse: true);
    await _flutterTts.speak(text);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        final File file = File(pickedFile.path);
        final bytes = await file.readAsBytes();
        
        setState(() {
          _selectedImage = file;
          _selectedImageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBase64 = null;
    });
  }

  void _toggleListening() async {
    final speechService = Provider.of<SpeechService>(context, listen: false);
    final langCode = Provider.of<LanguageNotifier>(context, listen: false).currentLanguage;
    
    await _flutterTts.stop();

    if (_isListening) {
      // Stop listening manually
      _micPulseController.stop();
      setState(() {
        _isListening = false;
        _statusText = "Online";
      });
      
      final text = await speechService.stopListening();
      if (text.isNotEmpty) {
        if (_voiceMode) {
          _submitMessage(text, isVoice: true);
        } else {
          _textController.text = _textController.text + (text.isEmpty ? "" : " " + text);
        }
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
              _statusText = "Online";
            });
            if (_voiceMode) {
              _submitMessage(text, isVoice: true);
            } else {
               _textController.text = _textController.text + (text.isEmpty ? "" : " " + text);
            }
          }
        },
        onTimeout: () {
          _micPulseController.stop();
          setState(() {
            _isListening = false;
            _statusText = "Online";
          });
        },
      );
    }
  }

  void _submitMessage(String query, {bool isVoice = false}) async {
    if (query.trim().isEmpty && _selectedImage == null) return;

    final firestoreService = Provider.of<FirestoreService>(context, listen: false);
    final langCode = Provider.of<LanguageNotifier>(context, listen: false).currentLanguage;
    
    final farmerId = firestoreService.cachedFarmer?.farmerId ?? "";
    if (farmerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to access your farm memory."))
      );
      return;
    }

    final String imagePayload = _selectedImageBase64 ?? "";
    
    setState(() {
      _messages.add(ChatMessage(
        text: query,
        isUser: true,
        base64Image: _selectedImageBase64,
      ));
      _isProcessing = true;
      _statusText = "Reasoning...";
      _textController.clear();
      _selectedImage = null;
      _selectedImageBase64 = null;
      
      // If the user submitted via text while voice mode was on, turn voice mode off for this response
      if (!isVoice) {
         _voiceMode = false;
      }
    });
    
    _scrollToBottom();

    final result = await DrakshaApiClient.sendQuery(
      uid: farmerId,
      query: query,
      farmId: widget.selectedFarmId,
      language: langCode,
      imageBase64: imagePayload.isNotEmpty ? imagePayload : null,
    );

    setState(() {
      _isProcessing = false;
      _statusText = "Online";
      
      final responseText = result['response'] as String? ?? "Error generating response.";
      _messages.add(ChatMessage(text: responseText, isUser: false));
    });
    
    _scrollToBottom();

    if (_voiceMode) {
      final responseText = result['response'] as String? ?? "";
      // Strip markdown for TTS
      final cleanText = responseText.replaceAll(RegExp(r'[*#_`]'), '');
      await _speak(cleanText, langCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Draksha AI"),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  "$_statusText • Plot: ${widget.selectedFarmId.isNotEmpty ? widget.selectedFarmId : 'Default'}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        elevation: 1,
      ),
      body: Column(
        children: [
          // Chat Area
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          
          if (_isProcessing)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            ),
            
          // Selected Image Preview Area
          if (_selectedImage != null)
            Container(
              padding: const EdgeInsets.all(8),
              alignment: Alignment.centerLeft,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_selectedImage!, width: 100, height: 100, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: -10,
                    right: -10,
                    child: IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: _removeSelectedImage,
                    ),
                  )
                ],
              ),
            ),
            
          // Input Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Upload Image Button
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate, color: AppColors.primaryGreen),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt),
                              title: const Text('Camera'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage(ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library),
                              title: const Text('Gallery'),
                              onTap: () {
                                Navigator.pop(context);
                                _pickImage(ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                
                // Voice to Text (transcribes into text field)
                IconButton(
                  icon: Icon(_isListening && !_voiceMode ? Icons.stop : Icons.mic_none, color: AppColors.primaryGreen),
                  onPressed: () {
                    setState(() {
                       _voiceMode = false;
                    });
                    _toggleListening();
                  },
                  tooltip: "Voice to text",
                ),

                // Text Field
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: "Message Draksha AI...",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    onSubmitted: (text) => _submitMessage(text, isVoice: false),
                  ),
                ),
                
                // Send / Voice Conversation
                AnimatedBuilder(
                  animation: _micPulseController,
                  builder: (context, child) {
                    final bool hasInput = _textController.text.trim().isNotEmpty || _selectedImage != null;
                    
                    if (hasInput) {
                       return IconButton(
                          icon: const Icon(Icons.send, color: AppColors.primaryGreen),
                          onPressed: () => _submitMessage(_textController.text, isVoice: false),
                        );
                    }
                    
                    return Transform.scale(
                      scale: _voiceMode && _isListening ? _micPulseController.value : 1.0,
                      child: IconButton(
                        icon: Icon(
                          _voiceMode && _isListening ? Icons.stop_circle : Icons.record_voice_over, 
                          color: _voiceMode && _isListening ? AppColors.errorRed : AppColors.primaryGreen
                        ),
                        onPressed: () {
                           setState(() {
                             _voiceMode = true;
                           });
                           _toggleListening();
                        },
                        tooltip: "Real-time Voice Conversation",
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: message.isUser ? AppColors.primaryGreen : Colors.white,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: message.isUser ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: message.isUser ? const Radius.circular(16) : const Radius.circular(0),
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            )
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.base64Image != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  base64Decode(message.base64Image!),
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (message.text.isNotEmpty)
              message.isUser 
                ? Text(
                    message.text,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  )
                : MarkdownBody(
                    data: message.text,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: Colors.black87, fontSize: 16),
                      listBullet: const TextStyle(color: AppColors.primaryGreen),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
