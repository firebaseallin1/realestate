import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/repositories/file_repository.dart';
import '../core/theme/app_colors.dart';
import '../models/site.dart';

/// Builds with a file's bytes, fetching them from the server if the file is
/// not already on this device.
class RemoteFileBytes extends StatefulWidget {
  final SiteFile file;
  final Widget Function(BuildContext context, Uint8List bytes) builder;

  /// Shown if the file cannot be fetched.
  final Widget? failed;

  const RemoteFileBytes({super.key, required this.file, required this.builder, this.failed});

  @override
  State<RemoteFileBytes> createState() => _RemoteFileBytesState();
}

class _RemoteFileBytesState extends State<RemoteFileBytes> {
  late Future<Uint8List> _bytes = FileRepository.instance.bytesOf(widget.file);

  @override
  void didUpdateWidget(RemoteFileBytes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.remoteId != widget.file.remoteId || oldWidget.file.bytes != widget.file.bytes) {
      _bytes = FileRepository.instance.bytesOf(widget.file);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Already here: no loading frame, which also keeps a picked file instant.
    if (widget.file.bytes.isNotEmpty) return widget.builder(context, widget.file.bytes);

    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.hasData) return widget.builder(context, snapshot.data!);
        if (snapshot.hasError) {
          return widget.failed ?? const Center(child: Text('This file could not be loaded.'));
        }
        return Center(child: CircularProgressIndicator(color: AppColors.primary));
      },
    );
  }
}
