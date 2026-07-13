import 'package:speech_to_text/speech_to_text.dart';

class SpeechService {
  final SpeechToText _speech = SpeechToText();

  Future<bool> initialize() => _speech.initialize();

  Future<void> listen({
    required String languageCode,
    required void Function(String text) onText,
  }) async {
    final locale = switch (languageCode) {
      'kn' => 'kn_IN',
      'hi' => 'hi_IN',
      _ => 'en_IN',
    };
    await _speech.listen(
      onResult: (result) => onText(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        localeId: locale,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> stop() => _speech.stop();
}
