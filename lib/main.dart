import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:nari_suraksha/app.dart';
import 'package:nari_suraksha/providers/user_provider.dart';
import 'package:nari_suraksha/providers/dashboard_provider.dart';
import 'package:nari_suraksha/providers/contact_provider.dart';
import 'package:nari_suraksha/providers/profile_provider.dart';
import 'package:nari_suraksha/providers/sos_provider.dart';
import 'package:nari_suraksha/providers/settings_provider.dart';
import 'package:nari_suraksha/providers/voice_sos_provider.dart';
import 'package:nari_suraksha/providers/sos_escalation_provider.dart';

// ── FlutterFire ──────────────────────────────────────────────────────────────
// Once you place android/app/google-services.json, run:
//   flutterfire configure
// and un-comment the import below + the options argument in initializeApp().
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase Initialization ─────────────────────────────────────────────────
  // Requires android/app/google-services.json (downloaded from Firebase Console).
  // If the file is missing the app will continue in degraded mode instead of
  // crashing, so the UI is always reachable for development.
  await _initFirebase();

  runApp(
    MultiProvider(
      providers: [
        // App preferences & settings (theme, notifications, location, voice SOS)
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(),
        ),

        // Core user state — available app-wide
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(),
        ),

        // Dashboard state — depends on UserProvider for user load
        ChangeNotifierProxyProvider<UserProvider, DashboardProvider>(
          create: (ctx) => DashboardProvider(
            userProvider: ctx.read<UserProvider>(),
          ),
          update: (ctx, userProvider, previous) =>
              previous ?? DashboardProvider(userProvider: userProvider),
        ),

        // Emergency contacts — real-time stream provider
        ChangeNotifierProvider<ContactProvider>(
          create: (_) => ContactProvider(),
        ),

        // Profile edit operations
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(),
        ),

        // SOS history + resolve-emergency
        ChangeNotifierProvider<SosProvider>(
          create: (_) => SosProvider(),
        ),

        // Voice SOS — keyword detection wired to DashboardProvider
        ChangeNotifierProxyProvider<DashboardProvider, VoiceSosProvider>(
          create: (ctx) => VoiceSosProvider(
            dashboardProvider: ctx.read<DashboardProvider>(),
          ),
          update: (ctx, dashProvider, previous) {
            if (previous != null) {
              previous.updateDashboardProvider(dashProvider);
              return previous;
            }
            return VoiceSosProvider(dashboardProvider: dashProvider);
          },
        ),

        // SOS Escalation session manager — single source of truth for active SOS
        ChangeNotifierProxyProvider2<ContactProvider, UserProvider, SosEscalationProvider>(
          create: (ctx) {
            final escalation = SosEscalationProvider();
            escalation.updateContacts(ctx.read<ContactProvider>().contacts);
            escalation.updateUserName(ctx.read<UserProvider>().user?.name ?? 'A Nari Suraksha user');
            return escalation;
          },
          update: (ctx, contactProvider, userProvider, previous) {
            final escalation = previous ?? SosEscalationProvider();
            escalation.updateContacts(contactProvider.contacts);
            escalation.updateUserName(userProvider.user?.name ?? 'A Nari Suraksha user');
            if (userProvider.currentUid != null && !escalation.hasActiveSession) {
              escalation.checkAndResumeActiveSession(userProvider.currentUid!);
            }
            return escalation;
          },
        ),
      ],
      child: const NarisurakshaApp(),
    ),
  );
}

/// Initialises Firebase, catching any error caused by missing or invalid
/// google-services.json so that the app can still launch in degraded mode.
///
/// To enable full Firebase support:
///   1. Go to https://console.firebase.google.com
///   2. Create / open your project.
///   3. Add an Android app with package name: com.narisuraksha.nari_suraksha
///   4. Download google-services.json → place at android/app/google-services.json
///   5. Run: flutterfire configure
///   6. Un-comment the firebase_options.dart import above and update the
///      initializeApp() call to pass options: DefaultFirebaseOptions.currentPlatform
Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp(
      // TODO: After running `flutterfire configure`, replace the line above with:
      // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    );
    debugPrint('✅ Firebase initialised successfully.');
  } on Exception catch (e) {
    debugPrint(
      '⚠️  Firebase initialisation failed — running in degraded mode.\n'
      '   Cause: $e\n'
      '   Fix: Place a valid google-services.json at android/app/google-services.json\n'
      '        then run `flutterfire configure`.',
    );
  }
}