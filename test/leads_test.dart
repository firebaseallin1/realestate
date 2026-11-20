import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/core/api/api_client.dart';
import 'package:real_estate/core/controllers/lead_controller.dart';
import 'package:real_estate/core/controllers/site_controller.dart';
import 'package:real_estate/core/controllers/user_controller.dart';
import 'package:real_estate/models/booking.dart';
import 'package:real_estate/models/customer.dart';
import 'package:real_estate/models/lead.dart';
import 'package:real_estate/screens/dashboard/dashboard_screen.dart';
import 'package:real_estate/screens/leads/lead_detail_screen.dart';
import 'package:real_estate/widgets/list_table_switcher.dart';

const _desktop = Size(1440, 1000);
const _phone = Size(390, 844);

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

Future<LeadController> _pump(WidgetTester tester, Size size, String username) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final users = UserController.test();
  final leads = LeadController();
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: RouteSettings(arguments: users.findByUsername(username)),
        builder: (_) => DashboardScreen(controller: SiteController.test(), userController: users, leadController: leads),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return leads;
}

Future<void> _openLeads(WidgetTester tester) async {
  final item = find.byKey(const ValueKey('menu-leads'));
  final group = find.byKey(const ValueKey('menu-group-sales'));
  if (item.evaluate().isEmpty) {
    final drawer = find.byKey(const ValueKey('open-menu'));
    await tester.tap(drawer.evaluate().isNotEmpty ? drawer : group);
    await tester.pumpAndSettle();
  }
  // In the drawer the group may start collapsed (Admin).
  if (item.evaluate().isEmpty) {
    await tester.ensureVisible(group);
    await tester.pumpAndSettle();
    await tester.tap(group);
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

Future<void> _choose(WidgetTester tester, String key, String option) async {
  await _tap(tester, find.byKey(ValueKey(key)));
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _clearSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// The New Lead button: on the web top bar, or the floating button on phones.
Finder get _newLead => find.text('New Lead').first;

void main() {
  setUp(ListTableSwitcher.reset);

  group('Lead rules', () {
    test('one lead per mobile number, however it is typed', () async {
      final c = LeadController();
      final lead = Lead(id: 'x', name: 'Copy', mobile: '+91 98480-11111', source: LeadSource.other, createdAt: DateTime.now());
      await expectLater(c.addLead(lead), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'DUPLICATE_LEAD')));
    });

    test('a follow-up moves the status and next date; won closes it', () async {
      final c = LeadController();
      final today = _today();
      await c.addFollowUp(
        'l3',
        FollowUp(
          id: 'a',
          date: today,
          mode: FollowUpMode.call,
          note: 'Call back Friday',
          status: LeadStatus.interested,
          nextDate: today.add(const Duration(days: 3)),
        ),
      );
      expect(c.leadById('l3')!.status, LeadStatus.interested);
      expect(c.leadById('l3')!.nextFollowUp, today.add(const Duration(days: 3)));

      await c.addFollowUp(
        'l3',
        FollowUp(id: 'b', date: today, mode: FollowUpMode.siteVisit, note: 'Booked', status: LeadStatus.won, nextDate: today),
      );
      expect(c.leadById('l3')!.status, LeadStatus.won);
      expect(c.leadById('l3')!.nextFollowUp, isNull);
      expect(c.leadById('l3')!.followUps.length, 2);
      expect(c.leadById('l3')!.isOverdue(today.add(const Duration(days: 30))), isFalse);
    });

    test('follow-ups cannot be in the future, nor the next one before it', () async {
      final c = LeadController();
      final today = _today();
      Future<void> add(DateTime date, DateTime? next) => c.addFollowUp(
            'l3',
            FollowUp(id: 'z', date: date, mode: FollowUpMode.call, note: 'x', status: LeadStatus.contacted, nextDate: next),
          );
      await expectLater(add(today.add(const Duration(days: 1)), null), throwsA(anything));
      await expectLater(add(today, today.subtract(const Duration(days: 1))), throwsA(anything));
      expect(c.leadById('l3')!.followUps, isEmpty);
    });
  });

  testWidgets('Sales add a lead with its details and first follow-up date', (tester) async {
    for (final size in [_desktop, _phone]) {
      final leads = await _pump(tester, size, 'sales');
      await _openLeads(tester);
      expect(find.text('Open Leads'), findsOneWidget);
      expect(find.byKey(const ValueKey('lead-l1')), findsOneWidget);

      await _tap(tester, _newLead);
      await _tap(tester, find.byKey(const ValueKey('lead-submit')));
      expect(find.text("Please enter the person's name."), findsOneWidget);
      expect(find.text('Enter a 10-digit mobile number.'), findsOneWidget);
      expect(find.text('Please choose the source.'), findsOneWidget);

      await _type(tester, 'lead-name', 'Kavya Sri');
      await _type(tester, 'lead-mobile', '98480 11111'); // Suresh Babu's number.
      await _type(tester, 'lead-area', 'Madhurawada');
      await _choose(tester, 'lead-source', 'Social Media');
      await _choose(tester, 'lead-site', 'Kaira Green Meadows');
      await _tap(tester, find.byKey(const ValueKey('lead-interest-withoutConstruction')));
      await _type(tester, 'lead-budget', '18,00,000');
      await _tap(tester, find.byKey(const ValueKey('lead-submit')));
      expect(find.textContaining('Suresh Babu already has this mobile number'), findsOneWidget);
      await tester.tap(find.text('OK').last);
      await tester.pumpAndSettle();

      await _type(tester, 'lead-mobile', '98480 55555');
      await _tap(tester, find.byKey(const ValueKey('lead-submit')));
      final added = leads.leads.firstWhere((l) => l.name == 'Kavya Sri');
      expect(added.source, LeadSource.socialMedia);
      expect(added.siteName, 'Kaira Green Meadows');
      expect(added.interest, BookingType.withoutConstruction);
      expect(added.budget, 1800000);
      expect(added.status, LeadStatus.newLead);
      expect(added.ownerName, 'Priya Sharma');
      expect(added.nextFollowUp, _today().add(const Duration(days: 1)));
      await _clearSnackBar(tester);
      expect(find.byKey(ValueKey('lead-${added.id}')), findsOneWidget);
    }
  });

  testWidgets('A lead opens full screen; follow-ups and edits update it', (tester) async {
    for (final size in [_desktop, _phone]) {
      final leads = await _pump(tester, size, 'sales');
      await _openLeads(tester);

      // Overdue first, then today's.
      await _tap(tester, find.byKey(const ValueKey('lead-due-overdue')));
      expect(find.byKey(const ValueKey('lead-l2')), findsOneWidget);
      expect(find.byKey(const ValueKey('lead-l1')), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('lead-due-dueToday')));
      await _tap(tester, find.byKey(const ValueKey('lead-l1')));
      expect(find.byType(LeadDetailScreen), findsOneWidget);
      expect(find.textContaining('Next follow-up: Today'), findsOneWidget);
      expect(find.byKey(const ValueKey('follow-up-0')), findsOneWidget);

      // Record the call and book the site visit.
      await _tap(tester, find.byKey(const ValueKey('lead-add-follow-up')));
      await _tap(tester, find.byKey(const ValueKey('follow-up-submit')));
      expect(find.text('Please note what was discussed.'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('follow-up-mode-whatsApp')));
      await _type(tester, 'follow-up-note', 'Will visit the site on Sunday');
      await _choose(tester, 'follow-up-status', 'Site Visit');
      await _tap(tester, find.byKey(const ValueKey('follow-up-submit')));
      final lead = leads.leadById('l1')!;
      expect(lead.followUps.length, 2);
      expect(lead.followUps.last.mode, FollowUpMode.whatsApp);
      expect(lead.status, LeadStatus.siteVisit);
      expect(lead.nextFollowUp, _today().add(const Duration(days: 2)));
      expect(find.text('Will visit the site on Sunday'), findsOneWidget);
      await _clearSnackBar(tester);

      // Edit the details; the follow-ups stay.
      await _tap(tester, find.byKey(const ValueKey('lead-edit')));
      expect(find.text('Edit Lead'), findsOneWidget);
      await _type(tester, 'lead-name', 'Suresh Babu K');
      await _tap(tester, find.byKey(const ValueKey('lead-submit')));
      expect(leads.leadById('l1')!.name, 'Suresh Babu K');
      expect(leads.leadById('l1')!.followUps.length, 2);
      expect(find.text('Suresh Babu K'), findsWidgets);
      await _clearSnackBar(tester);

      // Won: nothing more to follow up.
      await _tap(tester, find.byKey(const ValueKey('lead-add-follow-up')));
      await _type(tester, 'follow-up-note', 'Booked plot 12');
      await _choose(tester, 'follow-up-status', 'Won');
      expect(find.byKey(const ValueKey('follow-up-next')), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('follow-up-submit')));
      expect(leads.leadById('l1')!.status, LeadStatus.won);
      expect(leads.leadById('l1')!.nextFollowUp, isNull);
      expect(find.text('This lead is won.'), findsOneWidget);
      await _clearSnackBar(tester);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(LeadDetailScreen), findsNothing);
    }
  });

  testWidgets('A lead converts to a customer with more details, then books a plot', (tester) async {
    for (final size in [_desktop, _phone]) {
      final leads = await _pump(tester, size, 'sales');
      await _openLeads(tester);
      await _tap(tester, find.byKey(const ValueKey('lead-l1')));

      // Filled in from the lead; the address is needed.
      await _tap(tester, find.byKey(const ValueKey('lead-convert')));
      expect(find.text('Convert to Customer'), findsWidgets);
      await _type(tester, 'convert-address', '');
      await _type(tester, 'convert-alternate', '12');
      await _tap(tester, find.byKey(const ValueKey('convert-submit')));
      expect(find.text("Please enter the customer's address."), findsOneWidget);
      expect(find.text('Enter a 10-digit number, or leave it empty.'), findsOneWidget);
      await _type(tester, 'convert-address', '12-4, Gajuwaka, Vizag');
      await _type(tester, 'convert-alternate', '9000099999');
      await _type(tester, 'convert-occupation', 'Teacher');
      await _tap(tester, find.byKey(const ValueKey('convert-submit')));

      final lead = leads.leadById('l1')!;
      expect(lead.isConverted, isTrue);
      expect(lead.status, LeadStatus.won);
      expect(lead.nextFollowUp, isNull);
      final customer = leads.customers.customers.single;
      expect(customer.name, 'Suresh Babu');
      expect(customer.mobile, '9848011111');
      expect(customer.address, '12-4, Gajuwaka, Vizag');
      expect(customer.alternateMobile, '9000099999');
      expect(customer.source, LeadSource.walkIn);

      // Now on Customers, as a new customer not yet booked.
      expect(find.byType(LeadDetailScreen), findsNothing);
      await _clearSnackBar(tester);
      await _tap(tester, find.byKey(const ValueKey('customer-filter-notBooked')));
      final card = find.byKey(ValueKey('customer-${customer.id}'));
      expect(card, findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('New customer')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('Teacher')), findsOneWidget);

      // Book a Plot starts the booking with their details.
      await _tap(tester, find.byKey(ValueKey('customer-book-${customer.id}')));
      expect(find.text('New Booking'), findsWidgets);
      final name = tester.widget<TextFormField>(
        find.descendant(of: find.byKey(const ValueKey('customer-name')), matching: find.byType(TextFormField)),
      );
      expect(name.controller!.text, 'Suresh Babu');
      await tester.tap(find.byTooltip('Close').last);
      await tester.pumpAndSettle();

      // Converting again is refused; the lead now points to Customers.
      await expectLater(leads.convert('l1', customer), throwsA(isA<ApiException>()));
      await _openLeads(tester);
      await _tap(tester, find.byKey(const ValueKey('lead-l1')));
      expect(find.byKey(const ValueKey('lead-convert')), findsNothing);
      expect(find.byKey(const ValueKey('lead-add-follow-up')), findsNothing);
      expect(find.textContaining('Converted to a customer on'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('lead-view-customer')));
      expect(find.byType(LeadDetailScreen), findsNothing);
      expect(find.byKey(ValueKey('customer-${customer.id}')), findsOneWidget);
    }
  });

  test('one customer per mobile number', () async {
    final c = LeadController();
    final today = _today();
    CustomerProfile details(String mobile) =>
        CustomerProfile(id: '', name: 'X', mobile: mobile, address: 'Vizag', createdAt: today);
    await c.convert('l1', details('9848011111'));
    await expectLater(
      c.convert('l2', details('+91 98480-11111')),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'DUPLICATE_CUSTOMER')),
    );
    expect(c.leadById('l2')!.isConverted, isFalse);
  });

  testWidgets('Leads have a table; Admins see who looks after each', (tester) async {
    await _pump(tester, _desktop, 'admin');
    await _openLeads(tester);
    await _tap(tester, find.byKey(const ValueKey('view-table-leads')));
    expect(find.text('SALES EXECUTIVE'), findsOneWidget);
    expect(find.byKey(const ValueKey('lead-row-l2')), findsOneWidget);
    expect(find.text('Overdue by 2 days'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('lead-row-l3')));
    expect(find.byType(LeadDetailScreen), findsOneWidget);
    expect(find.text('Mohan Rao'), findsWidgets);
  });

  testWidgets('Site staff have no Leads menu', (tester) async {
    await _pump(tester, _desktop, 'incharge');
    expect(find.byKey(const ValueKey('menu-leads')), findsNothing);
  });
}
