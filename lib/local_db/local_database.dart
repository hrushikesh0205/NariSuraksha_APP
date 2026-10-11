import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/contacts_table.dart';
import 'tables/sos_session_table.dart';
import 'tables/sos_history_table.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Generated part — run: dart run build_runner build
// ─────────────────────────────────────────────────────────────────────────────
part 'local_database.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppDatabase
// ─────────────────────────────────────────────────────────────────────────────

/// Singleton local SQLite database for offline-first safety-critical data.
///
/// Tables:
/// - [LocalContactsTable] — emergency contacts cache for offline SMS dispatch.
/// - [LocalSosSessionTable] — single active SOS session for app-restart recovery.
/// - [LocalSosHistoryTable] — pending-sync SOS history records.
///
/// Usage:
/// ```dart
/// final db = AppDatabase.instance;
/// ```
@DriftDatabase(tables: [LocalContactsTable, LocalSosSessionTable, LocalSosHistoryTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase._() : super(_openConnection());

  static final AppDatabase instance = AppDatabase._();

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Future migrations go here.
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Database Connection
// ─────────────────────────────────────────────────────────────────────────────

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'nari_suraksha_offline.db'));
    debugPrint('📦 AppDatabase: opening at ${file.path}');
    return NativeDatabase.createInBackground(file);
  });
}
