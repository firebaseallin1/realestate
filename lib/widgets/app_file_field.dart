import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../models/site.dart';

/// AppFileField attaches one file (image or PDF): a dashed drop-style tile
/// when empty, and a preview row (thumbnail or PDF badge, name, size) with
/// replace and remove once a file is attached.
class AppFileField extends StatefulWidget {
  final String label;
  final String hint;
  final IconData icon;
  final List<String> allowedExtensions;
  final SiteFile? file;
  final ValueChanged<SiteFile?> onChanged;

  const AppFileField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.allowedExtensions,
    required this.file,
    required this.onChanged,
  });

  /// Replaces the system file picker, for tests.
  @visibleForTesting
  static Future<SiteFile?> Function(List<String> extensions)? pickOverride;

  /// A short message for a failed pick. A picker that is not loaded means
  /// the app is still running a build from before the plugin was added.
  static String describeError(Object error) {
    final text = error.toString();
    final notLoaded = error is UnimplementedError ||
        text.contains('MissingPluginException') ||
        text.contains('has not been implemented');
    return notLoaded
        ? 'File upload is not loaded yet. Stop the app and run it again '
            '(a hot reload is not enough after adding the file picker).'
        : 'Could not open that file. Please try another one.';
  }

  /// Opens the system picker limited to [extensions] and reads the file.
  static Future<SiteFile?> pick(List<String> extensions) async {
    if (pickOverride != null) return pickOverride!(extensions);
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (picked == null) return null;
    return SiteFile(name: picked.name, bytes: await picked.readAsBytes());
  }

  @override
  State<AppFileField> createState() => _AppFileFieldState();
}

class _AppFileFieldState extends State<AppFileField> {
  bool _loading = false;

  /// Shown under the field: a snackbar would sit hidden behind the
  /// dialog or bottom sheet this field usually lives in.
  String? _error;

  Future<void> _choose() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = await AppFileField.pick(widget.allowedExtensions);
      if (file != null) widget.onChanged(file);
    } catch (error, stack) {
      debugPrint('File pick failed: $error\n$stack');
      if (mounted) setState(() => _error = AppFileField.describeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.file;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.textSecondaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          file == null ? _buildEmpty() : _buildAttached(file),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: AppTypography.caption.copyWith(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final types = widget.allowedExtensions.map((e) => e.toUpperCase()).join(', ');

    return Material(
      color: AppColors.offWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _loading ? null : _choose,
        borderRadius: BorderRadius.circular(14),
        child: CustomPaint(
          painter: _DashedBorderPainter(color: AppColors.sageSoft, radius: 14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.mint.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        )
                      : Icon(widget.icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.hint,
                        style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight),
                      ),
                      Text(
                        types,
                        style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.upload_rounded, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttached(SiteFile file) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: file.isImage
                  ? Image.memory(
                      file.bytes,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _badge(Icons.broken_image_outlined, 'IMG'),
                    )
                  : _badge(Icons.picture_as_pdf_rounded, file.extension.toUpperCase()),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(color: AppColors.textPrimaryLight),
                ),
                Text(
                  file.sizeLabel,
                  style: AppTypography.caption.copyWith(color: AppColors.textMutedLight),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Replace',
            onPressed: _loading ? null : _choose,
            icon: const Icon(Icons.sync_rounded, color: AppColors.primary),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => widget.onChanged(null),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, String label) {
    return Container(
      color: AppColors.mint.withValues(alpha: 0.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: AppColors.primary),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              fontSize: 9,
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a rounded dashed outline, for the empty upload tile.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));

    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color || old.radius != radius;
}
