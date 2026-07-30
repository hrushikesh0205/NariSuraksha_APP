import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ActivityRepository
// ─────────────────────────────────────────────────────────────────────────────

/// Data-access layer for the `activity_logs` Firestore collection.
///
/// Drives the "Recent Alerts" section on the Home Dashboard.
class ActivityRepository {
  ActivityRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('activity_logs');

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Appends an activity log entry for [uid].
  Future<void> logActivity({
    required String uid,
    required ActivityLogType type,
    required String description,
  }) async {
    try {
      final log = ActivityLogModel(
        userId: uid,
        type: type,
        description: description,
        timestamp: DateTime.now(),
      );
      await _collection.add(log.toMap());
    } on FirebaseException catch (e) {
      // Non-fatal: silently swallow logging failures so they don't disrupt UX.
      // ignore: avoid_print
      print('ActivityRepository.logActivity failed [${e.code}]: ${e.message}');
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Fetches the [limit] most recent activity logs for [uid].
  Future<List<ActivityLogModel>> getRecentActivity(
    String uid, {
    int limit = 10,
  }) async {
    try {
      final snap = await _collection
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => ActivityLogModel.fromFirestore(
              d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } on FirebaseException catch (e) {
      throw Exception(
          'Failed to fetch activity logs [${e.code}]: ${e.message}');
    }
  }

  /// Returns a live [Stream] of the [limit] most recent activity logs for [uid].
  ///
  /// Use with [StreamBuilder] in the UI for real-time updates.
  Stream<List<ActivityLogModel>> watchRecentActivity(
    String uid, {
    int limit = 10,
  }) {
    return _collection
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ActivityLogModel.fromFirestore(
                d as DocumentSnapshot<Map<String, dynamic>>))
            .toList());
  }
}
