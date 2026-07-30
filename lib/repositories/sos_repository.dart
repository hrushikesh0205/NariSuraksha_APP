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

  /// Writes a new SOS record to Firestore and returns the generated document ID.
  Future<String> createSosRecord(SosRecordModel record) async {
    try {
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

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Fetches the [limit] most recent SOS records for a given user.
  Future<List<SosRecordModel>> getRecentSos(String uid, {int limit = 5}) async {
    try {
      final snap = await _collection
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => SosRecordModel.fromFirestore(
              d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
    } on FirebaseException catch (e) {
      throw Exception('Failed to fetch SOS history [${e.code}]: ${e.message}');
    }
  }
}
