import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_estate/core/controllers/booking_controller.dart';
import 'package:real_estate/core/controllers/construction_controller.dart';
import 'package:real_estate/core/controllers/site_controller.dart';
import 'package:real_estate/core/services/material_bill_reader.dart';
import 'package:real_estate/core/utils/material_bill_parser.dart';
import 'package:real_estate/models/booking.dart';
import 'package:real_estate/models/construction.dart';
import 'package:real_estate/models/site.dart';
import 'package:real_estate/screens/construction/construction_screen.dart';
import 'package:real_estate/screens/construction/widgets/material_bill_form.dart';
import 'package:real_estate/widgets/app_file_field.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;

/// A short bill with every rate, to scan more than once.
const _repeatBill = '''
Sri Sai Traders
Invoice No: SST/300        Date: 20/10/2026
S.No  Description  HSN  Qty  Unit  Rate  Amount
1  Cement OPC 53  2523  100  Bags  390.00  39,000.00
''';

const _sampleBill = '''
Sri Sai Traders
12-4, Main Road, Vizag
GSTIN: 37ABCDE1234F1Z5
Invoice No: SST/245        Date: 14/10/2026
Bill To: Kiran Varma
S.No  Description  HSN  Qty  Unit  Rate  Amount
1  Cement OPC 53  2523  200  Bags  380.00  76,000.00
2  TMT 12 mm  7214  2500  Kg  62.50  1,56,250.00
3  Red Bricks  6904  1000 Nos  8  8,000
4  Binding Wire  10 kg
Sub Total  2,40,250.00
CGST 9%  21,622.50
Grand Total  2,83,495.00
''';

