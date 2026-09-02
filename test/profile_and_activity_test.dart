import 'package:flutter_test/flutter_test.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/models/user_model.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/profile_provider.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/contact_repository.dart';
import 'package:nari_suraksha/repositories/user_repository.dart';

// ── Test Fakes ───────────────────────────────────────────────────────────────

class FakeActivityRepository implements ActivityRepository {
  final List<ActivityLogModel> logs = [];

  @override
  Future<void> logActivity({
    required String uid,
    required ActivityLogType type,
    required String description,
  }) async {
    logs.add(ActivityLogModel(
      id: 'log_${logs.length}',
      userId: uid,
      type: type,
      description: description,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Future<List<ActivityLogModel>> getRecentActivity(
    String uid, {
    int limit = 10,
  }) async {
    final userLogs = logs.where((l) => l.userId == uid).toList();
    userLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return userLogs.take(limit).toList();
  }

  @override
  Stream<List<ActivityLogModel>> watchRecentActivity(
    String uid, {
    int limit = 10,
  }) {
    final userLogs = logs.where((l) => l.userId == uid).toList();
    userLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return Stream.value(userLogs.take(limit).toList());
  }
}

class FakeContactRepository implements ContactRepository {
  final List<EmergencyContact> contacts = [];
  bool shouldFailDelete = false;

  @override
  Future<EmergencyContact> addContact(
    String uid,
    EmergencyContact contact, {
    ContactPriority priority = ContactPriority.high,
  }) async {
    final created = contact.copyWith(
      id: 'contact_${contacts.length + 1}',
      priority: priority,
    );
    contacts.add(created);
    return created;
  }

  @override
  Future<void> updateContact(String uid, EmergencyContact contact) async {
    final index = contacts.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      contacts[index] = contact;
    }
  }

  @override
  Future<void> deleteContact(String uid, String contactId) async {
    if (shouldFailDelete) {
      throw Exception('Simulated network error');
    }
    contacts.removeWhere((c) => c.id == contactId);
  }

  @override
  Future<List<EmergencyContact>> getContacts(String uid) async {
    return List.from(contacts);
  }

  @override
  Stream<List<EmergencyContact>> watchContacts(String uid) {
    return Stream.value(List.from(contacts));
  }
}

class FakeUserRepository implements UserRepository {
  final Map<String, UserModel> users = {};

  @override
  Future<UserModel?> fetchUser(String uid) async {
    return users[uid];
  }

  @override
  Stream<UserModel?> watchUser(String uid) {
    return Stream.value(users[uid]);
  }

  @override
  Future<void> createUser(UserModel user) async {
    users[user.uid] = user;
  }

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    final current = users[uid] ??
        UserModel(
          uid: uid,
          email: 'test@example.com',
          name: 'User',
          createdAt: DateTime.now(),
        );

    users[uid] = current.copyWith(
      name: fields['name'] as String?,
      phone: fields['phone'] as String?,
      photoUrl: fields['photoUrl'] as String?,
      bloodGroup: fields['bloodGroup'] as String?,
      allergies: fields['allergies'] as String?,
      conditions: fields['conditions'] as String?,
      medications: fields['medications'] as String?,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Recent Activity Stream & Sorting Tests', () {
    late FakeActivityRepository fakeActivityRepo;

    setUp(() {
      fakeActivityRepo = FakeActivityRepository();
    });

    test('Recent activity logs sort by timestamp descending', () async {
      final now = DateTime.now();

      fakeActivityRepo.logs.addAll([
        ActivityLogModel(
          id: '1',
          userId: 'user_1',
          type: ActivityLogType.contactAdded,
          description: 'Added Mom',
          timestamp: now.subtract(const Duration(minutes: 5)),
        ),
        ActivityLogModel(
          id: '2',
          userId: 'user_1',
          type: ActivityLogType.sosActivated,
          description: 'Emergency SOS triggered',
          timestamp: now,
        ),
        ActivityLogModel(
          id: '3',
          userId: 'user_1',
          type: ActivityLogType.locationShared,
          description: 'Location shared',
          timestamp: now.subtract(const Duration(minutes: 2)),
        ),
      ]);

      final recent = await fakeActivityRepo.getRecentActivity('user_1', limit: 10);

      expect(recent.length, 3);
      expect(recent.first.type, ActivityLogType.sosActivated);
      expect(recent[1].type, ActivityLogType.locationShared);
      expect(recent.last.type, ActivityLogType.contactAdded);
    });

    test('Activity stream isolates logs by authenticated userId', () async {
      fakeActivityRepo.logs.addAll([
        ActivityLogModel(
          id: '1',
          userId: 'user_A',
          type: ActivityLogType.sosActivated,
          description: 'User A SOS',
          timestamp: DateTime.now(),
        ),
        ActivityLogModel(
          id: '2',
          userId: 'user_B',
          type: ActivityLogType.sosActivated,
          description: 'User B SOS',
          timestamp: DateTime.now(),
        ),
      ]);

      final userALogs = await fakeActivityRepo.watchRecentActivity('user_A').first;
      expect(userALogs.length, 1);
      expect(userALogs.first.description, 'User A SOS');
    });
  });

  group('Contact Deletion Tests', () {
    late FakeContactRepository fakeContactRepo;
    late FakeActivityRepository fakeActivityRepo;
    late ContactProvider contactProvider;

    setUp(() {
      fakeContactRepo = FakeContactRepository();
      fakeActivityRepo = FakeActivityRepository();
      contactProvider = ContactProvider(
        contactRepository: fakeContactRepo,
        activityRepository: fakeActivityRepo,
      );
    });

    test('deleteContact deletes from repository and logs activity', () async {
      const contact = EmergencyContact(
        id: 'contact_1',
        userId: 'user_test',
        name: 'Sister',
        phone: '+919876543210',
        priority: ContactPriority.high,
      );

      fakeContactRepo.contacts.add(contact);

      final err = await contactProvider.deleteContact(
        uid: 'user_test',
        contact: contact,
      );

      expect(err, isNull);
      expect(fakeContactRepo.contacts, isEmpty);
      expect(fakeActivityRepo.logs.any((l) => l.type == ActivityLogType.contactDeleted), isTrue);
    });

    test('deleteContact handles missing contact ID gracefully', () async {
      const contactWithoutId = EmergencyContact(
        userId: 'user_test',
        name: 'Friend',
        phone: '+919876543211',
      );

      final err = await contactProvider.deleteContact(
        uid: 'user_test',
        contact: contactWithoutId,
      );

      expect(err, isNotNull);
      expect(err, contains('missing contact ID'));
    });

    test('deleteContact reverts local list if repository delete fails', () async {
      await contactProvider.addContact(
        uid: 'user_test',
        name: 'Sister',
        phone: '+919876543210',
        relation: 'Sister',
      );
      contactProvider.subscribe('user_test');
      await Future<void>.delayed(Duration.zero);

      final contact = contactProvider.contacts.first;
      fakeContactRepo.shouldFailDelete = true;

      final err = await contactProvider.deleteContact(
        uid: 'user_test',
        contact: contact,
      );

      expect(err, isNotNull);
      expect(contactProvider.contacts.length, 1);
    });
  });

  group('Profile Provider Tests', () {
    late FakeUserRepository fakeUserRepo;
    late FakeActivityRepository fakeActivityRepo;
    late ProfileProvider profileProvider;

    setUp(() {
      fakeUserRepo = FakeUserRepository();
      fakeActivityRepo = FakeActivityRepository();
      profileProvider = ProfileProvider(
        userRepository: fakeUserRepo,
        activityRepository: fakeActivityRepo,
      );
    });

    test('updateBasicInfo updates name and phone without photoUrl', () async {
      final initial = UserModel(
        uid: 'user_test',
        email: 'priya@example.com',
        name: 'Priya',
        phone: '+919876543210',
        photoUrl: 'https://example.com/existing.jpg',
        createdAt: DateTime.now(),
      );

      fakeUserRepo.users['user_test'] = initial;

      final err = await profileProvider.updateBasicInfo(
        current: initial,
        name: 'Priya Sharma',
        phone: '+919876543299',
      );

      expect(err, isNull);
      final updated = fakeUserRepo.users['user_test'];
      expect(updated?.name, 'Priya Sharma');
      expect(updated?.phone, '+919876543299');
      // Preserves existing photoUrl
      expect(updated?.photoUrl, 'https://example.com/existing.jpg');
    });

    test('updateBasicInfo validates non-empty name', () async {
      final initial = UserModel(
        uid: 'user_test',
        email: 'priya@example.com',
        name: 'Priya',
        createdAt: DateTime.now(),
      );

      final err = await profileProvider.updateBasicInfo(
        current: initial,
        name: '   ',
        phone: '+919876543210',
      );

      expect(err, isNotNull);
      expect(err, contains('Name cannot be empty'));
    });

    test('pickAndUploadProfilePhoto handles empty/cancelled selection cleanly', () async {
      final err = await profileProvider.pickAndUploadProfilePhoto(
        uid: 'user_test',
        simulatedCancel: true,
      );

      expect(err, isNull);
      expect(profileProvider.isUploadingPhoto, isFalse);
    });
  });
}
