import '../../core/api/json.dart';
import '../../models/construction.dart';
import '../../models/site.dart';
import '../utils/material_bill_parser.dart';
import '../api/api_client.dart';
import 'file_repository.dart';

/// Houses under construction on the server. Each change answers with the whole
/// project, so the app always shows what was actually saved.
class ConstructionRepository {
  ConstructionRepository({ApiClient? api, FileRepository? files})
    : _api = api ?? ApiClient.instance,
      _files = files ?? FileRepository.instance;

  final ApiClient _api;
  final FileRepository _files;

  ConstructionProject _project(Map<String, dynamic>? json) => ConstructionProject.fromJson(json!);

  Future<List<ConstructionProject>> fetchProjects() async {
    final page = await _api.get('/projects');
    return [
      for (final json in page!['items'] as List<dynamic>) ConstructionProject.fromJson(json as Map<String, dynamic>),
    ];
  }

  Future<ConstructionProject> assignIncharge(String projectId, String? inchargeId) async =>
      _project(await _api.patch('/projects/$projectId/incharge', body: {'inchargeId': inchargeId}));

  Future<ConstructionProject> updateStage(
    String projectId,
    String stageId,
    StageStatus status,
    int progress,
    String note,
  ) async => _project(
    await _api.patch(
      '/projects/$projectId/stages/$stageId',
      body: {'status': status.name, 'progress': progress, 'note': note},
    ),
  );

  Future<ConstructionProject> addDailyWork(String projectId, DailyWork work) async =>
      _project(await _api.post('/projects/$projectId/daily-work', body: work.toJson()));

  Future<ConstructionProject> addWorker(String projectId, Worker worker) async =>
      _project(await _api.post('/projects/$projectId/workers', body: worker.toJson()));

  Future<ConstructionProject> addMaterial(String projectId, MaterialEntry material) async =>
      _project(await _api.post('/projects/$projectId/materials', body: material.toJson()));

  Future<ConstructionProject> updateMaterial(String projectId, MaterialEntry material) async =>
      _project(await _api.patch('/projects/$projectId/materials/${material.id}', body: material.toJson()));

  /// Uploads [file] and has the server read it with AI, printed or
  /// handwritten. Returns the uploaded file (saving the bill reuses it), what
  /// was read, and the reader's notes for the reviewer.
  Future<(SiteFile, ParsedBill, String)> readBill(SiteFile file) async {
    final uploaded = await _files.ensureUploaded(file);
    final json = (await _api.post('/bills/read', body: {'fileId': uploaded.remoteId}))!;
    return (uploaded, ParsedBill.fromServer(json), json['notes'] as String? ?? '');
  }

  /// Uploads the bill's file, then saves the bill with its reviewed items.
  Future<ConstructionProject> addMaterialBill(
    String projectId,
    MaterialBill bill,
    List<MaterialEntry> items, {
    bool allowDuplicate = false,
  }) async {
    final file = await _files.ensureUploaded(bill.file);
    return _project(
      await _api.post(
        '/projects/$projectId/material-bills',
        body: {
          'fileId': file.remoteId,
          'supplier': bill.supplier,
          'billNumber': bill.billNumber,
          'date': dayToJson(bill.date),
          if (allowDuplicate) 'allowDuplicate': true,
          'items': [
            for (final item in items)
              {'name': item.name, 'quantity': item.quantity, 'unit': item.unit, 'ratePaise': toPaise(item.rate)},
          ],
        },
      ),
    );
  }

  Future<ConstructionProject> addPayment(String projectId, ExpensePayment payment) async =>
      _project(await _api.post('/projects/$projectId/expense-payments', body: payment.toJson()));
}
