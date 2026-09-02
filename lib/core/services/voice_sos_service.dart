import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VoiceSosState Enum
// ─────────────────────────────────────────────────────────────────────────────

/// High-level status of the Voice SOS subsystem.
enum VoiceSosState {
  /// Engine is idle, not actively listening.
  idle,

  /// Initializing speech recognition engine / permissions.
  initializing,

  /// Actively listening for voice input.
  listening,

  /// Emergency phrase was recognized and matched.
  emergencyDetected,

  /// SOS workflow is actively executing (GPS -> Firestore -> SMS).
  triggeringSos,

  /// SOS completed successfully.
  sosTriggered,

  /// Microphone permission is required / denied.
  permissionRequired,

  /// Microphone permission permanently denied (requires app settings).
  permissionPermanentlyDenied,

  /// Speech recognition is unavailable on this device.
  unavailable,

  /// An error occurred during recognition.
  error,
}

// ─────────────────────────────────────────────────────────────────────────────
// VoiceSosService
// ─────────────────────────────────────────────────────────────────────────────

/// Core service for Voice SOS keyword detection.
///
/// Features:
/// - Robust keyword matching against configured emergency phrases.
/// - False-positive protection (whole-word boundary check prevents "helper" or "helpful" from triggering).
/// - Deduplication & trigger lock so continuous speech callbacks cannot fire multiple SOS alerts.
/// - Graceful permission and error handling.
class VoiceSosService {
  VoiceSosService({
    SpeechToText? speechToText,
  }) : _speechToText = speechToText ?? SpeechToText();

  final SpeechToText _speechToText;

  // ── Default Emergency Phrases ──────────────────────────────────────────────

  /// Centralized list of supported emergency trigger keywords and phrases.
  static const List<String> defaultEmergencyPhrases = [
    'help',
    'emergency',
    'alert',
    'save me',
    'danger',
    'sos',
    'nari suraksha help',
  ];

  // ── State ──────────────────────────────────────────────────────────────────

  VoiceSosState _state = VoiceSosState.idle;
  String _recognizedText = '';
  String? _lastDetectedPhrase;
  String? _errorMessage;
  bool _isTriggerLocked = false;
  bool _isInitialized = false;

  List<String> _emergencyPhrases = List.unmodifiable(defaultEmergencyPhrases);

  // ── Callbacks ──────────────────────────────────────────────────────────────

  /// Invoked when the state changes.
  ValueChanged<VoiceSosState>? onStateChanged;

  /// Invoked when speech text is updated.
  ValueChanged<String>? onTextChanged;

  /// Invoked immediately when a valid emergency phrase is detected.
  ValueChanged<String>? onEmergencyDetected;

  /// Invoked when an error message is generated.
  ValueChanged<String>? onError;

  // ── Getters ────────────────────────────────────────────────────────────────

  VoiceSosState get state => _state;
  String get recognizedText => _recognizedText;
  String? get lastDetectedPhrase => _lastDetectedPhrase;
  String? get errorMessage => _errorMessage;
  bool get isListening => _state == VoiceSosState.listening;
  bool get isTriggerLocked => _isTriggerLocked;
  bool get isInitialized => _isInitialized;
  List<String> get emergencyPhrases => _emergencyPhrases;

  /// Configures custom emergency phrases if needed.
  void setEmergencyPhrases(List<String> phrases) {
    _emergencyPhrases = List.unmodifiable(
      phrases.map((p) => p.trim().toLowerCase()).where((p) => p.isNotEmpty),
    );
  }

  // ── Initialization & Permissions ───────────────────────────────────────────

