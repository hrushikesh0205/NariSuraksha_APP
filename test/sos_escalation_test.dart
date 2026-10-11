import 'package:flutter_test/flutter_test.dart';
import 'package:nari_suraksha/core/services/sms_service.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/providers/sos_escalation_provider.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/contact_repository.dart';
import 'package:nari_suraksha/repositories/sos_repository.dart';

// ── Test Fakes ───────────────────────────────────────────────────────────────

class FakeContactRepository implements ContactRepository {
  List<EmergencyContact> contacts = [];

  @override
  Stream<List<EmergencyContact>> watchContacts(String uid) {
    return Stream.value(contacts);
  }

  @override
  Future<List<EmergencyContact>> getContacts(String uid) async {
    return contacts;
  }

  @override
  Future<EmergencyContact> addContact(String uid, EmergencyContact contact) async {
    contacts.add(contact);
    return contact;
  }

  @override
  Future<void> updateContact(String uid, EmergencyContact contact) async {
    final idx = contacts.indexWhere((c) => c.id == contact.id);
    if (idx != -1) contacts[idx] = contact;
  }

  @override
  Future<void> deleteContact(String uid, String contactId) async {
    contacts.removeWhere((c) => c.id == contactId);
  }
}

class FakeSosRepository implements SosRepository {
  final List<SosRecordModel> records = [];
  String? updatedDocId;
  SosStatus? updatedStatus;
  String? updatedLevel;
  DateTime? updatedAlertedAt;
  Map<String, String>? updatedSmsResults;
  bool? updatedPoliceCallAuthorized;

  @override
  Future<String> createSosRecord(SosRecordModel record, {String? docId}) async {
    records.add(record);
    return docId ?? 'fake_sos_id_${records.length}';
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
  Future<void> updateSmsResults(
    String docId,
    Map<String, String> results,
  ) async {
    updatedDocId = docId;
    updatedSmsResults = results;
  }

  @override
  Future<void> updatePoliceCallStatus(
    String docId, {
    required bool authorized,
  }) async {
    updatedDocId = docId;
    updatedPoliceCallAuthorized = authorized;
  }

  @override
  Future<List<SosRecordModel>> getRecentSos(String uid, {int limit = 5}) async {
    return records;
  }
}

class FakeSmsService extends SmsService {
  final List<String> sentPhones = [];

