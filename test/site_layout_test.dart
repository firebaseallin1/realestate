import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/core/controllers/site_controller.dart';
import 'package:real_estate/models/site.dart';
import 'package:real_estate/screens/dashboard/dashboard_screen.dart';
import 'package:real_estate/screens/dashboard/widgets/dashboard_section.dart';
import 'package:real_estate/screens/site_layout/site_layout_screen.dart';
import 'package:real_estate/screens/site_layout/widgets/plot_canvas.dart';
import 'package:real_estate/widgets/app_file_field.dart';

/// A valid 1×1 PNG, so image previews have something real to decode.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<SiteController> _pumpLayout(WidgetTester tester, Size size, {String siteId = 's3'}) async {
  _setSize(tester, size);
  final controller = SiteController.test();
  await tester.pumpWidget(
    MaterialApp(home: SiteLayoutScreen(siteId: siteId, controller: controller)),
  );
  await tester.pumpAndSettle();
  return controller;
}

/// Turns drawing on (it stays on between plots) and drags a box across
/// the middle of the layout.
Future<void> _drawPlot(WidgetTester tester) async {
  if (find.text('Draw Plot').evaluate().isNotEmpty) {
    await tester.tap(find.text('Draw Plot'));
    await tester.pumpAndSettle();
  }
  final canvas = tester.getRect(find.byType(PlotCanvas));
  final start = canvas.topLeft + Offset(canvas.width * 0.3, canvas.height * 0.3);
  final gesture = await tester.startGesture(start);
  await gesture.moveBy(const Offset(20, 20));
  await gesture.moveBy(Offset(canvas.width * 0.15, canvas.height * 0.15));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  const desktop = Size(1440, 1000);
  const phone = Size(360, 780);

  group('Site layout model', () {
    test('Plots set the unit counts', () {
      const site = Site(
        id: 'x',
        name: 'Test',
        location: 'Pune',
        type: SiteType.plots,
        status: SiteStatus.active,
        totalUnits: 99,
        soldUnits: 50,
      );
      Plot plot(String n, PlotStatus s) => Plot(
            id: n,
            number: n,
            widthFt: 30,
            lengthFt: 40,
            facing: PlotFacing.east,
            status: s,
            rect: const Rect.fromLTWH(0, 0, 0.1, 0.1),
          );

      final mapped = site.withPlots([
        plot('1', PlotStatus.sold),
        plot('2', PlotStatus.booked),
        plot('3', PlotStatus.available),
        plot('4', PlotStatus.available),
      ]);
      expect(mapped.totalUnits, 4);
      expect(mapped.soldUnits, 1);
      expect(mapped.bookedUnits, 1);
      expect(mapped.availableUnits, 2);
      expect(mapped.plots.first.areaSqYd, closeTo(133.3, 0.1));
      expect(mapped.plots.first.sizeLabel, '30 × 40 ft');
    });

    test('Attachment helpers', () {
      final pdf = SiteFile(name: 'Brochure.PDF', bytes: Uint8List(2048));
      expect(pdf.isPdf, isTrue);
      expect(pdf.isImage, isFalse);
      expect(pdf.sizeLabel, '2 KB');
      expect(SiteFile(name: 'map.jpeg', bytes: _png).isImage, isTrue);
    });
  });

  for (final entry in {'desktop': desktop, 'phone': phone}.entries) {
    testWidgets('Draw, edit and delete a plot (${entry.key})', (tester) async {
      final controller = await _pumpLayout(tester, entry.value);
      expect(find.text('Nothing drawn yet'), findsOneWidget);

      await _drawPlot(tester);
      expect(find.text('New Plot'), findsOneWidget);
      // Number is suggested, size prefilled 30 × 40.
      await tester.tap(find.text('Add Plot'));
      await tester.pumpAndSettle();

      var site = controller.siteById('s3')!;
      expect(site.plots, hasLength(1));
      expect(site.plots.single.number, '1');
      expect(site.totalUnits, 1);
      expect(find.text('Available 1'), findsOneWidget);

      // Stop drawing, tap the plot on the map to edit it.
      await tester.tap(find.text('Done Drawing'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('plot-${site.plots.single.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Plot 1'), findsOneWidget);

      await tester.tap(find.byTooltip('Delete plot'));
      await tester.pumpAndSettle();
      site = controller.siteById('s3')!;
      expect(site.plots, isEmpty);
    });
  }

  testWidgets('Plot numbers must be unique', (tester) async {
    await _pumpLayout(tester, desktop);

    await _drawPlot(tester);
    await tester.tap(find.text('Add Plot'));
    await tester.pumpAndSettle();

    await _drawPlot(tester);
    final numberField = find.widgetWithText(TextFormField, '2');
    await tester.enterText(numberField, '1');
    await tester.tap(find.text('Add Plot'));
    await tester.pumpAndSettle();
    expect(find.text('Plot 1 already exists.'), findsOneWidget);
  });

  testWidgets('Site map and brochure attach through the site form', (tester) async {
    AppFileField.pickOverride = (extensions) async => extensions.contains('pdf')
        ? SiteFile(name: 'brochure.pdf', bytes: Uint8List(4096))
        : SiteFile(name: 'layout.png', bytes: _png);
    addTearDown(() => AppFileField.pickOverride = null);

    _setSize(tester, desktop);
    final controller = SiteController.test();
    await tester.pumpWidget(MaterialApp(home: DashboardScreen(controller: controller)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('menu-${DashboardSection.sites.name}')));
    await tester.pumpAndSettle();

    // Edit the first site (Kaira Green Meadows, s1) from its menu.
    await tester.tap(find.byTooltip('Site actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit site'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('site-next')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Upload site map'));
    await tester.tap(find.text('Upload site map'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Upload brochure'));
    await tester.tap(find.text('Upload brochure'));
    await tester.pumpAndSettle();
    expect(find.text('layout.png'), findsOneWidget);
    expect(find.text('brochure.pdf'), findsOneWidget);

    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    final site = controller.siteById('s1')!;
    expect(site.siteMap?.name, 'layout.png');
    expect(site.brochure?.name, 'brochure.pdf');
    expect(find.text('Site map'), findsOneWidget);
    expect(find.text('Brochure'), findsOneWidget);
  });

  testWidgets('Card menu opens the plot layout', (tester) async {
    _setSize(tester, desktop);
    await tester.pumpWidget(MaterialApp(home: DashboardScreen(controller: SiteController.test())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('menu-${DashboardSection.sites.name}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Site actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Plot layout'));
    await tester.pumpAndSettle();

    expect(find.byType(SiteLayoutScreen), findsOneWidget);
    expect(find.text('PLOT LAYOUT'), findsOneWidget);
  });

  testWidgets('A failed upload explains itself under the field', (tester) async {
    AppFileField.pickOverride = (_) async => throw UnimplementedError('pickFile() has not been implemented.');
    addTearDown(() => AppFileField.pickOverride = null);

    _setSize(tester, desktop);
    await tester.pumpWidget(MaterialApp(home: DashboardScreen(controller: SiteController.test())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('menu-${DashboardSection.sites.name}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Site'));
    await tester.pumpAndSettle();
    final landFields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextFormField));
    await tester.enterText(landFields.at(0), 'Ramesh Kumar');
    await tester.enterText(landFields.at(1), '1000');
    await tester.tap(find.byKey(const ValueKey('site-next')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Upload site map'));
    await tester.tap(find.text('Upload site map'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Stop the app and run it again'), findsOneWidget);
  });
}