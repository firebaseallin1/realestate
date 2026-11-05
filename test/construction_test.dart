import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/core/controllers/booking_controller.dart';
import 'package:real_estate/core/controllers/construction_controller.dart';
import 'package:real_estate/core/controllers/site_controller.dart';
import 'package:real_estate/core/controllers/user_controller.dart';
import 'package:real_estate/models/booking.dart';
import 'package:real_estate/models/construction.dart';
import 'package:real_estate/screens/construction/construction_screen.dart';
import 'package:real_estate/screens/dashboard/dashboard_screen.dart';

class _Setup {
  final BookingController bookings;
  final ConstructionController construction;
  final UserController users;

  _Setup(this.bookings, this.construction, this.users);
}

_Setup _controllers() {
  final bookings = BookingController(SiteController.test());
  return _Setup(bookings, ConstructionController(bookings), UserController.test());
}

Future<_Setup> _pump(WidgetTester tester, Size size, String username, {_Setup? setup}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final s = setup ?? _controllers();
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: RouteSettings(arguments: s.users.findByUsername(username)),
        builder: (_) => DashboardScreen(
          userController: s.users,
          bookingController: s.bookings,
          constructionController: s.construction,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return s;
}

Future<void> _openMenu(WidgetTester tester, String name) async {
  final item = find.byKey(ValueKey('menu-$name'));
  if (item.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('open-menu')));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(item.last);
  await tester.pumpAndSettle();
  await tester.tap(item.last);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(find.descendant(of: field, matching: find.byType(TextFormField)), text);
  await tester.pump();
}

