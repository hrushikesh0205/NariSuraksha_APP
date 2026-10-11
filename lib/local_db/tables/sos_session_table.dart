import 'package:drift/drift.dart';

// -----------------------------------------------------------------------------
// LocalSosSessionTable
// -----------------------------------------------------------------------------

/// Stores the single active SOS session locally for offline continuity.
///
/// Only one row per userId is expected at a time.
/// This allows the app to resume an active SOS after restart even without
/// Firestore connectivity.
class LocalSosSessionTable extends Table {
  /// Stable SOS doc ID (used for Firestore sync deduplication).
  TextColumn get sosDocId => text()();

  /// UID of the user who triggered the SOS.
  TextColumn get userId => text()();

  /// WGS-84 latitude.
  RealColumn get latitude => real().withDefault(const Constant(0.0))();

  /// WGS-84 longitude.
  RealColumn get longitude => real().withDefault(const Constant(0.0))();

  /// ISO 8601 timestamp when SOS was triggered (anchors escalation timing).
  TextColumn get startedAt => text()();

  /// Current escalation level: 'high' | 'medium' | 'low'
  TextColumn get currentLevel => text().withDefault(const Constant('high'))();

  /// Whether the SOS is resolved.
  BoolColumn get isResolved => boolean().withDefault(const Constant(false))();

  /// ISO 8601 timestamp of resolution (nullable).
  TextColumn get resolvedAt => text().nullable()();

  /// Comma-separated normalized phone numbers already alerted (deduplication).
  TextColumn get alertedPhones => text().withDefault(const Constant(''))();

  /// Comma-separated alerted priorities: 'high,medium,low'
  TextColumn get alertedPriorities => text().withDefault(const Constant('high'))();

  /// ISO 8601 timestamp of last update.
  TextColumn get updatedAt => text()();

  /// Sync status: 'pending' | 'synced'
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();

  /// How SOS was triggered: 'button' | 'voice' | 'shake'
  TextColumn get triggerSource => text().withDefault(const Constant('button'))();

  @override
  Set<Column> get primaryKey => {sosDocId};
}