  /// Requests microphone permission and initializes the speech engine.
  Future<bool> initialize() async {
    _updateState(VoiceSosState.initializing);
    _errorMessage = null;

    // 1. Check microphone permission
    final permStatus = await Permission.microphone.status;
    if (permStatus.isPermanentlyDenied) {
      _errorMessage = 'Microphone permission is permanently denied. Please enable it in Settings.';
      _updateState(VoiceSosState.permissionPermanentlyDenied);
      return false;
    }

    if (!permStatus.isGranted) {
      final reqResult = await Permission.microphone.request();
      if (reqResult.isPermanentlyDenied) {
        _errorMessage = 'Microphone permission is permanently denied. Please enable it in Settings.';
        _updateState(VoiceSosState.permissionPermanentlyDenied);
        return false;
      }
      if (!reqResult.isGranted) {
        _errorMessage = 'Microphone permission is required to detect emergency keywords.';
        _updateState(VoiceSosState.permissionRequired);
        return false;
      }
    }

    // 2. Initialize speech-to-text
    try {
      final available = await _speechToText.initialize(
        onError: _handleSpeechError,
        onStatus: _handleSpeechStatus,
        debugLogging: kDebugMode,
      );

      if (!available) {
        _errorMessage = 'Speech recognition is not available on this device.';
        _updateState(VoiceSosState.unavailable);
        return false;
      }

      _isInitialized = true;
      _updateState(VoiceSosState.idle);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to initialize speech recognition: $e';
      _updateState(VoiceSosState.error);
      return false;
    }
  }

  // ── Start / Stop Listening ─────────────────────────────────────────────────