  @override
  Future<SmsSendResult> sendDirectSms({
    required String phone,
    required String message,
    String contactName = '',
  }) async {
    final normalized = normalizePhone(phone);
    sentPhones.add(normalized);
    return SmsSendResult(
      phone: normalized,
      contactName: contactName,
      result: SmsResult.sent,
    );
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
    late FakeContactRepository fakeContactRepo;
    late SosEscalationProvider provider;

    setUp(() {
      fakeSosRepo = FakeSosRepository();
      fakeActivityRepo = FakeActivityRepository();
      fakeContactRepo = FakeContactRepository();
      provider = SosEscalationProvider(
        sosRepository: fakeSosRepo,
        activityRepository: fakeActivityRepo,
        contactRepository: fakeContactRepo,
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

    test('startSession auto-sends SMS to High priority contacts', () async {
      final fakeSms = FakeSmsService();
      final p = SosEscalationProvider(
        sosRepository: fakeSosRepo,
        activityRepository: fakeActivityRepo,
        contactRepository: fakeContactRepo,
        smsService: fakeSms,
      );

      final contacts = [
        const EmergencyContact(
          id: 'c1',
          userId: 'user_abc',
          name: 'Mom',
          phone: '+91 98765 00001',
          relation: 'Mother',
          priority: ContactPriority.high,
        ),
        const EmergencyContact(
          id: 'c2',
          userId: 'user_abc',
          name: 'Dad',
          phone: '+91 98765 00002',
          relation: 'Father',
          priority: ContactPriority.medium,
        ),
      ];

      p.updateContacts(contacts);
      p.updateUserName('Priya Sharma');

      p.startSession(
        sosDocId: 'sos_auto_sms_test',
        userId: 'user_abc',
        latitude: 12.9716,
        longitude: 77.5946,
        mapsUrl: 'https://maps.google.com/?q=12.9716,77.5946',
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(fakeSms.sentPhones, contains('+919876500001'));
      expect(fakeSms.sentPhones, isNot(contains('+919876500002')));
      expect(fakeSosRepo.updatedSmsResults, isNotNull);
      expect(fakeSosRepo.updatedSmsResults!['+919876500001'], 'sent');

      p.dispose();
    });

    test('escalateTo sends SMS to next priority contacts', () async {
      final fakeSms = FakeSmsService();
      final p = SosEscalationProvider(
        sosRepository: fakeSosRepo,
        activityRepository: fakeActivityRepo,
        contactRepository: fakeContactRepo,
        smsService: fakeSms,
      );

      final contacts = [
        const EmergencyContact(
          id: 'c1',
          userId: 'user_abc',
          name: 'Mom',
          phone: '+91 98765 00001',
          relation: 'Mother',
          priority: ContactPriority.high,
        ),
        const EmergencyContact(
          id: 'c2',
          userId: 'user_abc',
          name: 'Dad',
          phone: '+91 98765 00002',
          relation: 'Father',
          priority: ContactPriority.medium,
        ),
      ];

      p.updateContacts(contacts);
      p.startSession(
        sosDocId: 'sos_escalate_sms',
        userId: 'user_abc',
        latitude: 12.9716,
        longitude: 77.5946,
        mapsUrl: 'https://maps.google.com/?q=12.9716,77.5946',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      fakeSms.sentPhones.clear();

      await p.escalateTo(ContactPriority.medium);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(fakeSms.sentPhones, contains('+919876500002'));
      expect(p.activeSession?.isMediumAlerted, isTrue);

      p.dispose();
    });

    test('authorizePoliceCall and declinePoliceCall update repository', () async {
      provider.startSession(
        sosDocId: 'sos_police_test',
        userId: 'user_abc',
        latitude: 12.9716,
        longitude: 77.5946,
        mapsUrl: 'https://maps.google.com/?q=12.9716,77.5946',
      );

      await provider.authorizePoliceCall();
      expect(provider.activeSession?.policeCallAuthorized, isTrue);
      expect(fakeSosRepo.updatedPoliceCallAuthorized, isTrue);
      expect(fakeActivityRepo.logs, contains('User authorized calling emergency police/100.'));

      await provider.declinePoliceCall();
      expect(provider.activeSession?.policeCallAuthorized, isFalse);
      expect(fakeSosRepo.updatedPoliceCallAuthorized, isFalse);
      expect(provider.hasActiveSession, isFalse);
    });

    test('Timeline constants match required T=4m, T=8m, T=12m escalation', () {
      expect(SosEscalationProvider.mediumThresholdSeconds, 240); // 4 minutes
      expect(SosEscalationProvider.lowThresholdSeconds, 480);    // 8 minutes
      expect(SosEscalationProvider.policeThresholdSeconds, 720); // 12 minutes
      expect(SosEscalationProvider.safetyCheckTimeoutSeconds, 30);
    });

    test('Duplicate phone number across tiers is not alerted twice', () async {
      final fakeSms = FakeSmsService();
      final p = SosEscalationProvider(
        sosRepository: fakeSosRepo,
        activityRepository: fakeActivityRepo,
        contactRepository: fakeContactRepo,
        smsService: fakeSms,
      );

      final contacts = [
        const EmergencyContact(
          id: 'c1',
          userId: 'user_dup',
          name: 'Primary Phone',
          phone: '+91 99999 11111',
          relation: 'Friend',
          priority: ContactPriority.high,
        ),
        const EmergencyContact(
          id: 'c2',
          userId: 'user_dup',
          name: 'Duplicate Phone In Medium',
          phone: '+91 99999 11111', // Same number in Medium
          relation: 'Friend 2',
          priority: ContactPriority.medium,
        ),
      ];

      p.updateContacts(contacts);
      p.startSession(
        sosDocId: 'sos_dup_test',
        userId: 'user_dup',
        latitude: 12.9716,
        longitude: 77.5946,
        mapsUrl: 'https://maps.google.com/?q=12.9716,77.5946',
      );

      await Future.delayed(const Duration(milliseconds: 50));
      expect(fakeSms.sentPhones, ['+919999911111']);

      // Escalate to Medium
      fakeSms.sentPhones.clear();
      await p.escalateTo(ContactPriority.medium);
      await Future.delayed(const Duration(milliseconds: 50));

      // Must NOT send again to the same phone number
      expect(fakeSms.sentPhones, isEmpty);
      p.dispose();
    });

    test('resumeActiveSession restores original timestamp and alerted state without resetting', () {
      final fiveMinAgo = DateTime.now().subtract(const Duration(minutes: 5));
      final record = SosRecordModel(
        id: 'sos_resumed_doc',
        userId: 'user_resume',
        latitude: 19.0760,
        longitude: 72.8777,
        timestamp: fiveMinAgo,
        status: SosStatus.active,
        escalationLevel: 'medium',
        highAlertedAt: fiveMinAgo,
        mediumAlertedAt: fiveMinAgo.add(const Duration(minutes: 4)),
        smsResults: const {'+919876500001': 'sent'},
      );

      final resumed = provider.resumeActiveSession(record);
      expect(resumed, isNotNull);
      expect(resumed!.sosDocId, 'sos_resumed_doc');
      expect(resumed.startedAt, fiveMinAgo);
      expect(resumed.elapsed.inMinutes, greaterThanOrEqualTo(5));
      expect(resumed.isHighAlerted, isTrue);
      expect(resumed.isMediumAlerted, isTrue);
      expect(resumed.isLowAlerted, isFalse);
      expect(resumed.alertedContactPhones, contains('+919876500001'));
    });
  });
}