void main() {
  group('MaterialBillParser', () {
    final now = DateTime(2026, 11, 5);

    test('Reads the items and details of a typical bill', () {
      final bill = MaterialBillParser.parse(_sampleBill, now: now);

      expect(bill.supplier, 'Sri Sai Traders');
      expect(bill.billNumber, 'SST/245');
      expect(bill.date, DateTime(2026, 10, 14));
      expect(bill.total, 283495);

      expect(bill.lines.map((l) => l.name), ['Cement OPC 53', 'TMT 12 mm', 'Red Bricks', 'Binding Wire']);
      expect(bill.lines[0].quantity, 200);
      expect(bill.lines[0].unit, 'bags');
      expect(bill.lines[0].rate, 380);
      expect(bill.lines[0].needsCheck, isFalse);
      expect(bill.lines[1].quantity, 2500);
      expect(bill.lines[1].rate, 62.5);
      expect(bill.lines[1].unit, 'kg');
      expect(bill.lines[2].unit, 'nos');

      // A row with no rate is kept, flagged for the user to complete.
      expect(bill.lines[3].rate, 0);
      expect(bill.lines[3].needsCheck, isTrue);
    });

    test('Handles other row layouts', () {
      ParsedBillLine one(String row) => MaterialBillParser.parse(row, now: now).lines.single;

      // Without a header, with symbols and units joined to numbers.
      final symbols = one('River Sand 10 loads @ Rs. 6,500/- = ₹65,000');
      expect([symbols.name, symbols.quantity, symbols.unit, symbols.rate], ['River Sand', 10, 'loads', 6500]);

      final joined = one('Cement 50kg 200Bags 380 76000');
      expect([joined.name, joined.quantity, joined.unit], ['Cement 50 kg', 200, 'bags']);

      final squareFeet = one('Floor Tiles 500 sq.ft 45 22500');
      expect([squareFeet.quantity, squareFeet.unit], [500, 'sqft']);

      // A tax column after the amount does not confuse the columns.
      final taxed = one('Paint 20 Ltr 300 6000 18% 1080 7080');
      expect([taxed.quantity, taxed.unit, taxed.rate], [20, 'litres', 300]);

      // Unit in the name.
      final unitInName = one('Sand Bags 2 380 760');
      expect([unitInName.name, unitInName.quantity, unitInName.unit, unitInName.needsCheck], ['Sand', 2, 'bags', false]);

      // A serial number that happens to multiply out is not the quantity.
      expect(MaterialBillParser.parse('2 Sand Bags 380 760', now: now).lines, isEmpty);
      final serial = one('1 Binding Wire 1 kg 380 380');
      expect([serial.name, serial.quantity, serial.unit, serial.rate], ['Binding Wire', 1, 'kg', 380]);

      // No unit anywhere: the numbers are right but it gets flagged.
      final noUnit = one('Binding Wire 2 60 120');
      expect([noUnit.quantity, noUnit.rate, noUnit.unit, noUnit.needsCheck], [2, 60, 'nos', true]);

      // Amount that does not match is flagged, not trusted.
      final discounted = one('Jelly 4 loads 7000 26000');
      expect([discounted.quantity, discounted.rate, discounted.needsCheck], [4, 7000, true]);
    });

    test('An item row is not mistaken for the supplier', () {
      final bill = MaterialBillParser.parse('Cement  200 bags  380  76000\nSteel  100 kg  62  6200', now: now);
      expect(bill.supplier, '');
      expect(bill.lines.length, 2);
    });

    test('Leaves out rows that are not items', () {
      final bill = MaterialBillParser.parse(
        'Phone 98765 43210 1\n'
        'CGST 2 100 200\n'
        'Net weight 50 kg\n'
        'Total 2 100 200\n',
        now: now,
      );
      expect(bill.lines, isEmpty);
    });

    test('Ignores impossible and far-off dates', () {
      expect(MaterialBillParser.parse('Date: 31/02/2026', now: now).date, isNull);
      expect(MaterialBillParser.parse('Date: 14/10/1998', now: now).date, isNull);
      expect(MaterialBillParser.parse('Date: 14/10/2036', now: now).date, isNull);
      expect(MaterialBillParser.parse('Dated 5-Oct-26', now: now).date, DateTime(2026, 10, 5));
      expect(
        MaterialBillParser.parse('Due Date: 20/11/2026\nInvoice Date: 01/11/2026', now: now).date,
        DateTime(2026, 11, 1),
      );
    });

    test('Puts OCR boxes back into table rows', () {
      // OCR returns columns; the order here is column by column.
      final text = MaterialBillParser.rowsFromBoxes(const [
        BillTextBox(text: 'Cement', left: 10, right: 60, top: 100, bottom: 120),
        BillTextBox(text: 'Steel', left: 10, right: 60, top: 130, bottom: 150),
        BillTextBox(text: '200 bags', left: 200, right: 250, top: 102, bottom: 122),
        BillTextBox(text: '100 kg', left: 200, right: 250, top: 131, bottom: 151),
        BillTextBox(text: '380', left: 300, right: 330, top: 99, bottom: 119),
        BillTextBox(text: '62', left: 300, right: 330, top: 129, bottom: 149),
        BillTextBox(text: '76000', left: 400, right: 450, top: 101, bottom: 121),
        BillTextBox(text: '6200', left: 400, right: 450, top: 130, bottom: 150),
      ]);
      expect(text, 'Cement  200 bags  380  76000\nSteel  100 kg  62  6200');
      expect(MaterialBillParser.parse(text, now: now).lines.map((l) => l.amountForTest), [76000, 6200]);
    });
  });

  group('MaterialBillReader', () {
    test('Reads a real table PDF through to items', () {
      final bytes = _tablePdf();
      final text = MaterialBillReader.extractPdfText(bytes);
      final bill = MaterialBillParser.parse(text, now: DateTime(2026, 11, 5));

      expect(bill.supplier, 'Sri Sai Traders');
      expect(bill.billNumber, 'SST/245');
      expect(bill.date, DateTime(2026, 10, 14));
      expect(bill.lines.map((l) => l.name), ['Cement OPC 53', 'TMT Steel 12 mm']);
      expect(bill.lines.map((l) => l.quantity), [200, 2500]);
      expect(bill.lines.map((l) => l.rate), [380, 62.5]);
      expect(bill.lines.every((l) => !l.needsCheck), isTrue);
    });

    test('Reads a bill whose PDF stores the table column by column', () {
      // Drawn in the same scrambled order as a real supplier invoice:
      // amount, quantity, name, serial, unit, rate.
      const rows = [
        ['16M METAL PLATE LEG ALLZY', '5', '274.27', '1371.35'],
        ['6A SWITCH LEG ALLZY', '72', '23.50', '1692.00'],
        ['32A DP SWITCH WITH IND LEG ALL', '4', '180.39', '721.56'],
        ['CEILING ROSE GM', '15', '32.00', '480.00'],
      ];
      final document = pdf.PdfDocument();
      final page = document.pages.add();
      final font = pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 10);
      void text(String value, double x, double y) =>
          page.graphics.drawString(value, font, bounds: Rect.fromLTWH(x, y, 220, 14));

      text('VISAKA ELECTRICALS AND HARDW', 50, 0);
      text('ARES', 214, 0); // One word, split in two.
      text('To : KAIRA PROPERTIES', 15, 30);
      text('E.No : E-1442', 243, 30);
      text('TIRUPUR', 36, 42);
      text('Date : 24-10-2026', 243, 42);
      text('Amount', 345, 70);
      text('Rate', 290, 70);
      text('Qty', 247, 70);
      text('S.No', 15, 70);
      text('PARTICULARS', 78, 70);
      for (var i = 0; i < rows.length; i++) {
        final y = 90.0 + i * 12;
        text(rows[i][3], 345, y);
        text(rows[i][1], 240, y);
        text(rows[i][0], 39, y);
        text('${i + 1}', 20, y);
        text('No', 255, y);
        text(rows[i][2], 293, y);
      }
      text('Round Off', 200, 160);
      text('0.08', 350, 160);
      text('Total Qty : 96.00', 15, 160);
      text('16099.00', 345, 172);
      text('Net Amount', 200, 172);
      text('Total Items : 4', 15, 172);
      final bytes = Uint8List.fromList(document.saveSync());
      document.dispose();

      final bill = MaterialBillParser.parse(MaterialBillReader.extractPdfText(bytes), now: DateTime(2026, 11, 5));

      expect(bill.supplier, 'VISAKA ELECTRICALS AND HARDWARES');
      expect(bill.billNumber, 'E-1442');
      expect(bill.date, DateTime(2026, 10, 24));
      expect(bill.total, 16099);
      expect(bill.lines.map((l) => l.name), rows.map((r) => r[0]));
      expect(bill.lines.map((l) => l.quantity), [5, 72, 4, 15]);
      expect(bill.lines.map((l) => l.rate), [274.27, 23.5, 180.39, 32]);
      expect(bill.lines.every((l) => l.unit == 'nos' && !l.needsCheck), isTrue);
    });

    test('Rows of different pages are kept apart', () {
      final document = pdf.PdfDocument();
      final font = pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 10);
      for (final row in ['Cement 200 bags 380 76000', 'Steel 100 kg 62 6200']) {
        document.pages.add().graphics.drawString(row, font, bounds: const Rect.fromLTWH(0, 0, 300, 14));
      }
      final bytes = Uint8List.fromList(document.saveSync());
      document.dispose();

      final bill = MaterialBillParser.parse(MaterialBillReader.extractPdfText(bytes));
      expect(bill.lines.map((l) => l.name), ['Cement', 'Steel']);
    });

    test('A PDF without text, and a broken file, say why', () async {
      final blank = pdf.PdfDocument()..pages.add();
      final blankBytes = Uint8List.fromList(await blank.save());
      blank.dispose();

      await expectLater(
        MaterialBillReader.read(SiteFile(name: 'scan.pdf', bytes: blankBytes)),
        throwsA(isA<BillReadException>().having((e) => e.message, 'message', contains('scanned copy'))),
      );
      await expectLater(
        MaterialBillReader.read(SiteFile(name: 'bad.pdf', bytes: Uint8List.fromList([1, 2, 3]))),
        throwsA(isA<BillReadException>().having((e) => e.message, 'message', contains('Could not read this PDF'))),
      );
    });
  });

  group('Money with paise', () {
    test('A bill with paise can be paid off exactly', () {
      final c = _controller();
      final project = c.projectById('b3')!;
      c.addMaterial(
        'b3',
        MaterialEntry(id: 'p', date: DateTime(2026, 10, 1), name: 'Paint', quantity: 3.3, unit: 'litres', rate: 412.35),
      );
      expect(project.materialDue('p'), 1360.76);

      c.addPayment(
        'b3',
        ExpensePayment(id: 'x', kind: ExpenseKind.material, targetId: 'p', amount: 1000.1, date: DateTime(2026, 10, 2), method: PaymentMethod.cash),
      );
      c.addPayment(
        'b3',
        ExpensePayment(id: 'y', kind: ExpenseKind.material, targetId: 'p', amount: 360.66, date: DateTime(2026, 10, 2), method: PaymentMethod.cash),
      );
      expect(project.materialDue('p'), 0);
    });
  });

  group('Materials tab', () {
    const phone = Size(360, 780);
    const desktop = Size(1440, 1000);

    setUp(() => BillFilePreview.builderOverride = (file) => Text('Preview of ${file.name}'));

    tearDown(() {
      BillFilePreview.builderOverride = null;
      AppFileField.pickOverride = null;
      MaterialBillReader.captureOverride = null;
      MaterialBillReader.readTextOverride = null;
    });

    testWidgets('Upload a bill, review and edit its items, save, then view and edit it', (tester) async {
      AppFileField.pickOverride = (extensions) async {
        expect(extensions, contains('pdf'));
        return SiteFile(name: 'bill.pdf', bytes: Uint8List(4));
      };
      MaterialBillReader.readTextOverride = (_) async => _sampleBill;

      for (final size in [desktop, phone]) {
        final c = _controller();
        final project = c.projectById('b3')!;
        final before = project.materials.length;
        await _pumpMaterials(tester, c, size);

        await _tap(tester, find.byKey(const ValueKey('bill-upload')));
        expect(find.text('Review Bill'), findsOneWidget);
        expect(_fieldText(tester, 'bill-supplier'), 'Sri Sai Traders');
        expect(_fieldText(tester, 'bill-number'), 'SST/245');
        expect(find.text('Cement OPC 53'), findsOneWidget);
        expect(find.text('Add the rate for this item'), findsOneWidget);
        expect(find.byKey(const ValueKey('bill-total-difference')), findsOneWidget);

        // The wire has no rate yet, so it cannot be saved.
        await _tap(tester, find.byKey(const ValueKey('bill-submit')));
        expect(find.text('Add the quantity and rate for the highlighted items.'), findsOneWidget);
        expect(project.materials.length, before);

        // Fill it in.
        await _tap(tester, find.byKey(const ValueKey('bill-item-edit-3')));
        expect(find.text('Edit Material'), findsOneWidget);
        expect(find.byKey(const ValueKey('material-supplier')), findsNothing);
        await _type(tester, 'material-rate', '75');
        await _tap(tester, find.byKey(const ValueKey('material-submit')));
        expect(find.text('Binding Wire'), findsOneWidget);
        expect(find.text('Add the rate for this item'), findsNothing);

        // Remove one, add one.
        await _tap(tester, find.byKey(const ValueKey('bill-item-delete-2')));
        expect(find.text('Save 3 Items'), findsOneWidget);
        await _tap(tester, find.byKey(const ValueKey('bill-add-item')));
        await _type(tester, 'material-name', 'Transport');
        await _type(tester, 'material-quantity', '1');
        await _type(tester, 'material-rate', '3000');
        await _tap(tester, find.byKey(const ValueKey('material-submit')));

        await _tap(tester, find.byKey(const ValueKey('bill-submit')));
        expect(project.materials.length, before + 4);
        expect(project.bills.length, 1);
        final bill = project.bills.single;
        expect(bill.billNumber, 'SST/245');

        final saved = project.materialsOfBill(bill.id);
        expect(saved.map((m) => m.name), ['Cement OPC 53', 'TMT 12 mm', 'Binding Wire', 'Transport']);
        expect(saved.every((m) => m.supplier == 'Sri Sai Traders' && m.date == DateTime(2026, 10, 14)), isTrue);
        expect(saved[1].amount, 156250);
        await _clearSnackBar(tester);

        // View the saved bill and edit an item from there; the view updates.
        await _tap(tester, find.byKey(ValueKey('view-bill-${saved[2].id}')));
        expect(find.text('Material Bill'), findsOneWidget);
        await _tap(tester, find.byKey(ValueKey('saved-bill-item-edit-${saved[2].id}')));
        await _type(tester, 'material-name', 'Binding Wire 18G');
        await _tap(tester, find.byKey(const ValueKey('material-submit')));
        expect(project.materialById(saved[2].id)!.name, 'Binding Wire 18G');
        expect(project.materialById(saved[2].id)!.billId, bill.id);
        expect(find.descendant(of: find.byKey(ValueKey('saved-bill-item-${saved[2].id}')), matching: find.text('Binding Wire 18G')), findsOneWidget);
      }
    });

    testWidgets('A bill scanned again is warned about; its items add to the quantities, with history', (tester) async {
      var bytes = Uint8List.fromList([1, 2, 3, 4]);
      AppFileField.pickOverride = (_) async => SiteFile(name: 'bill.pdf', bytes: bytes);
      MaterialBillReader.readTextOverride = (_) async => _repeatBill;

      final c = _controller();
      final project = c.projectById('b3')!;
      final before = project.materials.length;
      await _pumpMaterials(tester, c, desktop);

      await _tap(tester, find.byKey(const ValueKey('bill-upload')));
      await _tap(tester, find.byKey(const ValueKey('bill-submit')));
      expect(project.materials.length, before + 1);
      final cement = project.materials.last;
      expect(cement.quantity, 100);
      await _clearSnackBar(tester);

      // The same file again: asked first, and Cancel stops there.
      await _tap(tester, find.byKey(const ValueKey('bill-upload')));
      expect(find.byKey(const ValueKey('duplicate-bill')), findsOneWidget);
      expect(find.textContaining('This bill was already scanned on'), findsOneWidget);
      expect(find.textContaining('(Bill SST/300)'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('duplicate-cancel')));
      expect(find.text('Review Bill'), findsNothing);
      expect(project.bills.length, 1);

      // Adding it again adds to the cement, not a second cement.
      await _tap(tester, find.byKey(const ValueKey('bill-upload')));
      await _tap(tester, find.byKey(const ValueKey('duplicate-confirm')));
      await _tap(tester, find.byKey(const ValueKey('bill-submit')));
      expect(project.bills.length, 2);
      expect(project.materials.length, before + 1);
      expect(project.materialById(cement.id)!.quantity, 200);
      await _clearSnackBar(tester);

      // Another copy of the same bill (same number and supplier) at a new price:
      // asked when saving.
      bytes = Uint8List.fromList([9, 9, 9]);
      MaterialBillReader.readTextOverride = (_) async => _repeatBill.replaceAll('390.00', '400.00');
      await _tap(tester, find.byKey(const ValueKey('bill-upload')));
      expect(find.text('Review Bill'), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('bill-submit')));
      expect(find.byKey(const ValueKey('duplicate-bill')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('duplicate-confirm')));
      expect(find.text('Review Bill'), findsNothing);
      final updated = project.materialById(cement.id)!;
      expect(updated.quantity, 300);
      expect(updated.rate, 400);
      expect(updated.amount, 120000);
      expect(updated.receipts.map((r) => r.rate), [390, 390, 400]);
      expect(project.materialsOfBill(project.bills.last.id).single.quantity, 100);
      await _clearSnackBar(tester);

      // The history: every scan, newest first, with its price and date.
      await _tap(tester, find.byKey(ValueKey('material-history-${cement.id}')));
      expect(find.byKey(const ValueKey('material-history')), findsOneWidget);
      expect(find.textContaining('Received 3 times'), findsWidgets);
      expect(find.byKey(const ValueKey('history-row-2')), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const ValueKey('history-row-0')), matching: find.textContaining('at ₹400')),
        findsOneWidget,
      );
      expect(find.textContaining('Scanned on'), findsNWidgets(3));
    });

    testWidgets('The uploaded bill stays in view next to the list, for comparing', (tester) async {
      AppFileField.pickOverride = (_) async => SiteFile(name: 'bill.pdf', bytes: Uint8List(4));
      MaterialBillReader.readTextOverride = (_) async => _sampleBill;
      const preview = 'Preview of bill.pdf';

      // Side by side on web: the bill to the left of the list.
      final wideController = _controller();
      await _pumpMaterials(tester, wideController, desktop);
      await _tap(tester, find.byKey(const ValueKey('bill-upload')));
      expect(find.text(preview), findsOneWidget);
      expect(find.byKey(const ValueKey('bill-toggle')), findsNothing);
      expect(
        tester.getTopLeft(find.text(preview)).dx,
        lessThan(tester.getTopLeft(find.byKey(const ValueKey('bill-item-0'))).dx),
      );

      // Stacked on mobile: the bill above the list, and it can be hidden.
      await _pumpMaterials(tester, _controller(), phone);
      await _tap(tester, find.byKey(const ValueKey('bill-upload')));
      expect(find.text(preview), findsOneWidget);
      expect(
        tester.getTopLeft(find.text(preview)).dy,
        lessThan(tester.getTopLeft(find.text('Review Bill')).dy),
      );
      expect(tester.getTopLeft(find.text('Review Bill')).dy, lessThan(phone.height));

      await _tap(tester, find.byKey(const ValueKey('bill-toggle')));
      expect(find.text(preview), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('bill-toggle')));
      expect(find.text(preview), findsOneWidget);

      // Hiding and full screen keep what was edited in the list.
      await _tap(tester, find.byKey(const ValueKey('bill-item-delete-0')));
      await _tap(tester, find.byKey(const ValueKey('bill-toggle')));
      await _tap(tester, find.byKey(const ValueKey('bill-open-file')));
      expect(find.text(preview), findsOneWidget);
      expect(find.text('Review Bill'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Save 3 Items'), findsOneWidget);

      // Cancel returns to the materials, with nothing saved.
      await _tap(tester, find.text('Cancel'));
      expect(find.byKey(const ValueKey('bill-upload')), findsOneWidget);
    });

    testWidgets('A saved bill opens next to its items too', (tester) async {
      final c = _controller();
      final project = c.projectById('b3')!;
      c.addMaterialBill(
        'b3',
        MaterialBill(id: 'mb', file: SiteFile(name: 'saved.pdf', bytes: Uint8List(4)), date: DateTime(2026, 10, 1)),
        [MaterialEntry(id: 's1', date: DateTime(2026, 10, 1), name: 'Socket', quantity: 2, unit: 'nos', rate: 90, billId: 'mb')],
      );
      await _pumpMaterials(tester, c, phone);

      await _tap(tester, find.byKey(const ValueKey('view-bill-s1')));
      expect(find.text('Preview of saved.pdf'), findsOneWidget);
      expect(find.byKey(const ValueKey('saved-bill-item-s1')), findsOneWidget);
      expect(project.materialsOfBill('mb').length, 1);
    });

    testWidgets('A bill that cannot be read opens for entry by hand', (tester) async {
      AppFileField.pickOverride = (_) async => SiteFile(name: 'scan.pdf', bytes: Uint8List(4));
      MaterialBillReader.readTextOverride = (_) async => '   ';

      final c = _controller();
      await _pumpMaterials(tester, c, const Size(360, 780));
      await _tap(tester, find.byKey(const ValueKey('bill-upload')));

      expect(find.byKey(const ValueKey('bill-notice')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('bill-submit')));
      expect(find.text('Add at least one item from this bill.'), findsOneWidget);
      expect(c.projectById('b3')!.bills, isEmpty);
    });

    testWidgets('A photo is read like a file; camera and cancel are handled', (tester) async {
      var photo = true;
      MaterialBillReader.captureOverride = () async => photo ? SiteFile(name: 'bill.jpg', bytes: Uint8List(4)) : null;
      MaterialBillReader.readTextOverride = (file) async {
        expect(file.name, 'bill.jpg');
        return 'Cement  200 bags  380  76000';
      };

      final c = _controller();
      await _pumpMaterials(tester, c, const Size(360, 780));

      photo = false;
      await _tap(tester, find.byKey(const ValueKey('bill-camera')));
      expect(find.text('Review Bill'), findsNothing);

      photo = true;
      await _tap(tester, find.byKey(const ValueKey('bill-camera')));
      expect(find.text('Review Bill'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('bill-item-0')), matching: find.text('Cement')), findsOneWidget);
      expect(_fieldText(tester, 'bill-supplier'), '');
    });

    testWidgets('A material cannot be edited below what is already paid', (tester) async {
      final c = _controller();
      final project = c.projectById('b3')!;
      await _pumpMaterials(tester, c, const Size(1440, 1000));

      // m2 is ₹1,55,000 with ₹1,00,000 paid.
      await _tap(tester, find.byKey(const ValueKey('edit-material-m2')));
      expect(find.text('Edit Material'), findsOneWidget);
      await _type(tester, 'material-rate', '10');
      await _tap(tester, find.byKey(const ValueKey('material-submit')));
      expect(find.text('₹1,00,000 is already paid on this material.'), findsOneWidget);
      expect(project.materialById('m2')!.rate, 62);

      await _type(tester, 'material-rate', '64');
      await _tap(tester, find.byKey(const ValueKey('material-submit')));
      expect(project.materialById('m2')!.rate, 64);
      expect(project.materialById('m2')!.supplier, 'Vizag Steels Dealer');
      expect(project.materialDue('m2'), 60000);
    });
  });
}

