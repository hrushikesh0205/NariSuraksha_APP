import 'package:flutter_test/flutter_test.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/providers/sos_escalation_provider.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/sos_repository.dart';

// ── Test Fakes ───────────────────────────────────────────────────────────────

class FakeSosRepository implements SosRepository {
  final List<SosRecordModel> records = [];
  String? updatedDocId;
  SosStatus? updatedStatus;
  String? updatedLevel;
  DateTime? updatedAlertedAt;

  @override
  Future<String> createSosRecord(SosRecordModel record) async {
    records.add(record);
    return 'fake_sos_id_${records.length}';
  }

  @override
  Future<void> updateStatus(String docId, SosStatus status) async {
    updatedDocId = docId;
    updatedStatus = status;
  }

  @override
  Future<void> updateEscalationLevel(
    String docId, {
    required String level,
    DateTime? alertedAt,
  }) async {
    updatedDocId = docId;
    updatedLevel = level;
    updatedAlertedAt = alertedAt;
  }

  @override
  Future<List<SosRecordModel>> getRecentSos(String uid, {int limit = 5}) async {
    return records;
  }
}

class FakeActivityRepository implements ActivityRepository {
  final List<String> logs = [];

  @override
  Future<void> logActivity({
    required String uid,
    required ActivityLogType type,
    required String description,
  }) async {
    logs.add(description);
  }

  @override
  Future<List<ActivityLogModel>> getRecentActivity(
    String uid, {
    int limit = 10,
  }) async {
    return [];
  }

  @override
  Stream<List<ActivityLogModel>> watchRecentActivity(
    String uid, {
    int limit = 10,
  }) {
    return const Stream.empty();
  }
}