  /// Starts listening for emergency keywords.
  Future<bool> startListening() async {
    if (_isTriggerLocked) {
      debugPrint('⚠️ VoiceSosService: Trigger locked, ignoring startListening');
      return false;
    }

    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    if (_speechToText.isListening) {
      _updateState(VoiceSosState.listening);
      return true;
    }

    _recognizedText = '';
    _lastDetectedPhrase = null;
    _errorMessage = null;
    onTextChanged?.call(_recognizedText);

    try {
      await _speechToText.listen(
        onResult: _handleSpeechResult,
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.confirmation,
          pauseFor: const Duration(seconds: 3),
          cancelOnError: false,
          partialResults: true,
        ),
      );

      _updateState(VoiceSosState.listening);
      return true;
    } catch (e) {
      _errorMessage = 'Could not start voice listening: $e';
      _updateState(VoiceSosState.error);
      return false;
    }
  }

  /// Stops microphone listening.
  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (e) {
      debugPrint('⚠️ VoiceSosService.stopListening error: $e');
    } finally {
      if (_state == VoiceSosState.listening) {
        _updateState(VoiceSosState.idle);
      }
    }
  }

  /// Manually cancel recognition immediately.
  Future<void> cancel() async {
    try {
      await _speechToText.cancel();
    } catch (_) {}
    if (_state != VoiceSosState.triggeringSos && _state != VoiceSosState.emergencyDetected) {
      _updateState(VoiceSosState.idle);
    }
  }

  // ── Trigger Lock Management ────────────────────────────────────────────────

  /// Locks voice SOS to prevent duplicate triggers while an emergency is running.
  void lockTrigger() {
    _isTriggerLocked = true;
  }

  /// Unlocks voice SOS after emergency is resolved or handled.
  void unlockTrigger() {
    _isTriggerLocked = false;
    if (_state == VoiceSosState.emergencyDetected || _state == VoiceSosState.sosTriggered) {
      _updateState(VoiceSosState.idle);
    }
  }

  /// Updates state manually (used by provider during SOS execution).
  void setSosExecutingState() {
    _updateState(VoiceSosState.triggeringSos);
  }

  /// Updates state manually when SOS execution finishes.
  void setSosCompletedState() {
    _updateState(VoiceSosState.sosTriggered);
  }

  // ── Result & Error Handlers ────────────────────────────────────────────────

  void _handleSpeechResult(SpeechRecognitionResult result) {
    _recognizedText = result.recognizedWords;
    onTextChanged?.call(_recognizedText);

    if (_isTriggerLocked) return;

    final matched = matchEmergencyPhrase(_recognizedText, phrases: _emergencyPhrases);
    if (matched != null) {
      _isTriggerLocked = true;
      _lastDetectedPhrase = matched;
      _updateState(VoiceSosState.emergencyDetected);

      // Stop listening immediately to release the microphone
      stopListening();

      // Notify caller / provider of emergency detection
      onEmergencyDetected?.call(matched);
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    debugPrint('⚠️ VoiceSosService speech error: ${error.errorMsg} (${error.permanent})');
    if (_state == VoiceSosState.emergencyDetected ||
        _state == VoiceSosState.triggeringSos ||
        _state == VoiceSosState.sosTriggered) {
      return;
    }

    // Common non-fatal errors (e.g. timeout with no speech)
    if (error.errorMsg == 'error_no_match' || error.errorMsg == 'error_speech_timeout') {
      return;
    }

    _errorMessage = error.errorMsg;
    onError?.call(error.errorMsg);
  }

  void _handleSpeechStatus(String status) {
    debugPrint('ℹ️ VoiceSosService speech status: $status');
    if (status == 'notListening' && _state == VoiceSosState.listening && !_isTriggerLocked) {
      _updateState(VoiceSosState.idle);
    }
  }

  void _updateState(VoiceSosState newState) {
    _state = newState;
    onStateChanged?.call(newState);
  }

  // ── Centralized Phrase Matching Algorithm ──────────────────────────────────

  /// Pure helper to check if [rawText] contains any configured emergency phrase.
  ///
  /// Features:
  /// - Case-insensitive.
  /// - Strips punctuation (`!`, `?`, `,`, `.`, etc.).
  /// - Token/word boundary enforcement (`\b`).
  /// - Substring / partial words like "helper" or "helpful" will **NOT** match "help".
  ///
  /// Returns the matched emergency phrase (lowercase) or `null` if no match.
  static String? matchEmergencyPhrase(
    String rawText, {
    List<String>? phrases,
  }) {
    if (rawText.trim().isEmpty) return null;

    // Prioritize longer/multi-word phrases (e.g. "nari suraksha help" before "help")
    final targetPhrases = List<String>.from(phrases ?? defaultEmergencyPhrases)
      ..sort((a, b) => b.length.compareTo(a.length));
    final normalized = normalizeText(rawText);

    if (normalized.isEmpty) return null;

    // Tokenize into words for strict word-boundary matching
    final tokens = normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    for (final phrase in targetPhrases) {
      final normalizedPhrase = normalizeText(phrase);
      if (normalizedPhrase.isEmpty) continue;

      final phraseWords = normalizedPhrase.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

      if (phraseWords.isEmpty) continue;

      if (phraseWords.length == 1) {
        // Single word phrase: must match an exact token in tokens list
        final word = phraseWords.first;
        if (tokens.contains(word)) {
          return phrase;
        }
      } else {
        // Multi-word phrase: must appear as contiguous tokens in the token list
        if (_containsContiguousWords(tokens, phraseWords)) {
          return phrase;
        }
      }
    }

    return null;
  }

  /// Normalizes string: lowercases, removes punctuation, trims and collapses spaces.
  static String normalizeText(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[^\w\s']|_"), ' ') // replace punctuation with spaces
        .replaceAll(RegExp(r"\s+"), ' ')         // collapse multiple spaces
        .trim();
  }

  static bool _containsContiguousWords(List<String> textWords, List<String> phraseWords) {
    if (textWords.length < phraseWords.length) return false;

    for (int i = 0; i <= textWords.length - phraseWords.length; i++) {
      bool match = true;
      for (int j = 0; j < phraseWords.length; j++) {
        if (textWords[i + j] != phraseWords[j]) {
          match = false;
          break;
        }
      }
      if (match) return true;
    }
    return false;
  }

  // ── Disposal ───────────────────────────────────────────────────────────────

  /// Disposes of the service and releases speech resources.
  void dispose() {
    stopListening();
    cancel();
  }
}
