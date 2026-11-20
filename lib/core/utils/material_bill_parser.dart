import '../api/json.dart';
import 'money_text.dart';

/// One item read off a bill. [needsCheck] marks a line the parser could not
/// confirm, e.g. quantity × rate did not match an amount printed on the line.
class ParsedBillLine {
  final String name;
  final double quantity;
  final String unit;

  /// 0 when the bill prints no rate, e.g. a delivery challan.
  final double rate;
  final bool needsCheck;

  const ParsedBillLine({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.rate,
    this.needsCheck = false,
  });
}

/// What could be read from a bill. Anything not found stays empty or null,
/// for the user to fill in while reviewing.
class ParsedBill {
  final String supplier;
  final String billNumber;
  final DateTime? date;

  /// The total printed on the bill, which may include tax and transport.
  final double? total;
  final List<ParsedBillLine> lines;

  const ParsedBill({
    this.supplier = '',
    this.billNumber = '',
    this.date,
    this.total,
    this.lines = const [],
  });

  /// A bill as read by the server's AI reader (POST /bills/read).
  factory ParsedBill.fromServer(Map<String, dynamic> json) => ParsedBill(
    supplier: json['supplier'] as String? ?? '',
    billNumber: json['billNumber'] as String? ?? '',
    date: json['date'] == null ? null : dayFromJson(json['date'] as String),
    total: json['totalPaise'] == null ? null : fromPaise(json['totalPaise'] as num),
    lines: [
      for (final row in json['lines'] as List<dynamic>)
        ParsedBillLine(
          name: (row as Map<String, dynamic>)['name'] as String,
          quantity: (row['quantity'] as num).toDouble(),
          unit: row['unit'] as String,
          rate: fromPaise(row['ratePaise'] as num),
          needsCheck: row['needsCheck'] as bool? ?? false,
        ),
    ],
  );
}

/// A piece of text and where it sits on the photo or PDF page.
class BillTextBox {
  final String text;
  final double left;
  final double right;
  final double top;
  final double bottom;

  const BillTextBox({
    required this.text,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  double get center => (top + bottom) / 2;
  double get height => bottom - top;
}

class _Token {
  final String text;
  final double? number;
  final String? unit;

  const _Token(this.text, {this.number, this.unit});

  bool get isNumber => number != null;
}

/// MaterialBillParser turns the text of a material bill into items, using
/// the arithmetic on each row: quantity × rate = amount tells the item rows
/// and the columns apart without knowing the bill's layout.
class MaterialBillParser {
  MaterialBillParser._();

  static const _unitAliases = {
    'bag': 'bags',
    'bags': 'bags',
    'bgs': 'bags',
    'kg': 'kg',
    'kgs': 'kg',
    'kilogram': 'kg',
    'kilograms': 'kg',
    'ton': 'tons',
    'tons': 'tons',
    'tonne': 'tons',
    'tonnes': 'tons',
    'mt': 'tons',
    'no': 'nos',
    'nos': 'nos',
    'pc': 'nos',
    'pcs': 'nos',
    'piece': 'nos',
    'pieces': 'nos',
    'load': 'loads',
    'loads': 'loads',
    'trip': 'loads',
    'trips': 'loads',
    'cft': 'cft',
    'sqft': 'sqft',
    'sft': 'sqft',
    'lt': 'litres',
    'ltr': 'litres',
    'ltrs': 'litres',
    'litre': 'litres',
    'litres': 'litres',
    'liter': 'litres',
    'liters': 'litres',
  };

  static const _months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];

  /// Rows that are never items, even when their numbers happen to multiply.
  static final _notItem = RegExp(
    r'\b(sub\s*total|total|grand|cgst|sgst|igst|gst|gstin|tax|round|discount|balance|paid|advance|due|pan|'
    r'phone|mobile|ph|bank|ifsc|a/c|account|invoice|bill|date|dated|vehicle|e-way|eway|hsn|rupees|words|'
    r'thank|thanks|signature|signatory|terms|page)\b',
    caseSensitive: false,
  );
  static final _itemWord = RegExp(r'\b(item|description|particulars?|materials?|products?|goods|name)\b', caseSensitive: false);
  static final _quantityWord = RegExp(r'\b(qty|quantity)\b', caseSensitive: false);
  static final _endOfItems = RegExp(r'\b(sub\s*total|total|grand|amount in words)\b', caseSensitive: false);
  static final _buyer = RegExp(r'\b(bill(ed)? to|ship(ped)? to|buyer|customer|consignee)\b', caseSensitive: false);

  static ParsedBill parse(String text, {DateTime? now}) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    return ParsedBill(
      supplier: _supplier(lines),
      billNumber: _billNumber(lines),
      date: _date(lines, now ?? DateTime.now()),
      total: _total(lines),
      lines: _items(lines),
    );
  }

