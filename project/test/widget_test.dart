import 'package:flutter_test/flutter_test.dart';
import 'package:project/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders login button after bootstrap', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MartStroyApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Войти'), findsOneWidget);
  });
}
