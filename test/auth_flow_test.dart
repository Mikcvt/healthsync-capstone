import 'package:flutter_test/flutter_test.dart';
import 'package:healthsync/main.dart';

void main() {
  testWidgets('welcome screen shows onboarding actions', (tester) async {
    await tester.pumpWidget(const HealthSyncApp());

    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Already have an account?'), findsOneWidget);
  });
}
