import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nari_suraksha/core/routes/app_routes.dart';
import 'package:nari_suraksha/core/services/auth_service.dart';
import 'package:nari_suraksha/features/auth/screens/login_page.dart';
import 'package:nari_suraksha/features/auth/screens/register_page.dart';
import 'package:nari_suraksha/models/activity_log_model.dart';
import 'package:nari_suraksha/models/contact_model.dart';
import 'package:nari_suraksha/models/user_model.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/user_provider.dart';
import 'package:nari_suraksha/repositories/activity_repository.dart';
import 'package:nari_suraksha/repositories/contact_repository.dart';
import 'package:nari_suraksha/repositories/user_repository.dart';
import 'package:provider/provider.dart';

// ── Test Fakes ───────────────────────────────────────────────────────────────

class FakeAuthService implements AuthService {
  final List<Map<String, dynamic>> registerCalls = [];
  final List<Map<String, String>> signInCalls = [];
  int signOutCallCount = 0;
  bool isSignedOut = true;

  Object? registerException;
  Object? signInException;
  UserModel? mockUser;

  @override
  User? get firebaseUser => null;

  @override
  bool get isAuthenticated => !isSignedOut;

  @override
  Stream<User?> get authStateChanges => Stream.value(null);

  @override
  Future<UserModel> registerWithEmailPassword({
    required String name,
    required String email,
    required String password,
    String? phone,
  }) async {
    if (registerException != null) {
      throw registerException!;
    }
    registerCalls.add({
      'name': name,
      'email': email,
      'password': password,
      'phone': phone,
    });
    isSignedOut = false;
    return mockUser ??
        UserModel(
          uid: 'fake_uid_priya',
          name: name,
          email: email,
          phone: phone,
        );
  }

  @override
  Future<void> signOut() async {
    signOutCallCount++;
    isSignedOut = true;
  }

  @override
  Future<UserModel> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    if (signInException != null) {
      throw signInException!;
    }
    signInCalls.add({'email': email, 'password': password});
    isSignedOut = false;
    return mockUser ??
        UserModel(
          uid: 'fake_uid_priya',
          name: 'Priya Sharma',
          email: email,
        );
  }

  @override
  Future<UserModel?> fetchCurrentUserModel() async => mockUser;

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {}

  @override
  Future<void> deleteAccount({required String password}) async {}
}

class FakeUserRepositoryWithFailure implements UserRepository {
  bool shouldFailCreate = true;

  @override
  Future<void> createUser(UserModel user) async {
    if (shouldFailCreate) {
      throw Exception('Firestore permission denied: simulated failure');
    }
  }

  @override
  Future<UserModel?> fetchUser(String uid) async => null;

  @override
  Stream<UserModel?> watchUser(String uid) => Stream.value(null);

  @override
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {}
}

class FakeContactRepository implements ContactRepository {
  @override
  Stream<List<EmergencyContact>> watchContacts(String uid) => Stream.value([]);
  @override
  Future<List<EmergencyContact>> getContacts(String uid) async => [];
  @override
  Future<EmergencyContact> addContact(String uid, EmergencyContact contact) async => contact;
  @override
  Future<void> updateContact(String uid, EmergencyContact contact) async {}
  @override
  Future<void> deleteContact(String uid, String contactId) async {}
}

class FakeActivityRepository implements ActivityRepository {
  @override
  Future<void> logActivity({
    required String uid,
    required ActivityLogType type,
    required String description,
  }) async {}

  @override
  Stream<List<ActivityLogModel>> watchRecentActivity(String uid, {int limit = 10}) =>
      Stream.value([]);

  @override
  Future<List<ActivityLogModel>> getRecentActivity(String uid, {int limit = 10}) async =>
      [];
}

// ── Test Harness Helpers ─────────────────────────────────────────────────────

Widget _buildTestApp({
  required Widget child,
  FakeAuthService? authService,
  NavigatorObserver? navigatorObserver,
}) {
  final fakeAuth = authService ?? FakeAuthService();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>(
        create: (_) => UserProvider(authService: fakeAuth),
      ),
      ChangeNotifierProvider<ContactProvider>(
        create: (_) => ContactProvider(
          contactRepository: FakeContactRepository(),
          activityRepository: FakeActivityRepository(),
        ),
      ),
    ],
    child: MaterialApp(
      routes: {
        AppRoutes.login: (_) => LoginPage(authService: fakeAuth),
        AppRoutes.register: (_) => RegisterPage(authService: fakeAuth),
        AppRoutes.home: (_) => const Scaffold(body: Text('Home Dashboard')),
      },
      navigatorObservers:
          navigatorObserver != null ? [navigatorObserver] : [],
      home: child,
    ),
  );
}