  /// Rebuilds rows from text positions. OCR and many PDFs give a table column
  /// by column, so boxes at the same height are put back together, left to
  /// right, with a wide gap between columns. [mergeFragments] joins touching
  /// boxes, as PDFs can split one word in two ("HARDW", "ARES").
  static String rowsFromBoxes(List<BillTextBox> boxes, {bool mergeFragments = false}) {
    final sorted = [...boxes]..sort((a, b) => a.center.compareTo(b.center));
    final rows = <List<BillTextBox>>[];
    for (final box in sorted) {
      final row = rows.isEmpty ? null : rows.last;
      if (row != null && (box.center - row.first.center).abs() < box.height * 0.6) {
        row.add(box);
      } else {
        rows.add([box]);
      }
    }
    return rows.map((row) {
      row.sort((a, b) => a.left.compareTo(b.left));
      final text = StringBuffer(row.first.text);
      for (var i = 1; i < row.length; i++) {
        final gap = row[i].left - row[i - 1].right;
        final height = row[i].height;
        if (gap >= height) {
          text.write('  ');
        } else if (!mergeFragments || gap >= height * 0.1) {
          text.write(' ');
        }
        text.write(row[i].text);
      }
      return text.toString();
    }).join('\n');
  }

  // Items

  static List<ParsedBillLine> _items(List<String> lines) {
    final header = lines.indexWhere((line) => _quantityWord.hasMatch(line) && _itemWord.hasMatch(line));
    final hasHeader = header != -1;
    final items = <ParsedBillLine>[];

    for (final line in lines.skip(header + 1)) {
      if (hasHeader && items.isNotEmpty && _endOfItems.hasMatch(line)) break;
      if (_notItem.hasMatch(line)) continue;
      final item = _item(_tokens(line), inTable: hasHeader);
      if (item != null) items.add(item);
    }
    return items;
  }

  static ParsedBillLine? _item(List<_Token> tokens, {required bool inTable}) {
    // Numbers before the first word are serial numbers, not columns.
    final firstWord = tokens.indexWhere((t) => t.text.contains(RegExp(r'[a-zA-Z]')));
    if (firstWord == -1) return null;
    final numbers = [
      for (var i = firstWord + 1; i < tokens.length; i++)
        if (tokens[i].isNumber && tokens[i].number! > 0) i,
    ];

    // The confident case: three numbers on the row that multiply out. The
    // rightmost quantity wins, as earlier numbers can be part of the name
    // ("TMT 12 mm").
    for (var a = numbers.length - 3; a >= 0; a--) {
      for (var b = a + 1; b < numbers.length; b++) {
        for (var c = b + 1; c < numbers.length; c++) {
          final first = tokens[numbers[a]].number!;
          final second = tokens[numbers[b]].number!;
          final amount = tokens[numbers[c]].number!;
          if (!_multiplies(first, second, amount)) continue;
          // "380 per bag, 200": a unit after the second number means the
          // rate came first.
          final rateFirst = _unitAfter(tokens, numbers[b]) && !_unitAfter(tokens, numbers[a]);
          return _line(
            tokens,
            nameEnd: numbers[a],
            unitEnd: numbers[c],
            quantity: rateFirst ? second : first,
            rate: rateFirst ? first : second,
          );
        }
      }
    }

    // A quantity with its unit, then the rate if the row has one.
    for (var i = numbers.length - 1; i >= 0; i--) {
      if (!_unitAfter(tokens, numbers[i])) continue;
      final rate = i + 1 < numbers.length ? tokens[numbers[i + 1]].number! : 0.0;
      if (rate == 0 && !inTable) return null;
      return _line(
        tokens,
        nameEnd: numbers[i],
        unitEnd: tokens.length,
        quantity: tokens[numbers[i]].number!,
        rate: rate,
        needsCheck: true,
      );
    }

    // Inside a table the columns can be assumed: quantity, rate, amount.
    if (inTable && numbers.length >= 2) {
      final quantityAt = numbers.length >= 3 ? numbers.length - 3 : 0;
      return _line(
        tokens,
        nameEnd: numbers[quantityAt],
        unitEnd: tokens.length,
        quantity: tokens[numbers[quantityAt]].number!,
        rate: tokens[numbers[quantityAt + 1]].number!,
        needsCheck: true,
      );
    }
    return null;
  }

