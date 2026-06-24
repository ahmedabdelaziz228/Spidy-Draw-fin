import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spidy_draw/main.dart';

void main() {
  testWidgets('Spidy Draw app starts', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const SpidyDrawApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('Spidy Draw'), findsWidgets);
    expect(find.text('ESP32 URL'), findsOneWidget);
  });
}
