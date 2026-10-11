import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SosRepository
// ─────────────────────────────────────────────────────────────────────────────

/// Data-access layer for the `sos_history` Firestore collection.
class SosRepository {
  SosRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('sos_history');

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Writes a new SOS record to Firestore and returns the document ID.
  ///
  /// If [docId] is provided, uses `.doc(docId).set()` (idempotent — safe to
  /// call twice with the same ID during sync retry). Otherwise, generates a
  /// new Firestore document ID via `.add()`.
  Future<String> createSosRecord(SosRecordModel record, {String? docId}) async {
    try {
      if (docId != null && docId.isNotEmpty) {
        await _collection.doc(docId).set(record.toMap());
        return docId;
      }
      final ref = await _collection.add(record.toMap());
      return ref.id;
    } on FirebaseException catch (e) {
      throw Exception('Failed to create SOS record [${e.code}]: ${e.message}');
    }
  }

  /// Updates the status of an existing SOS record.
  Future<void> updateStatus(String docId, SosStatus status) async {
    try {
      await _collection.doc(docId).update({
        'status': status.value,
        'resolvedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Failed to update SOS status [${e.code}]: ${e.message}');
    }
  }

  /// Updates the escalation level and records the corresponding priority alert timestamp.
  Future<void> updateEscalationLevel(
    String docId, {
    required String level,
    DateTime? alertedAt,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'escalationLevel': level,
      };
      if (level == 'medium') {
        updateData['mediumAlertedAt'] = alertedAt != null
            ? Timestamp.fromDate(alertedAt)
            : FieldValue.serverTimestamp();
      } else if (level == 'low') {
        updateData['lowAlertedAt'] = alertedAt != null
            ? Timestamp.fromDate(alertedAt)
            : FieldValue.serverTimestamp();
      }
      await _collection.doc(docId).update(updateData);
    } on FirebaseException catch (e) {
      throw Exception(
          'Failed to update SOS escalation level [${e.code}]: ${e.message}');
    }
  }

  /// Updates the per-contact SMS send results in the SOS record.
  Future<void> updateSmsResults(
    String docId,
    Map<String, String> smsResults,
  ) async {
    try {
      await _collection.doc(docId).update({
        'smsResults': smsResults,
      });
    } on FirebaseException catch (e) {
      throw Exception(
          'Failed to update SMS results [${e.code}]: ${e.message}');
    }
  }

  /// Updates whether the user authorized calling police at worst-case stage.
  Future<void> updatePoliceCallStatus(
    String docId, {
    required bool authorized,
  }) async {
    try {
      await _collection.doc(docId).update({
        'policeCallAuthorized': authorized,
      });
    } on FirebaseException catch (e) {
      throw Exception(
          'Failed to update police call status [${e.code}]: ${e.message}');
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Fetches the [limit] most recent SOS records for a given user.
  ///
  /// NOTE: We intentionally omit `.orderBy('timestamp')` here to avoid
  /// requiring a Firestore composite index on (userId, timestamp).
  /// Records are instead sorted in memory after fetching — this is safe
  /// because we only ever fetch a small [limit] (default 5).
  Future<List<SosRecordModel>> getRecentSos(String uid, {int limit = 5}) async {
    try {
      final snap = await _collection
          .where('userId', isEqualTo: uid)
          .limit(limit)
          .get();
      final records = snap.docs
          .map((d) => SosRecordModel.fromFirestore(
              d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      // Sort newest-first in Dart — avoids composite index requirement.
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return records;
    } on FirebaseException catch (e) {
      throw Exception('Failed to fetch SOS history [${e.code}]: ${e.message}');
    }
  }
}
