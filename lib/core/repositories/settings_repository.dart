import '../../models/app_settings.dart';
import '../api/api_client.dart';

/// App-wide settings on the server (Admins only).
class SettingsRepository {
  SettingsRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  final ApiClient _api;

  Future<FileStorageStatus> fetchFileStorage() async =>
      FileStorageStatus.fromJson((await _api.get('/settings/file-storage'))!);

  Future<FileStorageStatus> setFileStorage(FileStorage storage) async =>
      FileStorageStatus.fromJson((await _api.put('/settings/file-storage', body: {'storage': storage.name}))!);

  /// Moves files kept elsewhere into the chosen storage: the new status, and
  /// how many moved and failed.
  Future<(FileStorageStatus, int, int)> moveFiles() async {
    final json = (await _api.post('/settings/file-storage/move'))!;
    return (FileStorageStatus.fromJson(json), json['moved'] as int, json['failed'] as int);
  }
}
