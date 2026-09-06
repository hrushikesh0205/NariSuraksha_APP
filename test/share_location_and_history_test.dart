import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nari_suraksha/models/sos_record_model.dart';
import 'package:nari_suraksha/providers/sos_provider.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/sos_repository.dart';
import 'package:nari_suraksha/core/services/auth_service.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

class MockFirebaseUser implements User {
  MockFirebaseUser({required this.uid, this.email});

  @override
  final String uid;

  @override
  final String? email;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthService implements AuthService {
  MockFirebaseUser? _currentUser;

  void setUser(String uid, String email) {
    _currentUser = MockFirebaseUser(uid: uid, email: email);
  }

  void clearUser() {
    _currentUser = null;
  }

  @override
  User? get firebaseUser => _currentUser;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSosRepoForHistory implements SosRepository {
  List<SosRecordModel> recordsToReturn = [];
  Exception? errorToThrow;
  String? queriedUid;

  @override
  Future<List<SosRecordModel>> getRecentSos(String uid, {int limit = 5}) async {
    queriedUid = uid;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    // Return records sorted newest-first (simulating the in-memory sort in real repo)
    final list = List<SosRecordModel>.from(recordsToReturn);
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list.take(limit).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeActivityRepo implements ActivityRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Share Location — Logic & URL Generation Tests', () {
    test('Google Maps search URL format is correct', () {
      const lat = 19.0760;
      const lng = 72.8777;
      final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

      expect(url, 'https://www.google.com/maps/search/?api=1&query=19.076,72.8777');
      expect(Uri.parse(url).isAbsolute, isTrue);
      expect(Uri.parse(url).queryParameters['query'], '19.076,72.8777');
    });

    test('Share text message includes maps URL and header', () {
      const lat = 28.6139;
      const lng = 77.2090;
      final mapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final shareText = 'Nari Suraksha \u2014 My Current Location\n\n'
          'I am sharing my current location with you.\n\n'
          'Location:\n$mapsUrl';

      expect(shareText, contains('Nari Suraksha'));
      expect(shareText, contains(mapsUrl));
      expect(shareText, contains('28.6139,77.209'));
    });

    test('Friendly error strings map GPS & permission error conditions correctly', () {
      String resolveError(String errorMsg) {
        final msg = errorMsg.toLowerCase();
        if (msg.contains('disabled') || msg.contains('service')) {
          return 'Location services are disabled. Please enable GPS in Settings.';
        } else if (msg.contains('permission') || msg.contains('denied')) {
          return 'Location permission denied. Please grant location access in Settings.';
        } else if (msg.contains('timeout') || msg.contains('time')) {
          return 'Location request timed out. Please try again.';
        } else {
          return 'Unable to get your current location. Please enable location services.';
        }
      }

      expect(
        resolveError('LocationServiceDisabledException: Location services are disabled.'),
        'Location services are disabled. Please enable GPS in Settings.',
      );
      expect(
        resolveError('PermissionDeniedException: User denied permissions to access the device location.'),
        'Location permission denied. Please grant location access in Settings.',
      );
      expect(
        resolveError('TimeoutException after 0:00:10.000000: Location request timed out'),
        'Location request timed out. Please try again.',
      );
      expect(
        resolveError('Unknown error occurred'),
        'Unable to get your current location. Please enable location services.',
      );
    });
  });

  group('SOS History — In-Memory Sort & Provider Error Handling', () {
    late FakeAuthService auth;
    late FakeSosRepoForHistory repo;
    late FakeActivityRepo activityRepo;
    late SosProvider provider;

    setUp(() {
      auth = FakeAuthService();
      auth.setUser('user_123', 'test@example.com');
      repo = FakeSosRepoForHistory();
      activityRepo = FakeActivityRepo();
      provider = SosProvider(
        authService: auth,
        sosRepository: repo,
        activityRepository: activityRepo,
      );
    });

    test('getRecentSos returns records sorted newest-first (in-memory sort)', () async {
      final t1 = DateTime(2026, 1, 1, 10, 0);
      final t2 = DateTime(2026, 1, 2, 10, 0); // newest
      final t3 = DateTime(2025, 12, 31, 10, 0); // oldest

      repo.recordsToReturn = [
        SosRecordModel(
          id: 'rec_1',
          userId: 'user_123',
          latitude: 19.0,
          longitude: 72.0,
          timestamp: t1,
        ),
        SosRecordModel(
          id: 'rec_2',
          userId: 'user_123',
          latitude: 19.1,
          longitude: 72.1,
          timestamp: t2,
        ),
        SosRecordModel(
          id: 'rec_3',
          userId: 'user_123',
          latitude: 19.2,
          longitude: 72.2,
          timestamp: t3,
        ),
      ];

      await provider.loadHistory();

      expect(provider.history.length, 3);
      expect(provider.history[0].id, 'rec_2'); // newest first
      expect(provider.history[1].id, 'rec_1');
      expect(provider.history[2].id, 'rec_3'); // oldest last
      expect(provider.historyError, isNull);
      expect(repo.queriedUid, 'user_123');
    });

    test('Empty history returns empty list without error', () async {
      repo.recordsToReturn = [];

      await provider.loadHistory();

      expect(provider.history, isEmpty);
      expect(provider.historyError, isNull);
    });

    test('failed-precondition (composite index missing) is handled gracefully without generic crash', () async {
      repo.errorToThrow = Exception('[cloud_firestore/failed-precondition] The query requires an index.');

      await provider.loadHistory();

      expect(provider.history, isEmpty);
      expect(provider.historyError, isNotNull);
      expect(provider.historyError, 'Unable to load history. Please refresh.');
      // Must NOT be "Something went wrong"
      expect(provider.historyError, isNot(contains('Something went wrong')));
    });

    test('network unavailable error is handled gracefully with clear connectivity message', () async {
      repo.errorToThrow = Exception('[cloud_firestore/unavailable] The service is currently unavailable.');

      await provider.loadHistory();

      expect(provider.history, isEmpty);
      expect(provider.historyError, contains('No internet connection'));
    });

    test('permission-denied error is handled gracefully', () async {
      repo.errorToThrow = Exception('[cloud_firestore/permission-denied] Missing or insufficient permissions.');

      await provider.loadHistory();

      expect(provider.history, isEmpty);
      expect(provider.historyError, contains('Access denied'));
    });

    test('Unauthenticated user returns empty history immediately', () async {
      auth.clearUser();

      await provider.loadHistory();

      expect(provider.history, isEmpty);
      expect(provider.historyError, isNull);
    });
  });
}