/// Lets a snackbar time out so it does not cover buttons.
Future<void> _clearSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  const phone = Size(360, 780);
  const desktop = Size(1440, 1000);

  group('ConstructionController', () {
    test('Sample house has stages, attendance-based wages and material bills', () {
      final c = _controllers().construction;
      final project = c.projectById('b3')!;

      expect(project.stages.length, ConstructionStage.defaultNames.length);
      expect(project.progress, 29); // (100 + 100 + 60) / 9
      expect(project.currentStage!.name, 'Walls & Brickwork');
      expect(project.budget, 4000000);

      // Raju worked 3 days at ₹900 and was paid ₹1,800.
      expect(project.daysWorked('w1'), 3);
      expect(project.wagesEarned('w1'), 2700);
      expect(project.wagesDue('w1'), 900);

      expect(project.materialCost, 76000 + 155000 + 160000 + 65000);
      expect(project.materialDue('m2'), 55000);
      expect(project.totalDue, project.totalCost - project.totalPaid);
    });

    test('Approved With Construction bookings open projects; incharges see only theirs', () {
      final s = _controllers();
      final incharge = s.users.findByUsername('incharge')!;

      expect(s.construction.projectById('b2'), isNull); // pending
      s.bookings.approve('b2');
      final project = s.construction.projectById('b2')!;
      expect(project.inchargeId, isNull);
      expect(s.construction.projects.length, 2);

      expect(s.construction.projectsFor(incharge).map((p) => p.id), ['b3']);
      s.construction.assignIncharge('b2', incharge.id);
      expect(s.construction.projectsFor(incharge).length, 2);
    });

    test('Work updates start stages, and data survives booking changes', () {
      final s = _controllers();
      final project = s.construction.projectById('b3')!;
      final slab = project.stages[3];

      s.construction.addDailyWork(
        'b3',
        DailyWork(id: 'x', date: DateTime(2026, 10, 25), stageId: slab.id, description: 'Shuttering', workerIds: const ['w4'], updatedBy: 'T'),
      );
      expect(slab.status, StageStatus.inProgress);

      s.construction.updateStage('b3', slab.id, status: StageStatus.completed, progress: 40);
      expect(slab.progress, 100);

      // A customer payment replaces the booking; the construction data stays.
      s.bookings.addPayment(
        'b3',
        PaymentEntry(id: 'y', part: PaymentPart.construction, amount: 100000, date: DateTime(2026, 10, 26), method: PaymentMethod.upi),
      );
      final again = s.construction.projectById('b3')!;
      expect(again.dailyWork.length, 4);
      expect(again.booking.totalPaid, project.booking.totalPaid);
    });
  });

  testWidgets('Site Incharge adds a daily update, pays wages and records material', (tester) async {
    for (final size in [desktop, phone]) {
      final s = await _pump(tester, size, 'incharge');

      await _openMenu(tester, 'dailyConstruction');
      await _tap(tester, find.byKey(const ValueKey('project-b3')));
      expect(find.byType(ConstructionScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('daily-d3')), findsOneWidget);

      // Daily work update with attendance.
      await _tap(tester, find.byKey(const ValueKey('construction-action')));
      await _tap(tester, find.byKey(const ValueKey('daily-submit')));
      expect(find.text('Please describe the work done.'), findsOneWidget);
      expect(find.text('Select the workers present.'), findsOneWidget);
      await _type(tester, 'daily-description', 'Lintel concrete poured');
      await _tap(tester, find.byKey(const ValueKey('daily-worker-w4')));
      await _tap(tester, find.byKey(const ValueKey('daily-submit')));
      final project = s.construction.projectById('b3')!;
      expect(project.dailyWork.length, 4);
      expect(project.wagesEarned('w4'), 1600);
      await _clearSnackBar(tester);

      // Pay Raju the ₹900 due (amount is prefilled).
      await _tap(tester, find.byKey(const ValueKey('tab-workers')));
      await _tap(tester, find.byKey(const ValueKey('pay-worker-w1')));
      await _type(tester, 'expense-amount', '5000');
      await _tap(tester, find.byKey(const ValueKey('expense-submit')));
      expect(find.text('More than the ₹900 due.'), findsOneWidget);
      await _type(tester, 'expense-amount', '900');
      await _tap(tester, find.byKey(const ValueKey('expense-submit')));
      expect(project.wagesDue('w1'), 0);
      await _clearSnackBar(tester);

      // New material, then pay its bill.
      await _tap(tester, find.byKey(const ValueKey('tab-materials')));
      await _tap(tester, find.byKey(const ValueKey('construction-action')));
      await _type(tester, 'material-name', 'Jelly 20mm');
      await _type(tester, 'material-quantity', '4');
      await _type(tester, 'material-rate', '7000');
      expect(find.text('₹28,000'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('material-submit')));
      final jelly = project.materials.last;
      expect(jelly.amount, 28000);
      await _clearSnackBar(tester);

      await _tap(tester, find.byKey(ValueKey('pay-material-${jelly.id}')));
      await _tap(tester, find.byKey(const ValueKey('expense-submit')));
      expect(project.materialDue(jelly.id), 0);
      await _clearSnackBar(tester);

      // Expenses tab totals.
      await _tap(tester, find.byKey(const ValueKey('tab-expenses')));
      expect(find.text('Cost Breakdown'), findsOneWidget);
      expect(find.text('Jelly 20mm'), findsOneWidget);
    }
  });

  testWidgets('Site Manager assigns an incharge and updates a stage', (tester) async {
    for (final size in [desktop, phone]) {
      final setup = _controllers();
      setup.bookings.approve('b2');
      final s = await _pump(tester, size, 'manager', setup: setup);

      await _openMenu(tester, 'siteAssignment');
      expect(find.text('No Site Incharge assigned'), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('assign-b2')));
      await tester.tap(find.text('Suresh Reddy').last);
      await tester.pumpAndSettle();
      expect(s.construction.projectById('b2')!.inchargeId, 'u4');
      await _clearSnackBar(tester);

      await _openMenu(tester, 'constructionPlanning');
      await _tap(tester, find.byKey(const ValueKey('project-b3')));
      await _tap(tester, find.byKey(const ValueKey('stage-2')));
      await _tap(tester, find.byKey(const ValueKey('stage-status-completed')));
      await _tap(tester, find.byKey(const ValueKey('stage-submit')));
      final project = s.construction.projectById('b3')!;
      expect(project.stages[2].status, StageStatus.completed);
      expect(project.currentStage!.name, 'Roof Slab');
      expect(find.text('33%'), findsWidgets);
    }
  });

  testWidgets('Progress monitoring totals and incharge without projects', (tester) async {
    for (final size in [desktop, phone]) {
      await _pump(tester, size, 'manager');
      await _openMenu(tester, 'progressMonitoring');
      expect(find.text('Avg. Progress'), findsOneWidget);
      expect(find.byKey(const ValueKey('project-b3')), findsOneWidget);
    }

    final setup = _controllers()..construction.assignIncharge('b3', null);
    await _pump(tester, desktop, 'incharge', setup: setup);
    await _openMenu(tester, 'labor');
    expect(find.text('No houses are assigned to you yet. Your Site Manager assigns them.'), findsOneWidget);
  });
}