extension on ParsedBillLine {
  double get amountForTest => quantity * rate;
}

ConstructionController _controller() => ConstructionController(BookingController(SiteController.test()));

Future<void> _pumpMaterials(WidgetTester tester, ConstructionController c, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const SizedBox());
  await tester.pumpWidget(
    MaterialApp(
      home: ConstructionScreen(
        projectId: 'b3',
        controller: c,
        userName: 'Suresh Reddy',
        initialTab: ConstructionTab.materials,
      ),
    ),
  );
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

String _fieldText(WidgetTester tester, String key) => tester
    .widget<TextFormField>(find.descendant(of: find.byKey(ValueKey(key)), matching: find.byType(TextFormField)))
    .controller!
    .text;

Future<void> _clearSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

/// A real PDF with a drawn table, like an invoice exported from billing
/// software.
Uint8List _tablePdf() {
  final document = pdf.PdfDocument();
  final page = document.pages.add();
  final font = pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 11);

  void text(String value, double x, double y) =>
      page.graphics.drawString(value, font, bounds: Rect.fromLTWH(x, y, 300, 20));

  text('Sri Sai Traders', 0, 0);
  text('Invoice No: SST/245', 0, 20);
  text('Date: 14/10/2026', 300, 20);

  const rows = [
    ['Description', 'Qty', 'Unit', 'Rate', 'Amount'],
    ['Cement OPC 53', '200', 'Bags', '380.00', '76,000.00'],
    ['TMT Steel 12 mm', '2500', 'Kg', '62.50', '1,56,250.00'],
  ];
  const columns = [0.0, 180.0, 240.0, 300.0, 380.0];
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < columns.length; c++) {
      text(rows[r][c], columns[c], 60.0 + r * 20);
    }
  }
  text('Grand Total 2,32,250.00', 300, 140);

  final bytes = Uint8List.fromList(document.saveSync());
  document.dispose();
  return bytes;
}
