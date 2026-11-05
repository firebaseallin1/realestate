import 'dart:io';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../utils/material_bill_parser.dart';

/// ML Kit runs on Android and iOS only.
bool get billOcrAvailable => Platform.isAndroid || Platform.isIOS;

/// Reads a photo of a bill on the device. ML Kit takes a file path, so the
/// bytes go through a temporary file.
Future<String> recognizeBillText(Uint8List bytes, String extension) async {
  final folder = await Directory.systemTemp.createTemp('bill');
  final recognizer = TextRecognizer();
  try {
    final file = await File('${folder.path}/bill.$extension').writeAsBytes(bytes);
    final recognized = await recognizer.processImage(InputImage.fromFilePath(file.path));
    return MaterialBillParser.rowsFromBoxes([
      for (final block in recognized.blocks)
        for (final line in block.lines)
          BillTextBox(
            text: line.text,
            left: line.boundingBox.left,
            right: line.boundingBox.right,
            top: line.boundingBox.top,
            bottom: line.boundingBox.bottom,
          ),
    ]);
  } finally {
    await recognizer.close();
    await folder.delete(recursive: true);
  }
}
