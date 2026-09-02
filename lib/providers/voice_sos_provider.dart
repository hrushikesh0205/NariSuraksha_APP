import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/core/services/voice_sos_service.dart';
import 'package:nari_suraksha/providers/dashboard_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VoiceSosProvider
// ─────────────────────────────────────────────────────────────────────────────

/// State container managing Voice SOS keyword detection and automatic SOS dispatch.
///
/// Ties [VoiceSosService] directly into the existing [DashboardProvider.triggerSos]
/// pipeline with deduplication, trigger locking, and lifecycle safety.
class VoiceSosProvider extends ChangeNotifier {
  VoiceSosProvider({
    VoiceSosService? voiceSosService,
    DashboardProvider? dashboardProvider,
  })  : _service = voiceSosService ?? VoiceSosService(),
        _dashboardProvider = dashboardProvider {
    _initServiceListeners();
  }

  final VoiceSosService _service;
  DashboardProvider? _dashboardProvider;

  SosTriggerResult? _lastSosResult;
  DateTime? _lastSosTime;

  // ── Getters ────────────────────────────────────────────────────────────────

  VoiceSosState get state => _service.state;
  String get recognizedText => _service.recognizedText;
  String? get lastDetectedPhrase => _service.lastDetectedPhrase;
  String? get errorMessage => _service.errorMessage;
  bool get isListening => _service.isListening;
  bool get isTriggerLocked => _service.isTriggerLocked;
  bool get isInitialized => _service.isInitialized;
  List<String> get emergencyPhrases => _service.emergencyPhrases;
  SosTriggerResult? get lastSosResult => _lastSosResult;
  DateTime? get lastSosTime => _lastSosTime;

  /// Updates the reference to [DashboardProvider] if re-provided in proxy provider.
  void updateDashboardProvider(DashboardProvider? dashboardProvider) {
    _dashboardProvider = dashboardProvider;
  }

  // ── Service Listener Setup ─────────────────────────────────────────────────

  void _initServiceListeners() {
    _service.onStateChanged = (_) {
      notifyListeners();
    };

    _service.onTextChanged = (_) {
      notifyListeners();
    };

    _service.onError = (_) {
      notifyListeners();
    };

    _service.onEmergencyDetected = (phrase) async {
      await _handleEmergencyDetected(phrase);
    };
  }

  // ── Emergency Handler ──────────────────────────────────────────────────────

  Future<void> _handleEmergencyDetected(String phrase) async {
    debugPrint('🚨 VoiceSosProvider: Emergency keyword detected: "$phrase"');

    _service.setSosExecutingState();
    notifyListeners();

    if (_dashboardProvider == null) {
      debugPrint('⚠️ VoiceSosProvider: DashboardProvider is null, cannot execute triggerSos');
      _service.unlockTrigger();
      notifyListeners();
      return;
    }

    try {
      final result = await _dashboardProvider!.triggerSos(triggerSource: 'Voice SOS');
      _lastSosResult = result;
      _lastSosTime = DateTime.now();

      if (result.isSuccess) {
        debugPrint('✅ VoiceSosProvider: SOS successfully dispatched via voice keyword!');
        _service.setSosCompletedState();
      } else {
        debugPrint('❌ VoiceSosProvider: SOS failed: ${result.failureReason}');
        _service.unlockTrigger();
      }
    } catch (e) {
      debugPrint('❌ VoiceSosProvider: Exception during SOS trigger: $e');
      _service.unlockTrigger();
    } finally {
      notifyListeners();
    }
  }

  // ── Public Controls ────────────────────────────────────────────────────────

  /// Initializes speech recognition and permissions.
  Future<bool> initialize() async {
    final ok = await _service.initialize();
    notifyListeners();
    return ok;
  }

  /// Starts listening for emergency keywords.
  Future<bool> startListening() async {
    final ok = await _service.startListening();
    notifyListeners();
    return ok;
  }

  /// Stops microphone listening.
  Future<void> stopListening() async {
    await _service.stopListening();
    notifyListeners();
  }

  /// Toggles between listening and idle.
  Future<void> toggleListening() async {
    if (isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  /// Resets trigger lock and clears previous SOS results so user can listen again.
  void reset() {
    _lastSosResult = null;
    _lastSosTime = null;
    _service.unlockTrigger();
    notifyListeners();
  }

  /// Updates configured emergency phrases.
  void setEmergencyPhrases(List<String> phrases) {
    _service.setEmergencyPhrases(phrases);
    notifyListeners();
  }

  // ── Disposal ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
