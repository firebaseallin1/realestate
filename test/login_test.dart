import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/core/controllers/auth_controller.dart';
import 'package:real_estate/core/repositories/local_user_repository.dart';
import 'package:real_estate/models/app_user.dart';
import 'package:real_estate/screens/auth/login_screen.dart';
import 'package:real_estate/screens/auth/views/login_mobile_view.dart';
import 'package:real_estate/screens/auth/views/login_web_view.dart';

Future<void> _pumpLogin(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Mobile width shows mobile layout with brand, fields and login', (WidgetTester tester) async {
    await _pumpLogin(tester, const Size(390, 844));

    expect(find.byType(LoginMobileView), findsOneWidget);
    expect(find.byType(LoginWebView), findsNothing);
    expect(find.text('KAIRA'), findsOneWidget);
    expect(find.text('PROPERTIES'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('Web width shows split web layout with the same form', (WidgetTester tester) async {
    await _pumpLogin(tester, const Size(1440, 900));

    expect(find.byType(LoginWebView), findsOneWidget);
    expect(find.byType(LoginMobileView), findsNothing);
    expect(find.text('KAIRA'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  test('Sign-in returns the account with its role, and rejects wrong details', () async {
    final auth = AuthController(repository: LocalUserRepository());

    final roles = {
      'admin': UserRole.admin,
      'SALES': UserRole.salesExecutive,
      'manager': UserRole.siteManager,
      'incharge': UserRole.siteIncharge,
    };
    for (final entry in roles.entries) {
      final user = await auth.login(username: entry.key, password: LocalUserRepository.demoPassword);
      expect(user?.role, entry.value);
    }

    expect(await auth.login(username: 'admin', password: 'wrong-pass'), isNull);
    expect(auth.errorMessage, 'Incorrect username or password.');
    expect(await auth.login(username: 'nobody', password: LocalUserRepository.demoPassword), isNull);
  });
}