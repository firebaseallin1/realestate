import 'package:flutter/material.dart';

/// Where new uploads (bills, site maps, brochures) are kept.
enum FileStorage {
  database(
    'Database',
    'Kept inside MongoDB as binary chunks. Nothing to set up on the server, and database backups include the files.',
    Icons.storage_rounded,
  ),
  folder(
    'Server folder',
    'Kept in the uploads folder on the server. The server needs a disk that survives restarts and deploys, '
        'and the folder must be backed up separately.',
    Icons.folder_outlined,
  );

  const FileStorage(this.label, this.description, this.icon);

  final String label;
  final String description;
  final IconData icon;
}

/// How many files, and how much space, one storage holds.
class StorageUse {
  final int files;
  final int bytes;

  const StorageUse({this.files = 0, this.bytes = 0});

  factory StorageUse.fromJson(Map<String, dynamic> json) =>
      StorageUse(files: json['files'] as int, bytes: json['bytes'] as int);

  /// e.g. "12 files · 4.3 MB".
  String get label {
    final mb = bytes / (1024 * 1024);
    final size = mb >= 1 ? '${mb.toStringAsFixed(1)} MB' : '${(bytes / 1024).ceil()} KB';
    return '$files ${files == 1 ? 'file' : 'files'} · $size';
  }
}

/// The file storage setting and what each storage holds now.
class FileStorageStatus {
  final FileStorage storage;
  final StorageUse database;
  final StorageUse folder;

  const FileStorageStatus({
    this.storage = FileStorage.database,
    this.database = const StorageUse(),
    this.folder = const StorageUse(),
  });

  factory FileStorageStatus.fromJson(Map<String, dynamic> json) => FileStorageStatus(
    storage: FileStorage.values.byName(json['storage'] as String),
    database: StorageUse.fromJson(json['database'] as Map<String, dynamic>),
    folder: StorageUse.fromJson(json['folder'] as Map<String, dynamic>),
  );

  StorageUse useOf(FileStorage storage) => storage == FileStorage.database ? database : folder;

  /// Files kept somewhere other than the current setting.
  StorageUse get elsewhere => useOf(storage == FileStorage.database ? FileStorage.folder : FileStorage.database);
}
