import 'package:flutter/foundation.dart';

import '../../models/app_settings.dart';
import '../repositories/settings_repository.dart';

/// SettingsController holds the app-wide settings Admins change, such as
/// where uploads are stored.
///
/// The app's [instance] loads from and saves to the server. The default
/// constructor keeps the settings in memory, for tests and previews.
class SettingsController extends ChangeNotifier {
  SettingsController() : _repository = null;

  SettingsController._server() : _repository = SettingsRepository();

  static final SettingsController instance = SettingsController._server();

  final SettingsRepository? _repository;
  FileStorageStatus _fileStorage = const FileStorageStatus();

  FileStorageStatus get fileStorage => _fileStorage;

  Future<void> load() async {
    final repository = _repository;
    if (repository == null) return;
    _fileStorage = await repository.fetchFileStorage();
    notifyListeners();
  }

  /// New uploads go to [storage]; files already saved stay where they are.
  Future<void> setFileStorage(FileStorage storage) async {
    final repository = _repository;
    _fileStorage = repository != null
        ? await repository.setFileStorage(storage)
        : FileStorageStatus(storage: storage, database: _fileStorage.database, folder: _fileStorage.folder);
    notifyListeners();
  }

  /// Moves files kept elsewhere into the chosen storage. Returns how many
  /// moved and how many could not be read.
  Future<(int, int)> moveFiles() async {
    final repository = _repository;
    if (repository == null) {
      final status = _fileStorage;
      final moved = status.elsewhere.files;
      final all = StorageUse(
        files: status.database.files + status.folder.files,
        bytes: status.database.bytes + status.folder.bytes,
      );
      _fileStorage = FileStorageStatus(
        storage: status.storage,
        database: status.storage == FileStorage.database ? all : const StorageUse(),
        folder: status.storage == FileStorage.folder ? all : const StorageUse(),
      );
      notifyListeners();
      return (moved, 0);
    }
    final (status, moved, failed) = await repository.moveFiles();
    _fileStorage = status;
    notifyListeners();
    return (moved, failed);
  }

  /// Sample numbers for tests and previews.
  @visibleForTesting
  void preview(FileStorageStatus status) {
    _fileStorage = status;
    notifyListeners();
  }

  /// Forgets everything on sign-out.
  void clear() {
    _fileStorage = const FileStorageStatus();
    notifyListeners();
  }
}