void _setScreenSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  group('Authentication UX Registration Flow Tests', () {
    late FakeAuthService fakeAuth;

    setUp(() {
      fakeAuth = FakeAuthService();
    });

    testWidgets(
        'Successful registration shows "Account Created" success dialog and signs out immediately',
        (WidgetTester tester) async {
      _setScreenSize(tester);
      await tester.pumpWidget(
        _buildTestApp(
          child: RegisterPage(authService: fakeAuth),
          authService: fakeAuth,
        ),
      );

      // Fill in registration fields
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(5));

      await tester.enterText(textFields.at(0), 'Priya Sharma');
      await tester.enterText(textFields.at(1), '+91 98765 43210');
      await tester.enterText(textFields.at(2), 'priya@example.com');
      await tester.enterText(textFields.at(3), 'secret123');
      await tester.enterText(textFields.at(4), 'secret123');
      await tester.pump();

      // Tap "Create Account"
      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');
      expect(createButton, findsOneWidget);
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump(); // Start async operation
      await tester.pump(const Duration(milliseconds: 100)); // Complete async

      // Verify registerWithEmailPassword was called
      expect(fakeAuth.registerCalls.length, 1);
      expect(fakeAuth.registerCalls.first['name'], 'Priya Sharma');
      expect(fakeAuth.registerCalls.first['email'], 'priya@example.com');
      expect(fakeAuth.registerCalls.first['password'], 'secret123');
      expect(fakeAuth.registerCalls.first['phone'], '+91 98765 43210');

      // Verify immediate signOut was performed
      expect(fakeAuth.signOutCallCount, 1);
      expect(fakeAuth.isSignedOut, isTrue);

      // Verify Success Dialog is displayed
      expect(find.text('Account Created'), findsOneWidget);
      expect(
        find.text(
          'Your account has been created successfully.\n\nPlease login to continue.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(ElevatedButton, 'Continue'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });

    testWidgets(
        'Tapping Continue on success dialog dismisses dialog and navigates to Login',
        (WidgetTester tester) async {
      _setScreenSize(tester);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>(
              create: (_) => UserProvider(authService: fakeAuth),
            ),
            ChangeNotifierProvider<ContactProvider>(
              create: (_) => ContactProvider(
                contactRepository: FakeContactRepository(),
                activityRepository: FakeActivityRepository(),
              ),
            ),
          ],
          child: MaterialApp(
            initialRoute: AppRoutes.login,
            routes: {
              AppRoutes.login: (_) => LoginPage(authService: fakeAuth),
              AppRoutes.register: (_) => RegisterPage(authService: fakeAuth),
              AppRoutes.home: (_) => const Scaffold(body: Text('Home Dashboard')),
            },
          ),
        ),
      );

      // On Login Page, tap "Register"
      final registerLink = find.text('Register');
      expect(registerLink, findsOneWidget);
      await tester.ensureVisible(registerLink);
      await tester.tap(registerLink);
      await tester.pumpAndSettle();

      // Now on Register Page
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Ananya Roy');
      await tester.enterText(textFields.at(1), '+91 98765 00000');
      await tester.enterText(textFields.at(2), 'ananya@example.com');
      await tester.enterText(textFields.at(3), 'pass1234');
      await tester.enterText(textFields.at(4), 'pass1234');
      await tester.pump();

      // Tap Create Account
      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify dialog is shown
      expect(find.text('Account Created'), findsOneWidget);

      // Tap Continue
      final continueButton = find.widgetWithText(ElevatedButton, 'Continue');
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      // Verify we are back on the Login screen
      expect(find.text('Welcome back 👋'), findsOneWidget);
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets(
        'Newly registered user is NOT automatically logged into UserProvider',
        (WidgetTester tester) async {
      _setScreenSize(tester);
      final userProvider = UserProvider(authService: fakeAuth);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(
              value: userProvider,
            ),
            ChangeNotifierProvider<ContactProvider>(
              create: (_) => ContactProvider(
                contactRepository: FakeContactRepository(),
                activityRepository: FakeActivityRepository(),
              ),
            ),
          ],
          child: MaterialApp(
            routes: {
              AppRoutes.login: (_) => LoginPage(authService: fakeAuth),
              AppRoutes.register: (_) => RegisterPage(authService: fakeAuth),
              AppRoutes.home: (_) => const Scaffold(body: Text('Home Dashboard')),
            },
            home: RegisterPage(authService: fakeAuth),
          ),
        ),
      );

      // Register user
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Kavita Iyer');
      await tester.enterText(textFields.at(1), '+91 98765 11111');
      await tester.enterText(textFields.at(2), 'kavita@example.com');
      await tester.enterText(textFields.at(3), 'kavitaPass');
      await tester.enterText(textFields.at(4), 'kavitaPass');
      await tester.pump();

      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // UserProvider must NOT be holding the registered user
      expect(userProvider.user, isNull);
      expect(fakeAuth.signOutCallCount, 1);
      expect(fakeAuth.isSignedOut, isTrue);
    });

    testWidgets(
        'Registration failure (e.g. email-already-in-use) stays on Register and displays error',
        (WidgetTester tester) async {
      _setScreenSize(tester);
      fakeAuth.registerException = FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'The email address is already in use by another account.',
      );

      await tester.pumpWidget(
        _buildTestApp(
          child: RegisterPage(authService: fakeAuth),
          authService: fakeAuth,
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Existing User');
      await tester.enterText(textFields.at(1), '+91 98765 22222');
      await tester.enterText(textFields.at(2), 'used@example.com');
      await tester.enterText(textFields.at(3), 'pass1234');
      await tester.enterText(textFields.at(4), 'pass1234');
      await tester.pump();

      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Error message must be visible
      expect(
        find.text('An account already exists with this email.'),
        findsOneWidget,
      );

      // Success dialog must NOT be visible
      expect(find.text('Account Created'), findsNothing);

      // Sign out must NOT be called on failure
      expect(fakeAuth.signOutCallCount, 0);

      // Must remain on Register screen
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets(
        'Registration validation rejects password mismatch without calling auth service',
        (WidgetTester tester) async {
      _setScreenSize(tester);
      await tester.pumpWidget(
        _buildTestApp(
          child: RegisterPage(authService: fakeAuth),
          authService: fakeAuth,
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'Test Name');
      await tester.enterText(textFields.at(1), '+91 98765 33333');
      await tester.enterText(textFields.at(2), 'test@example.com');
      await tester.enterText(textFields.at(3), 'passwordOne');
      await tester.enterText(textFields.at(4), 'passwordTwo');
      await tester.pump();

      final createButton = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.ensureVisible(createButton);
      await tester.tap(createButton);
      await tester.pump();

      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(fakeAuth.registerCalls, isEmpty);
      expect(find.text('Account Created'), findsNothing);
    });

    testWidgets('Login works normally and transitions to Home',
        (WidgetTester tester) async {
      _setScreenSize(tester);
      final userProvider = UserProvider(authService: fakeAuth);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<UserProvider>.value(
              value: userProvider,
            ),
            ChangeNotifierProvider<ContactProvider>(
              create: (_) => ContactProvider(
                contactRepository: FakeContactRepository(),
                activityRepository: FakeActivityRepository(),
              ),
            ),
          ],
          child: MaterialApp(
            routes: {
              AppRoutes.login: (_) => LoginPage(authService: fakeAuth),
              AppRoutes.home: (_) =>
                  const Scaffold(body: Text('Home Dashboard Screen')),
            },
            home: LoginPage(authService: fakeAuth),
          ),
        ),
      );

      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'priya@example.com');
      await tester.enterText(textFields.at(1), 'secret123');
      await tester.pump();

      final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.ensureVisible(signInButton);
      await tester.tap(signInButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify sign in called
      expect(fakeAuth.signInCalls.length, 1);
      expect(fakeAuth.signInCalls.first['email'], 'priya@example.com');

      // Verify user loaded into UserProvider
      expect(userProvider.user?.email, 'priya@example.com');

      // Verify Home is reached
      expect(find.text('Home Dashboard Screen'), findsOneWidget);
    });
  });

  group('AuthService Firestore resilience tests', () {
    test('Firestore error mapping gives user-friendly message', () {
      final friendly = AuthService.friendlyError(
        FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'Email in use',
        ),
      );
      expect(friendly, 'An account already exists with this email.');
    });

    test('Firestore timeout error is caught gracefully in friendlyError', () {
      final friendly = AuthService.friendlyError(
        Exception('Network timeout error while reaching Firestore'),
      );
      expect(friendly, contains('timed out'));
    });
  });
}
