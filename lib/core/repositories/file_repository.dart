import 'dart:typed_data';

import '../../models/site.dart';
import '../api/api_client.dart';

/// Uploads and fetches attached files, keeping what it has fetched so a map
/// is downloaded only once per session.
class FileRepository {
  FileRepository({ApiClient? api}) : _api = api ?? ApiClient.instance;

  static final FileRepository instance = FileRepository();

  final ApiClient _api;
  final Map<String, Future<Uint8List>> _downloads = {};

  /// [file] as it is on the server, uploading it first if it is new.
  Future<SiteFile> ensureUploaded(SiteFile file) async {
    if (file.remoteId != null) return file;
    final json = await _api.upload('/files', file.name, file.bytes);
    return SiteFile(
      name: json!['name'] as String,
      bytes: file.bytes,
      remoteId: json['id'] as String,
      remoteSize: json['size'] as int?,
      sha256: json['sha256'] as String?,
    );
  }

  Future<Uint8List> bytesOf(SiteFile file) {
    final id = file.remoteId;
    if (file.bytes.isNotEmpty || id == null) return Future.value(file.bytes);
    return _downloads[id] ??= _api.download('/files/$id/content').catchError((Object error) {
      // Not kept, so opening the file again tries again.
      _downloads.remove(id);
      throw error;
    });
  }

  /// Forgets fetched files on sign-out.
  void clear() => _downloads.clear();
}