  static ParsedBillLine? _line(
    List<_Token> tokens, {
    required int nameEnd,
    required int unitEnd,
    required double quantity,
    required double rate,
    bool needsCheck = false,
  }) {
    final nameTokens = tokens.sublist(0, nameEnd).toList();

    // A serial number in front, an HSN code behind.
    if (nameTokens.length > 1 && _isSerial(nameTokens.first.text)) nameTokens.removeAt(0);
    if (nameTokens.isNotEmpty && RegExp(r'^\d{4,8}$').hasMatch(nameTokens.last.text)) nameTokens.removeLast();

    var unit = tokens.sublist(nameEnd, unitEnd).map((t) => t.unit).firstWhere((u) => u != null, orElse: () => null);
    if (unit == null && nameTokens.length > 1 && nameTokens.last.unit != null) {
      unit = nameTokens.removeLast().unit;
    }

    final name = nameTokens.map((t) => t.text).join(' ').trim();
    if (RegExp(r'[a-zA-Z]{2}').allMatches(name).isEmpty) return null;

    return ParsedBillLine(
      name: name,
      quantity: quantity,
      unit: unit ?? 'nos',
      rate: rate,
      needsCheck: needsCheck || unit == null,
    );
  }

  /// Equal within rounding on the bill.
  static bool _multiplies(double quantity, double rate, double amount) {
    final difference = (quantity * rate - amount).abs();
    return difference <= 1 || difference <= amount * 0.005;
  }

  static bool _unitAfter(List<_Token> tokens, int index) =>
      index + 1 < tokens.length && tokens[index + 1].unit != null;

  static bool _isSerial(String text) => RegExp(r'^\d{1,3}[.)]?$').hasMatch(text);

  static List<_Token> _tokens(String line) {
    final cleaned = line
        .replaceAll(RegExp(r'sq\.?\s*f(ee)?t\.?', caseSensitive: false), 'sqft')
        .replaceAll(RegExp(r'cu\.?\s*f(ee)?t\.?', caseSensitive: false), 'cft')
        .replaceAll(RegExp(r'\b(rs\.?|inr)(?=[\s\d])', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'[|@=×₹]|/-'), ' ')
        .replaceAll(RegExp(r'(?<=\s)[xX*](?=\s)'), ' ');

    final tokens = <_Token>[];
    for (final word in cleaned.split(RegExp(r'\s+'))) {
      if (word.isEmpty || RegExp(r'^[\d.]+%$').hasMatch(word)) continue;

      // "200Bags" is a number and a unit; "12mm" stays part of the name.
      final joined = RegExp(r'^(\d[\d,]*(?:\.\d+)?)([a-zA-Z./]+)$').firstMatch(word);
      final joinedUnit = joined == null ? null : _unit(joined.group(2)!);
      if (joinedUnit != null) {
        tokens
          ..add(_Token(joined!.group(1)!, number: MoneyText.parse(joined.group(1))))
          ..add(_Token(joined.group(2)!, unit: joinedUnit));
      } else if (RegExp(r'^\d[\d,]*(\.\d+)?$').hasMatch(word)) {
        tokens.add(_Token(word, number: MoneyText.parse(word)));
      } else {
        tokens.add(_Token(word, unit: _unit(word)));
      }
    }
    return tokens;
  }

