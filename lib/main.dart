import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:nari_suraksha/app.dart';
import 'package:nari_suraksha/providers/user_provider.dart';
import 'package:nari_suraksha/providers/dashboard_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase Initialization ─────────────────────────────────────────────────
  // Requires google-services.json at android/app/google-services.json.
  await Firebase.initializeApp();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<UserProvider>(
          create: (_) => UserProvider(),
        ),
        ChangeNotifierProxyProvider<UserProvider, DashboardProvider>(
          create: (ctx) => DashboardProvider(
            userProvider: ctx.read<UserProvider>(),
          ),
          update: (ctx, userProvider, previous) =>
              previous ?? DashboardProvider(userProvider: userProvider),
        ),
      ],
      child: const NarisurakshaApp(),
    ),
  );
}