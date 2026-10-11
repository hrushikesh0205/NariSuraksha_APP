import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/core/services/auth_service.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/local_sos_repository.dart';
import 'package:nari_suraksha/repositories/sos_repository.dart';

// -----------------------------------------------------------------------------
// SosProvider
// -----------------------------------------------------------------------------

/// Manages SOS history and the resolve-emergency flow.
class SosProvider extends ChangeNotifier {
  SosProvider({
    SosRepository? sosRepository,
    ActivityRepository? activityRepository,
    AuthService? authService,
    LocalSosRepository? localSosRepository,
  })  : _sosRepository = sosRepository ?? SosRepository(),
        _activityRepository = activityRepository ?? ActivityRepository(),
        _authService = authService ?? AuthService(),
        _localSosRepository = localSosRepository ?? LocalSosRepository();

  final SosRepository _sosRepository;
  final ActivityRepository _activityRepository;
  final AuthService _authService;
  final LocalSosRepository _localSosRepository;

  // -- State ------------------------------------------------------------------

  List<SosRecordModel> _history = [];
  bool _isLoadingHistory = false;
  String? _historyError;

  bool _isResolving = false;
  String? _resolveError;
  bool _resolveSuccess = false;

  List<SosRecordModel> get history => _history;
  bool get isLoadingHistory => _isLoadingHistory;
  String? get historyError => _historyError;

  bool get isResolving => _isResolving;
  String? get resolveError => _resolveError;
  bool get resolveSuccess => _resolveSuccess;

  // -- Load History ------------------------------------------------------------

  Future<void> loadHistory() async {
    final uid = _authService.firebaseUser?.uid;
    if (uid == null) {
      _history = [];
      _historyError = null;
      notifyListeners();
      return;
    }

    _isLoadingHistory = true;
    _historyError = null;
    notifyListeners();

    try {
      // Attempt Firestore first
      final firestoreHistory = await _sosRepository.getRecentSos(uid, limit: 5);

      // Also get pending-sync local records not yet in Firestore
      final localPending = await _localSosRepository.getPendingHistoryRecords(uid);
      final pendingModels = await _localSosRepository.getHistoryRecords(uid, limit: 5);

      // Merge: Firestore records take precedence; local pending records are appended
      // if they don't have a corresponding Firestore doc ID yet.
      final firestoreIds = firestoreHistory.map((r) => r.id).whereType<String>().toSet();
      final pendingOnly = pendingModels.where((r) {
        // Only add local pending records not already in Firestore list
        return localPending.any((p) => p.localId == r.id) &&
            !firestoreIds.contains(r.id);
      }).toList();

      final merged = [...firestoreHistory, ...pendingOnly];
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      _history = merged.take(5).toList();
      _historyError = null;
    } catch (e, st) {
      debugPrint('ðŸ”¥ SosProvider.loadHistory Firestore error: $e\n$st');
      // Offline fallback: load from local DB
      try {
        _history = await _localSosRepository.getHistoryRecords(uid, limit: 5);
        if (_history.isNotEmpty) {
          _historyError = null; // Local data available
          debugPrint('ðŸ“¦ SosProvider: loaded ${_history.length} records from local DB (offline fallback)');
        } else {
          _historyError = _friendlyError(e);
        }
      } catch (localErr) {
        _historyError = _friendlyError(e);
        _history = [];
      }
    } finally {
      _isLoadingHistory = false;
      notifyListeners();
    }
  }

  // -- Resolve Emergency -------------------------------------------------------

  Future<bool> resolveLatest(String docId) async {
    final uid = _authService.firebaseUser?.uid;
    if (uid == null) {
      _resolveError = 'Not signed in.';
      notifyListeners();
      return false;
    }

    _isResolving = true;
    _resolveError = null;
    _resolveSuccess = false;
    notifyListeners();

    try {
      await _sosRepository.updateStatus(docId, SosStatus.resolved);
      await _activityRepository.logActivity(
        uid: uid,
        type: ActivityLogType.locationShared,
        description: 'SOS emergency resolved.',
      );
      _resolveSuccess = true;
      await loadHistory();
      return true;
    } catch (e) {
      _resolveError = _friendlyError(e);
      return false;
    } finally {
      _isResolving = false;
      notifyListeners();
    }
  }

  void clearResolveState() {
    _resolveError = null;
    _resolveSuccess = false;
    notifyListeners();
  }

  // -- Helpers ----------------------------------------------------------------

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('unavailable')) {
      return 'No internet connection. Check your data connection and retry.';
    }
    if (msg.contains('permission-denied') || msg.contains('permission_denied')) {
      return 'Access denied. Please contact support.';
    }
    if (msg.contains('failed-precondition') || msg.contains('failed_precondition')) {
      // Usually a missing Firestore index â€” in-memory sort should prevent this.
      return 'Unable to load history. Please refresh.';
    }
    if (msg.contains('not-found') || msg.contains('no document')) {
      return 'SOS record not found. It may have already been deleted.';
    }
    if (msg.contains('unauthenticated') || msg.contains('not signed in')) {
      return 'Session expired. Please sign in again.';
    }
    return 'Unable to load SOS history. Please tap Refresh.';
  }
}
