import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:nari_suraksha/local_db/local_database.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LocalSosRepository
// ─────────────────────────────────────────────────────────────────────────────

/// Manages the local active SOS session and SOS history records.
///
/// Priority order for data availability:
/// - Local DB: always readable (offline + online)
/// - Firestore: only when online
class LocalSosRepository {
  LocalSosRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  final AppDatabase _db;

  // ── Active Session ─────────────────────────────────────────────────────────

  /// Saves or updates the active SOS session locally.
  Future<void> saveActiveSession({
    required String sosDocId,
    required String userId,
    required double latitude,
    required double longitude,
    required DateTime startedAt,
    required String currentLevel,
    bool isResolved = false,
    DateTime? resolvedAt,
    Set<String> alertedPhones = const {},
    Set<String> alertedPriorities = const {'high'},
    String triggerSource = 'button',
    String syncStatus = 'pending',
  }) async {
    try {
      await _db.into(_db.localSosSessionTable).insertOnConflictUpdate(
            LocalSosSessionTableCompanion(
              sosDocId: Value(sosDocId),
              userId: Value(userId),
              latitude: Value(latitude),
              longitude: Value(longitude),
              startedAt: Value(startedAt.toIso8601String()),
              currentLevel: Value(currentLevel),
              isResolved: Value(isResolved),
              resolvedAt: Value(resolvedAt?.toIso8601String()),
              alertedPhones: Value(alertedPhones.join(',')),
              alertedPriorities: Value(alertedPriorities.join(',')),
              triggerSource: Value(triggerSource),
              updatedAt: Value(DateTime.now().toIso8601String()),
              syncStatus: Value(syncStatus),
            ),
          );
      debugPrint('📦 LocalSosRepository: saved active session $sosDocId');
    } catch (e) {
      debugPrint('⚠️ LocalSosRepository.saveActiveSession error: $e');
    }
  }

  /// Returns the active (unresolved) SOS session for [userId], or null if none.
  Future<LocalSosSessionTableData?> getActiveSession(String userId) async {
    try {
      final query = _db.select(_db.localSosSessionTable)
        ..where((s) => s.userId.equals(userId) & s.isResolved.equals(false));
      final rows = await query.get();
      return rows.isNotEmpty ? rows.first : null;
    } catch (e) {
      debugPrint('⚠️ LocalSosRepository.getActiveSession error: $e');
      return null;
    }
  }

  /// Marks the active session for [sosDocId] as resolved.
  Future<void> markSessionResolved(String sosDocId) async {
    try {
      await (_db.update(_db.localSosSessionTable)
            ..where((s) => s.sosDocId.equals(sosDocId)))
          .write(LocalSosSessionTableCompanion(
            isResolved: const Value(true),
            resolvedAt: Value(DateTime.now().toIso8601String()),
            updatedAt: Value(DateTime.now().toIso8601String()),
          ));
    } catch (e) {
      debugPrint('⚠️ LocalSosRepository.markSessionResolved error: $e');
    }
  }

  /// Updates the alerted phones and current escalation level for [sosDocId].
  Future<void> updateSessionEscalation({
    required String sosDocId,
    required String currentLevel,
    required Set<String> alertedPhones,
    required Set<String> alertedPriorities,
  }) async {
    try {
      await (_db.update(_db.localSosSessionTable)
            ..where((s) => s.sosDocId.equals(sosDocId)))
          .write(LocalSosSessionTableCompanion(
            currentLevel: Value(currentLevel),
            alertedPhones: Value(alertedPhones.join(',')),
            alertedPriorities: Value(alertedPriorities.join(',')),
            updatedAt: Value(DateTime.now().toIso8601String()),
          ));
    } catch (e) {
      debugPrint('⚠️ LocalSosRepository.updateSessionEscalation error: $e');
    }
  }

  /// Deletes all resolved sessions for [userId] (cleanup).
  Future<void> cleanupResolvedSessions(String userId) async {
    try {
      await (_db.delete(_db.localSosSessionTable)
            ..where((s) => s.userId.equals(userId) & s.isResolved.equals(true)))
          .go();
    } catch (e) {
      debugPrint('⚠️ LocalSosRepository.cleanupResolvedSessions error: $e');
    }
  }

  // ── SOS History ───────────────────────────────────────────────────────────

  /// Inserts a new SOS history record with [syncStatus] = 'pending'.
  Future<void> insertHistoryRecord({
    required String localId,
    required String userId,
    required double latitude,
    required double longitude,
    required DateTime startedAt,
    String status = 'active',
    String escalationLevel = 'high',
    String triggerSource = 'button',
  }) async {
    try {
      await _db.into(_db.localSosHistoryTable).insertOnConflictUpdate(
            LocalSosHistoryTableCompanion(
              localId: Value(localId),
              userId: Value(userId),
              latitude: Value(latitude),
              longitude: Value(longitude),
              startedAt: Value(startedAt.toIso8601String()),
              status: Value(status),
              escalationLevel: Value(escalationLevel),
              triggerSource: Value(triggerSource),
              syncStatus: const Value('pending'),
            ),
          );
      debugPrint('📦 LocalSosRepository: inserted history record $localId');
    } catch (e) {
      debugPrint('⚠️ LocalSosRepository.insertHistoryRecord error: $e');
    }
  }

