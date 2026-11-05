import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/core/controllers/site_controller.dart';
import 'package:real_estate/models/site.dart';
import 'package:real_estate/screens/dashboard/dashboard_screen.dart';
import 'package:real_estate/screens/dashboard/widgets/dashboard_section.dart';
import 'package:real_estate/screens/dashboard/widgets/site_form.dart';

const _phone = Size(360, 780);
const _desktop = Size(1440, 1000);

Future<SiteController> _openAddForm(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final controller = SiteController.test();
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(MaterialApp(home: DashboardScreen(controller: controller)));
  await tester.pumpAndSettle();
  await _openSites(tester);
  await tester.tap(find.text('Add Site'));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _openSites(WidgetTester tester) async {
  final item = find.byKey(ValueKey('menu-${DashboardSection.sites.name}'));
  if (item.evaluate().isEmpty) {
    await tester.tap(find.byKey(const ValueKey('open-menu')));
    await tester.pumpAndSettle();
  }
  await tester.tap(item.last);
  await tester.pumpAndSettle();
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(find.descendant(of: field, matching: find.byType(TextFormField)), text);
  await tester.pump();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final button = find.byKey(ValueKey(key));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String key) => tester
    .widget<TextFormField>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextFormField)))
    .controller!
    .text;

void main() {
  testWidgets('Owner and land come first; Next shows the site fields and saves everything', (tester) async {
    for (final size in [_desktop, _phone]) {
      final controller = await _openAddForm(tester, size);

      // Step 1 only.
      expect(find.text('Step 1 of 2 · Owner & Land'), findsOneWidget);
      expect(find.byKey(const ValueKey('site-owner')), findsOneWidget);
      expect(find.text('Site Name'), findsNothing);

      // Owner and total area are required to move on.
      await _tapKey(tester, 'site-next');
      expect(find.text('Please enter the owner\'s name.'), findsOneWidget);
      expect(find.text('Please enter the total area.'), findsOneWidget);
      expect(find.text('Site Name'), findsNothing);

      await _type(tester, 'site-owner', 'Ramesh Kumar');
      await _type(tester, 'site-total-area', '1,00,000');
      await _type(tester, 'site-sales-area', '70000');
      await _type(tester, 'site-road-area', '20000');
      await _type(tester, 'site-garden-area', '5000.5');
      expect(
        find.descendant(of: find.byKey(const ValueKey('site-area-balance')), matching: find.text('4,999.50 sq yd')),
        findsOneWidget,
      );
      await _tapKey(tester, 'site-next');

      // Step 2: today's fields.
      expect(find.text('Step 2 of 2 · Site Details'), findsOneWidget);
      expect(find.text('Site Name'), findsOneWidget);
      expect(find.byKey(const ValueKey('site-owner')), findsNothing);

      // Back keeps both steps' entries.
      final fields = find.descendant(of: find.byType(SiteForm), matching: find.byType(TextFormField));
      await tester.enterText(fields.at(0), 'Kaira Palm Grove');
      await tester.pump();
      await _tapKey(tester, 'site-back');
      expect(_text(tester, 'site-owner'), 'Ramesh Kumar');
      expect(_text(tester, 'site-road-area'), '20000');
      await _tapKey(tester, 'site-next');
      expect(find.text('Kaira Palm Grove'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('site-location')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('search-dropdown-panel')), matching: find.text('Chennai')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(fields.at(1), '40');
      final addSite = find.descendant(of: find.byType(SiteForm), matching: find.text('Add Site'));
      await tester.ensureVisible(addSite);
      await tester.pumpAndSettle();
      await tester.tap(addSite);
      await tester.pumpAndSettle();

      final site = controller.sites.firstWhere((s) => s.name == 'Kaira Palm Grove');
      expect(site.ownerName, 'Ramesh Kumar');
      expect(site.totalArea, 100000);
      expect(site.salesArea, 70000);
      expect(site.roadArea, 20000);
      expect(site.gardenArea, 5000.5);
      expect(site.otherArea, 0);
      expect(site.totalUnits, 40);
    }
  });

  testWidgets('Areas cannot add up to more than the total', (tester) async {
    await _openAddForm(tester, _phone);
    await _type(tester, 'site-owner', 'Ramesh Kumar');
    await _type(tester, 'site-total-area', '1000');
    await _type(tester, 'site-sales-area', '900');
    await _type(tester, 'site-road-area', '200');

    expect(find.text('Over total area by'), findsOneWidget);
    expect(find.text('100 sq yd'), findsOneWidget);

    await _tapKey(tester, 'site-next');
    expect(find.text('Less than the areas below'), findsOneWidget);
    expect(find.text('Site Name'), findsNothing);

    await _type(tester, 'site-road-area', 'abc');
    await _tapKey(tester, 'site-next');
    expect(find.text('Enter a number'), findsOneWidget);
    expect(find.text('Site Name'), findsNothing);

    await _type(tester, 'site-road-area', '100');
    expect(find.text('Balance Area'), findsOneWidget);
    await _tapKey(tester, 'site-next');
    expect(find.text('Site Name'), findsOneWidget);
  });

  testWidgets('Older sites can be edited without land details; saved details show and prefill', (tester) async {
    tester.view.physicalSize = _desktop;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final controller = SiteController.test();
    await tester.pumpWidget(MaterialApp(home: DashboardScreen(controller: controller)));
    await tester.pumpAndSettle();
    await _openSites(tester);

    Future<void> editFirstSite() async {
      await tester.tap(find.byTooltip('Site actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit site'));
      await tester.pumpAndSettle();
    }

    // s1 has no land details: Next is not blocked, and nothing is invented.
    await editFirstSite();
    await _tapKey(tester, 'site-next');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(controller.siteById('s1')!.hasLandDetails, isFalse);

    // Once entered, the details show on the card and come back in the form.
    final site = controller.siteById('s1')!;
    controller.updateSite(site.copyWith(ownerName: 'Lakshmi Devi', totalArea: 120000, roadArea: 20000));
    await tester.pumpAndSettle();
    expect(find.text('Lakshmi Devi'), findsOneWidget);
    expect(find.text('Total 1,20,000 sq yd'), findsOneWidget);
    expect(find.text('Road 20,000'), findsOneWidget);
    expect(find.textContaining('Garden'), findsNothing);

    await editFirstSite();
    expect(_text(tester, 'site-owner'), 'Lakshmi Devi');
    expect(_text(tester, 'site-total-area'), '120000');
    expect(_text(tester, 'site-sales-area'), '');

    // A site with details cannot lose its owner.
    await _type(tester, 'site-owner', '');
    await _tapKey(tester, 'site-next');
    expect(find.text('Please enter the owner\'s name.'), findsOneWidget);
    await _type(tester, 'site-owner', 'Lakshmi Devi');
    await _tapKey(tester, 'site-next');
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    final saved = controller.siteById('s1')!;
    expect(saved.ownerName, 'Lakshmi Devi');
    expect(saved.totalArea, 120000);
    expect(saved.name, 'Kaira Green Meadows');
  });

  test('Land details survive layout and copy changes', () {
    const site = Site(
      id: 'x',
      name: 'X',
      location: 'Y',
      type: SiteType.plots,
      status: SiteStatus.active,
      totalUnits: 1,
      ownerName: 'Owner',
      totalArea: 500,
      gardenArea: 50,
    );
    final copy = site.copyWith(soldUnits: 1).withPlots(const []);
    expect(copy.ownerName, 'Owner');
    expect(copy.totalArea, 500);
    expect(copy.gardenArea, 50);
    expect(const Site(id: 'y', name: 'Y', location: 'Z', type: SiteType.plots, status: SiteStatus.active, totalUnits: 1).hasLandDetails, isFalse);
  });
}
