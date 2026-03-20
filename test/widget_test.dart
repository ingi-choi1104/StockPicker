import 'package:flutter_test/flutter_test.dart';
import 'package:stockpicker/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const StockPickerApp());
    expect(find.text('증권사 이벤트'), findsOneWidget);
  });
}
