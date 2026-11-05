import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../models/site.dart';
import '../utils/material_bill_parser.dart';
import 'bill_ocr_stub.dart' if (dart.library.io) 'bill_ocr_mobile.dart';

/// Why a bill could not be read, in words for the user.
class BillReadException implements Exception {
  final String message;

  const BillReadException(this.message);

  @override
  String toString() => message;
}

/// MaterialBillReader gets the items out of a bill on the device: text PDFs
/// through the PDF's own text, photos through text recognition. Nothing is
/// sent anywhere.
class MaterialBillReader {
  MaterialBillReader._();

  /// Replace the camera and the reading of a file, for tests.
  @visibleForTesting
  static Future<SiteFile?> Function()? captureOverride;
  @visibleForTesting
  static Future<String> Function(SiteFile file)? readTextOverride;

  static bool get canCapture => captureOverride != null || billOcrAvailable;

  /// The file types the device can read.
  static List<String> get extensions => ['pdf', if (canCapture) ...['jpg', 'jpeg', 'png']];

  /// Takes a photo of a bill; null when the user backs out.
  static Future<SiteFile?> capture() async {
    if (captureOverride != null) return captureOverride!();
    final photo = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 90);
    if (photo == null) return null;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return SiteFile(name: 'bill-$stamp.jpg', bytes: await photo.readAsBytes());
  }

  /// Reads [file]. Throws [BillReadException] when no text can be got out.
  static Future<ParsedBill> read(SiteFile file) async {
    final text = await _textOf(file);
    if (text.trim().isEmpty) {
      throw BillReadException(
        file.isPdf
            ? canCapture
                ? 'This PDF has no readable text, it looks like a scanned copy. '
                    'Take a photo of the bill, or add the items by hand.'
                : 'This PDF has no readable text, it looks like a scanned copy. Add the items by hand.'
            : 'No text was found in this photo. Add the items by hand, or retake it in better light.',
      );
    }
    return MaterialBillParser.parse(text);
  }

  static Future<String> _textOf(SiteFile file) async {
    if (readTextOverride != null) return readTextOverride!(file);
    try {
      if (file.isPdf) return await compute(extractPdfText, file.bytes);
      return await recognizeBillText(file.bytes, file.extension);
    } catch (error, stack) {
      debugPrint('Bill read failed: $error\n$stack');
      throw BillReadException(
        file.isPdf
            ? 'Could not read this PDF. It may be password protected or damaged. Add the items by hand.'
            : 'Could not read this photo. Add the items by hand.',
      );
    }
  }

  /// The PDF's text, page by page, with rows rebuilt from where the words
  /// sit. The PDF's own text order can't be trusted: billing software often
  /// writes a table column by column.
  @visibleForTesting
  static String extractPdfText(Uint8List bytes) {
    final document = PdfDocument(inputBytes: bytes);
    try {
      final pages = <int, List<BillTextBox>>{};
      for (final line in PdfTextExtractor(document).extractTextLines()) {
        final boxes = pages.putIfAbsent(line.pageIndex, () => []);
        for (final word in line.wordCollection) {
          if (word.text.trim().isEmpty) continue;
          boxes.add(
            BillTextBox(
              text: word.text.trim(),
              left: word.bounds.left,
              right: word.bounds.right,
              top: word.bounds.top,
              bottom: word.bounds.bottom,
            ),
          );
        }
      }
      final order = pages.keys.toList()..sort();
      return order.map((page) => MaterialBillParser.rowsFromBoxes(pages[page]!, mergeFragments: true)).join('\n');
    } finally {
      document.dispose();
    }
  }
}