  /// Updates a history record after Firestore sync.
  Future<void> markHistorySynced(String localId, String firestoreDocId) async {
    try {
      await (_db.update(_db.localSosHistoryTable)
            ..where((h) => h.localId.equals(localId)))
          .write(LocalSosHistoryTableCompanion(
            firestoreDocId: Value(firestoreDocId),
            syncStatus: const Value('synced'),
          ));
    } catch (e) {
      debugPrint('⚠️ LocalSosRepository.markHistorySynced error: $e');
    }
  }

  /// Updates history record escalation and resolution data.
  Future<void> updateHistoryRecord({
    required String localId,
    String? status,
    String? escalationLevel,
    DateTime? resolvedAt,
    DateTime? highAlertedAt,
    DateTime? mediumAlertedAt,
    DateTime? lowAlertedAt,
    Map<String, String>? smsResults,
    bool? policeCallAuthorized,
  }) async {
    try {
      await (_db.update(_db.localSosHistoryTable)
            ..where((h) => h.localId.equals(localId)))
          .write(LocalSosHistoryTableCompanion(
            status: status != null ? Value(status) : const Value.absent(),
            escalationLevel: escalationLevel != null
                ? Value(escalationLevel)
                : const Value.absent(),
            resolvedAt: resolvedAt != null
                ? Value(resolvedAt.toIso8601String())
                : const Value.absent(),
            highAlertedAt: highAlertedAt != null
                ? Value(highAlertedAt.toIso8601String())
                : const Value.absent(),
            mediumAlertedAt: mediumAlertedAt != null
                ? Value(mediumAlertedAt.toIso8601String())
                : const Value.absent(),
            lowAlertedAt: lowAlertedAt != null
                ? Value(lowAlertedAt.toIso8601String())
                : const Value.absent(),
            smsResultsJson: smsResults != null
                ? Value(jsonEncode(smsResults))
                : const Value.absent(),
            policeCallAuthorized: policeCallAuthorized != null
                ? Value(policeCallAuthorized)
                : const Value.absent(),
          ));
    } catch (e) {
      debugPrint('⚠️ LocalSosRepository.updateHistoryRecord error: $e');
    }
  }

  /// Returns all pending (not-yet-synced) SOS history records for [userId].
  Future<List<LocalSosHistoryTableData>> getPendingHistoryRecords(
      String userId) async {
    try {
      return await (_db.select(_db.localSosHistoryTable)
            ..where((h) =>
                h.userId.equals(userId) & h.syncStatus.equals('pending')))
          .get();
    } catch (e) {
      debugPrint('⚠️ LocalSosRepository.getPendingHistoryRecords error: $e');
      return [];
    }
  }

  /// Returns all local SOS history records for [userId], newest first.
  Future<List<SosRecordModel>> getHistoryRecords(String userId,
      {int limit = 5}) async {
    try {
      final query = _db.select(_db.localSosHistoryTable)
        ..where((h) => h.userId.equals(userId))
        ..orderBy([(h) => OrderingTerm.desc(h.startedAt)])
        ..limit(limit);

      final rows = await query.get();
      return rows.map(_rowToModel).toList();
    } catch (e) {
      debugPrint('⚠️ LocalSosRepository.getHistoryRecords error: $e');
      return [];
    }
  }

  // ── Conversion ────────────────────────────────────────────────────────────

  SosRecordModel _rowToModel(LocalSosHistoryTableData row) {
    Map<String, String>? smsResults;
    if (row.smsResultsJson != null) {
      try {
        final decoded = jsonDecode(row.smsResultsJson!) as Map;
        smsResults = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
      } catch (_) {}
    }

    return SosRecordModel(
      id: row.firestoreDocId ?? row.localId,
      userId: row.userId,
      latitude: row.latitude,
      longitude: row.longitude,
      timestamp: DateTime.tryParse(row.startedAt) ?? DateTime.now(),
      status: _parseStatus(row.status),
      escalationLevel: row.escalationLevel,
      resolvedAt:
          row.resolvedAt != null ? DateTime.tryParse(row.resolvedAt!) : null,
      highAlertedAt: row.highAlertedAt != null
          ? DateTime.tryParse(row.highAlertedAt!)
          : null,
      mediumAlertedAt: row.mediumAlertedAt != null
          ? DateTime.tryParse(row.mediumAlertedAt!)
          : null,
      lowAlertedAt: row.lowAlertedAt != null
          ? DateTime.tryParse(row.lowAlertedAt!)
          : null,
      smsResults: smsResults,
      policeCallAuthorized: row.policeCallAuthorized,
    );
  }

  SosStatus _parseStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'resolved':
        return SosStatus.resolved;
      case 'cancelled':
        return SosStatus.cancelled;
      default:
        return SosStatus.active;
    }
  }
}