  static String? _unit(String word) => _unitAliases[word.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')];

  // Bill details

  /// Layout text pads columns with spaces, so a cell ends at a wide gap.
  static String _cell(String text) => text.trim().split(RegExp(r'\s{2,}|\t')).first.trim();

  static String _supplier(List<String> lines) {
    final labelled = RegExp(r'\b(?:supplier|vendor|seller|sold by|from)\s*[:\-]\s*(.+)', caseSensitive: false);
    for (final line in lines) {
      final match = labelled.firstMatch(line);
      if (match != null) return _cell(match.group(1)!);
    }

    // Otherwise the letterhead: the first plain line above the buyer and
    // the item table.
    for (final line in lines) {
      if (_buyer.hasMatch(line) || _quantityWord.hasMatch(line)) break;
      if (!_notItem.hasMatch(line) && _item(_tokens(line), inTable: false) != null) break;
      final cell = _cell(line).replaceFirst(RegExp(r'^m/s\.?\s*', caseSensitive: false), '');
      if (_notItem.hasMatch(cell) || cell.contains(RegExp(r'[\d@]'))) continue;
      if (RegExp(r'[a-zA-Z]{3}').hasMatch(cell)) return cell;
    }
    return '';
  }

  static String _billNumber(List<String> lines) {
    final pattern = RegExp(
      r'\b(?:invoice|inv|bill|e)\.?\s*(?:no\b\.?|number\b|num\b|#)\s*[:#\-]?\s*([a-zA-Z0-9][a-zA-Z0-9/\-]*)',
      caseSensitive: false,
    );
    for (final line in lines) {
      final match = pattern.firstMatch(line);
      if (match != null) return match.group(1)!;
    }
    return '';
  }

  static DateTime? _date(List<String> lines, DateTime now) {
    final labelled = lines.where((line) => RegExp(r'\bdated?\b', caseSensitive: false).hasMatch(line));
    final ordered = [
      ...labelled.where((line) => !RegExp(r'\bdue\b', caseSensitive: false).hasMatch(line)),
      ...lines,
    ];
    for (final line in ordered) {
      final date = _dateIn(line, now);
      if (date != null) return date;
    }
    return null;
  }

  /// Bills are day first. Dates outside 2020 to next year are misreads, and
  /// the date picker could not open on them either.
  static DateTime? _dateIn(String line, DateTime now) {
    final numeric = RegExp(r'\b(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{4}|\d{2})\b').firstMatch(line);
    final named = RegExp(r'\b(\d{1,2})[\s\-/]*([a-zA-Z]{3})[a-zA-Z]*[\s\-/,]*(\d{4}|\d{2})\b').firstMatch(line);

    int? day, month, year;
    if (numeric != null) {
      day = int.parse(numeric.group(1)!);
      month = int.parse(numeric.group(2)!);
      year = int.parse(numeric.group(3)!);
    } else if (named != null) {
      final index = _months.indexOf(named.group(2)!.toLowerCase());
      if (index == -1) return null;
      day = int.parse(named.group(1)!);
      month = index + 1;
      year = int.parse(named.group(3)!);
    } else {
      return null;
    }
    if (year < 100) year += 2000;

    final date = DateTime(year, month, day);
    final valid = date.month == month && date.day == day;
    final inRange = !date.isBefore(DateTime(2020)) && !date.isAfter(now.add(const Duration(days: 365)));
    return valid && inRange ? date : null;
  }

  static double? _total(List<String> lines) {
    final strong = RegExp(r'\b(grand total|net amount|net payable|total amount|invoice total|bill amount|amount payable)\b', caseSensitive: false);
    final plain = RegExp(r'\btotal\b', caseSensitive: false);
    final sub = RegExp(r'\bsub\s*-?\s*total\b', caseSensitive: false);

    double? lastNumberIn(bool Function(String) matches) {
      for (final line in lines.reversed) {
        if (!matches(line)) continue;
        final numbers = _tokens(line).where((t) => t.isNumber && t.number! > 0);
        if (numbers.isNotEmpty) return numbers.last.number;
      }
      return null;
    }

    return lastNumberIn(strong.hasMatch) ?? lastNumberIn((line) => plain.hasMatch(line) && !sub.hasMatch(line));
  }
}
