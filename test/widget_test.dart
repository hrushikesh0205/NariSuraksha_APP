import 'package:flutter_test/flutter_test.dart';
import 'package:nari_suraksha/app.dart';

void main() {
  testWidgets('App renders Nari Suraksha title', (WidgetTester tester) async {
    // Mount the app. SplashPage.initState() schedules two Future.delayed timers:
    //   1) Future.delayed(Duration.zero)  — starts the entrance AnimationController
    //   2) Future.delayed(Duration(ms: 3200)) — triggers navigation to onboarding
    // We must drain both before the test ends to avoid "A Timer is still pending".

    await tester.pumpWidget(const NarisurakshaApp());

    // Pump a single zero-duration frame. This drains the microtask queue and
    // resolves the first Future.delayed(Duration.zero), causing _entrance.forward()
    // to be called. The 'Nari Suraksha' Text widget is now in the tree.
    await tester.pump(Duration.zero);

    // The text is present in the widget tree (inside a FadeTransition whose
    // opacity begins at 0, but find.text() searches the widget tree, not the
    // rendered pixels, so the widget is still found).
    expect(find.text('Nari Suraksha'), findsOneWidget);

    // Advance the clock by the full splash duration (3200 ms) so the second
    // Future.delayed completes, _navigateNext() runs, and the async _startSequence
    // future is fully resolved — leaving no pending timers.
    await tester.pump(const Duration(milliseconds: 3200));

    // Pump a few frames so the route transition can render without calling
    // pumpAndSettle(), which would time out due to repeating animations in the
    // destination screen (OnboardingScreen has looping AnimationControllers).
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  });
}
