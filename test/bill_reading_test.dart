import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:real_estate/core/api/api_client.dart';
import 'package:real_estate/core/repositories/construction_repository.dart';
import 'package:real_estate/core/repositories/file_repository.dart';
import 'package:real_estate/models/site.dart';

void main() {
  test('A bill is uploaded once, read by the server, and comes back to review', () async {
    final paths = <String>[];
    final api = ApiClient(
      baseUrl: 'http://x/api/v1',
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/files')) {
          return http.Response(jsonEncode({'id': 'f1', 'name': 'scan.pdf', 'size': 4, 'sha256': 'abc'}), 201);
        }
        expect(request.url.path, endsWith('/bills/read'));
        expect(jsonDecode(request.body), {'fileId': 'f1'});
        return http.Response(
          jsonEncode({
            'supplier': 'Anbalaya Cotton Mills',
            'billNumber': '353',
            'date': '2026-09-03',
            'totalPaise': null,
            'notes': 'Order form; no rates.',
            'lines': [
              {
                'name': 'Karna Set - Full Sleeve - Size 36',
                'quantity': 20,
                'unit': 'nos',
                'ratePaise': 0,
                'needsCheck': true,
              },
              {'name': 'Cement OPC 53', 'quantity': 200, 'unit': 'bags', 'ratePaise': 38050, 'needsCheck': false},
            ],
          }),
          200,
        );
      }),
    );
    final repository = ConstructionRepository(
      api: api,
      files: FileRepository(api: api),
    );

    final (file, bill, notes) = await repository.readBill(
      SiteFile(name: 'scan.pdf', bytes: Uint8List.fromList([1, 2, 3, 4])),
    );
    expect(paths.length, 2);
    // Saving the bill later reuses the upload.
    expect(file.remoteId, 'f1');
    expect(file.bytes.length, 4);
    expect(bill.supplier, 'Anbalaya Cotton Mills');
    expect(bill.billNumber, '353');
    expect(bill.date, DateTime(2026, 9, 3));
    expect(bill.total, isNull);
    expect(notes, 'Order form; no rates.');
    expect(bill.lines.first.needsCheck, isTrue);
    expect(bill.lines.first.rate, 0);
    expect(bill.lines.last.rate, 380.5);
    expect(bill.lines.last.unit, 'bags');
  });
}