void main() {
  group('SosRecordModel Escalation Schema Tests', () {
    test('SosRecordModel default fields and escalationLevel', () {
      final now = DateTime.now();
      final record = SosRecordModel(
        userId: 'user_test',
        latitude: 19.0760,
        longitude: 72.8777,
        timestamp: now,
        status: SosStatus.active,
        escalationLevel: 'high',
        highAlertedAt: now,
      );

      expect(record.status, SosStatus.active);
      expect(record.escalationLevel, 'high');
      expect(record.highAlertedAt, now);
      expect(record.mediumAlertedAt, isNull);
      expect(record.lowAlertedAt, isNull);
      expect(record.resolvedAt, isNull);
    });

    test('SosRecordModel toMap() includes escalation metadata', () {
      final now = DateTime.now();
      final record = SosRecordModel(
        userId: 'user_test',
        latitude: 19.0760,
        longitude: 72.8777,
        timestamp: now,
        status: SosStatus.resolved,
        escalationLevel: 'medium',
        resolvedAt: now,
      );

      final map = record.toMap();
      expect(map['userId'], 'user_test');
      expect(map['latitude'], 19.0760);
      expect(map['longitude'], 72.8777);
      expect(map['status'], 'resolved');
      expect(map['escalationLevel'], 'medium');
      expect(map['resolvedAt'], isNotNull);
    });

    test('SosRecordModel copyWith updates escalationLevel and timestamps', () {
      final start = DateTime.now();
      final resolved = start.add(const Duration(minutes: 3));

      final initial = SosRecordModel(
        userId: 'user_test',
        latitude: 19.0760,
        longitude: 72.8777,
        timestamp: start,
        status: SosStatus.active,
        escalationLevel: 'high',
      );

      final escalated = initial.copyWith(
        escalationLevel: 'medium',
        mediumAlertedAt: start.add(const Duration(minutes: 2)),
      );
      expect(escalated.escalationLevel, 'medium');
      expect(escalated.mediumAlertedAt, isNotNull);

      final finished = escalated.copyWith(
        status: SosStatus.resolved,
        resolvedAt: resolved,
      );
      expect(finished.status, SosStatus.resolved);
      expect(finished.resolvedAt, resolved);
    });
  });

  group('ActiveSosSession Logic Tests', () {
    test('ActiveSosSession initializes with High priority alerted by default', () {
      final now = DateTime.now();
      final session = ActiveSosSession(
        sosDocId: 'sos_123',
        userId: 'user_123',
        latitude: 19.0760,
        longitude: 72.8777,
        mapsUrl: 'https://maps.google.com/?q=19.0760,72.8777',
        startedAt: now,
      );

      expect(session.sosDocId, 'sos_123');
      expect(session.currentLevel, ContactPriority.high);
      expect(session.isHighAlerted, isTrue);
      expect(session.isMediumAlerted, isFalse);
      expect(session.isLowAlerted, isFalse);
      expect(session.isResolved, isFalse);
    });

    test('ActiveSosSession tracks contact phones and avoids duplicate alerts', () {
      final now = DateTime.now();
      final session = ActiveSosSession(
        sosDocId: 'sos_123',
        userId: 'user_123',
        latitude: 19.0760,
        longitude: 72.8777,
        mapsUrl: 'https://maps.google.com/?q=19.0760,72.8777',
        startedAt: now,
      );

      session.alertedContactPhones.add('919876543210');
      expect(session.alertedContactPhones.contains('919876543210'), isTrue);
      expect(session.alertedContactPhones.contains('919876543211'), isFalse);
    });
  });

  group('SosEscalationProvider Lifecycle & Timer Tests', () {
    late FakeSosRepository fakeSosRepo;
    late FakeActivityRepository fakeActivityRepo;
    late SosEscalationProvider provider;

    setUp(() {
      fakeSosRepo = FakeSosRepository();
      fakeActivityRepo = FakeActivityRepository();
      provider = SosEscalationProvider(
        sosRepository: fakeSosRepo,
        activityRepository: fakeActivityRepo,
      );
    });

    tearDown(() {
      provider.dispose();
    });

    test('startSession initializes active session and ticker', () {
      final session = provider.startSession(
        sosDocId: 'sos_abc',
        userId: 'user_abc',
        latitude: 12.9716,
        longitude: 77.5946,
        mapsUrl: 'https://maps.google.com/?q=12.9716,77.5946',
      );

      expect(provider.hasActiveSession, isTrue);
      expect(provider.activeSession?.sosDocId, 'sos_abc');
      expect(session.currentLevel, ContactPriority.high);
      expect(session.isHighAlerted, isTrue);
    });

    test('Duplicate SOS triggers do NOT create duplicate sessions or reset startedAt', () {
      final originalTime = DateTime.now().subtract(const Duration(minutes: 1));

      final firstSession = provider.startSession(
        sosDocId: 'sos_first',
        userId: 'user_abc',
        latitude: 12.9716,
        longitude: 77.5946,
        mapsUrl: 'https://maps.google.com/?q=12.9716,77.5946',
        startedAt: originalTime,
      );

      // Trigger again while active
      final secondSession = provider.startSession(
        sosDocId: 'sos_second_duplicate',
        userId: 'user_abc',
        latitude: 12.9716,
        longitude: 77.5946,
        mapsUrl: 'https://maps.google.com/?q=12.9716,77.5946',
        startedAt: DateTime.now(),
      );

      expect(secondSession.sosDocId, 'sos_first');
      expect(secondSession.startedAt, originalTime);
      expect(identical(firstSession, secondSession), isTrue);
    });

    test('escalateTo medium updates active session and repository', () async {
      provider.startSession(
        sosDocId: 'sos_escalate_test',
        userId: 'user_abc',
        latitude: 12.9716,
        longitude: 77.5946,
        mapsUrl: 'https://maps.google.com/?q=12.9716,77.5946',
      );

      await provider.escalateTo(ContactPriority.medium);

      expect(provider.activeSession?.currentLevel, ContactPriority.medium);
      expect(provider.activeSession?.isMediumAlerted, isTrue);
      expect(fakeSosRepo.updatedDocId, 'sos_escalate_test');
      expect(fakeSosRepo.updatedLevel, 'medium');
      expect(fakeActivityRepo.logs, contains('SOS escalated to Medium Priority.'));
    });

    test('resolveEmergency marks active session resolved and stops escalation', () async {
      provider.startSession(
        sosDocId: 'sos_resolve_test',
        userId: 'user_abc',
        latitude: 12.9716,
        longitude: 77.5946,
        mapsUrl: 'https://maps.google.com/?q=12.9716,77.5946',
      );

      expect(provider.hasActiveSession, isTrue);

      final success = await provider.resolveEmergency();
      expect(success, isTrue);
      expect(provider.hasActiveSession, isFalse);
      expect(provider.activeSession?.isResolved, isTrue);
      expect(provider.activeSession?.resolvedAt, isNotNull);
      expect(fakeSosRepo.updatedDocId, 'sos_resolve_test');
      expect(fakeSosRepo.updatedStatus, SosStatus.resolved);
      expect(fakeActivityRepo.logs, contains('SOS emergency resolved by user.'));
    });

    test('recordContactAlerted and isContactAlerted normalize phone numbers', () {
      provider.startSession(
        sosDocId: 'sos_phone_test',
        userId: 'user_abc',
        latitude: 12.9716,
        longitude: 77.5946,
        mapsUrl: 'https://maps.google.com/?q=12.9716,77.5946',
      );

      expect(provider.isContactAlerted('+91 98765 43210'), isFalse);

      provider.recordContactAlerted('+91 98765-43210');

      // Verify matching despite formatting differences
      expect(provider.isContactAlerted('+91 98765 43210'), isTrue);
      expect(provider.isContactAlerted('919876543210'), isTrue);
      expect(provider.isContactAlerted('+91 98765 43211'), isFalse);
    });
  });
}
