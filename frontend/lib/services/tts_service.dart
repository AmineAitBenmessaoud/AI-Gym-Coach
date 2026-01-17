import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/foundation.dart';

/// Service for handling text-to-speech operations
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  TtsService._internal();

  /// Initialize TTS with settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Set language to English
      await _flutterTts.setLanguage("en-US");
      
      // Set speech rate (0.5 = slow, 1.0 = normal)
      await _flutterTts.setSpeechRate(0.5);
      
      // Set volume (0.0 to 1.0)
      await _flutterTts.setVolume(1.0);
      
      // Set pitch (0.5 to 2.0, 1.0 = normal)
      await _flutterTts.setPitch(1.0);

      // Set up completion handler
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      // Set up error handler
      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        _isSpeaking = false;
      });

      _isInitialized = true;
      debugPrint('✅ TTS Service initialized');
    } catch (e) {
      debugPrint('⚠️ TTS initialization error: $e');
    }
  }

  /// Speak text with optional priority
  Future<void> speak(String text, {bool interrupt = false}) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (text.isEmpty) return;

    try {
      // If interrupt is true, stop current speech
      if (interrupt && _isSpeaking) {
        await stop();
      }

      // Don't speak if already speaking (unless interrupt is true)
      if (_isSpeaking && !interrupt) {
        debugPrint('🔇 TTS busy, skipping: "$text"');
        return;
      }

      _isSpeaking = true;
      debugPrint('🔊 Speaking: "$text"');
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('⚠️ TTS speak error: $e');
      _isSpeaking = false;
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (e) {
      debugPrint('⚠️ TTS stop error: $e');
    }
  }

  /// Pause current speech
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (e) {
      debugPrint('⚠️ TTS pause error: $e');
    }
  }

  /// Check if currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Dispose TTS resources
  Future<void> dispose() async {
    await stop();
  }
}
