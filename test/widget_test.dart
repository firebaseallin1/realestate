import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/main.dart';

void main() {
  testWidgets('App renders splash screen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const RealEstateApp());
    expect(find.text('KAIRA'), findsOneWidget);
    expect(find.text('PROPERTIES'), findsOneWidget);
  });
}
