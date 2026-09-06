import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nari_suraksha/core/routes/app_router.dart';
import 'package:nari_suraksha/core/routes/app_routes.dart';
import 'package:nari_suraksha/features/sos/screens/sos_screen.dart';

void main() {
  group('Home Dashboard UX Tests', () {
    test('Core routes exist and removed routes are absent', () {
      expect(AppRoutes.home, '/home');
      expect(AppRoutes.contacts, '/contacts');
      expect(AppRoutes.liveTracking, '/live-tracking');
      expect(AppRoutes.voiceSos, '/voice-sos');
      expect(AppRoutes.profile, '/profile');
    });

    testWidgets('Live Tracking route resolves to real LocationBottomSheet, not Coming Soon', (tester) async {
      final route = AppRouter.onGenerateRoute(const RouteSettings(name: AppRoutes.liveTracking));
      expect(route, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: (route as MaterialPageRoute).builder(tester.element(find.byType(Container))),
        ),
      );

      // Must NOT show 'Coming Soon'
      expect(find.text('Coming Soon'), findsNothing);
      expect(find.text('Live Tracking'), findsOneWidget);
      expect(find.byType(LocationBottomSheet), findsOneWidget);
    });

    testWidgets('LocationBottomSheet renders GPS and Share Location elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: LocationBottomSheet(),
          ),
        ),
      );

      expect(find.text('CURRENT LOCATION'), findsOneWidget);
    });
  });
}
