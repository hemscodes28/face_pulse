import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_rppg_app/main.dart';

void main() {
  testWidgets('FacePulseApp renders smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const FacePulseApp());

    // Verify that HUD elements are present.
    expect(find.textContaining('STATUS:'), findsOneWidget);
    expect(find.text('STOP CAMERA'), findsOneWidget);
  });
}
