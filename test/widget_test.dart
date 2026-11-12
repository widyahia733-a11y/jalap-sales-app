import 'package:flutter_test/flutter_test.dart';
import 'package:jalap_sales_app/main.dart';

void main() {
  testWidgets('LoginPage renders correctly on startup', (WidgetTester tester) async {
    await tester.pumpWidget(const JalapSalesApp());

    expect(find.text('جلب الميداني'), findsOneWidget);
    expect(find.text('تسجيل الدخول للميدان'), findsOneWidget);
  });
}
