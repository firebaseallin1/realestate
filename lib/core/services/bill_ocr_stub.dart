import 'dart:typed_data';

/// Web has no on-device text recognition.
bool get billOcrAvailable => false;

Future<String> recognizeBillText(Uint8List bytes, String extension) {
  throw UnsupportedError('Photos of bills can only be read in the mobile app.');
}
