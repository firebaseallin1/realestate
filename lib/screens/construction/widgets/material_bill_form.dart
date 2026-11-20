import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/date_text.dart';
import '../../../core/utils/material_bill_parser.dart';
import '../../../core/utils/money_text.dart';
import '../../../core/utils/responsive.dart';
import '../../../models/construction.dart';
import '../../../models/site.dart';
import '../../../widgets/app_form_sheet.dart';
import '../../../widgets/app_form_shell.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/remote_file_bytes.dart';
import 'construction_forms.dart';

/// The bill itself: a PDF or a zoomable photo.
class BillFilePreview extends StatelessWidget {
  final SiteFile file;

  const BillFilePreview({super.key, required this.file});

  /// Replaces the PDF viewer, which needs its platform plugin, for tests.
  @visibleForTesting
  static Widget Function(SiteFile file)? builderOverride;

  @override
  Widget build(BuildContext context) {
    if (builderOverride != null) return builderOverride!(file);
    return RemoteFileBytes(
      file: file,
      builder: (_, bytes) {
        if (file.isPdf) return SfPdfViewer.memory(bytes);
        return InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Image.memory(
              bytes,
              errorBuilder: (_, _, _) => const Text('This photo could not be shown.'),
            ),
          ),
        );
      },
    );
  }
}

/// Opens the bill alone, full screen.
Future<void> showBillFile(BuildContext context, SiteFile file) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Theme(
        data: AppTheme.lightTheme,
        child: Scaffold(
          appBar: AppBar(title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          body: BillFilePreview(file: file),
        ),
      ),
    ),
  );
}

/// Opens [details] beside the bill, to compare the two.
Future<void> showBillCompare(BuildContext context, {required SiteFile file, required Widget details}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => BillCompareScreen(file: file, details: details)),
  );
}

/// BillCompareScreen keeps the bill in view next to [details]: side by side
/// on web, and stacked on mobile, where the bill can be hidden to give the
/// list more room.
class BillCompareScreen extends StatefulWidget {
  final SiteFile file;
  final Widget details;

  const BillCompareScreen({super.key, required this.file, required this.details});

  @override
  State<BillCompareScreen> createState() => _BillCompareScreenState();
}

class _BillCompareScreenState extends State<BillCompareScreen> {
  bool _billShown = true;

  Widget _buildBillBar({required bool canHide}) {
    return Container(
      color: AppColors.mint.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(12, 2, 4, 2),
      child: Row(
        children: [
          Icon(
            widget.file.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_outlined,
            size: 20,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            key: const ValueKey('bill-open-file'),
            tooltip: 'Full screen',
            onPressed: () => showBillFile(context, widget.file),
            icon: Icon(Icons.fullscreen_rounded, color: AppColors.primary),
          ),
          if (canHide)
            IconButton(
              key: const ValueKey('bill-toggle'),
              tooltip: _billShown ? 'Hide bill' : 'Show bill',
              onPressed: () => setState(() => _billShown = !_billShown),
              icon: Icon(
                _billShown ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      child: widget.details,
    );
  }

  Widget _buildWide() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildBillBar(canHide: false),
              Expanded(child: ClipRect(child: BillFilePreview(file: widget.file))),
            ],
          ),
        ),
        VerticalDivider(width: 1, color: AppColors.lightBorder),
        SizedBox(width: 500, child: _buildDetails()),
      ],
    );
  }

  Widget _buildStacked() {
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildBillBar(canHide: true),
          if (_billShown)
            SizedBox(
              height: constraints.maxHeight * 0.42,
              child: ClipRect(child: BillFilePreview(file: widget.file)),
            ),
          Divider(height: 1, color: AppColors.lightBorder),
          Expanded(child: _buildDetails()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppColors.pureWhite,
        body: SafeArea(child: Responsive.isWeb(context) ? _buildWide() : _buildStacked()),
      ),
    );
  }
}

/// One item of a bill, with its edit and delete buttons when given.
class _BillItemRow extends StatelessWidget {
  final MaterialEntry item;
  final bool needsCheck;
  final Key? editKey;
  final VoidCallback onEdit;
  final Key? deleteKey;
  final VoidCallback? onDelete;

  const _BillItemRow({
    super.key,
    required this.item,
    this.needsCheck = false,
    this.editKey,
    required this.onEdit,
    this.deleteKey,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: needsCheck ? AppColors.accentGold : AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimaryLight, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${MoneyText.plain(item.quantity)} ${item.unit} × ${MoneyText.exact(item.rate)} = ${MoneyText.exact(item.amount)}',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondaryLight),
                ),
                if (needsCheck) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.rate > 0 ? 'Please check this item' : 'Add the rate for this item',
                    style: AppTypography.caption.copyWith(color: AppColors.accentGold, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: editKey,
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, size: 20, color: AppColors.primary),
          ),
          if (onDelete != null)
            IconButton(
              key: deleteKey,
              tooltip: 'Remove',
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
            ),
        ],
      ),
    );
  }
}

/// MaterialBillForm reviews what was read from a bill before anything is
/// saved: the bill's details and the list of items, each one editable, with
/// items to remove or add.
class MaterialBillForm extends StatefulWidget {
  final SiteFile file;
  final ParsedBill parsed;

  /// Why the list is empty, when the bill could not be read.
  final String? notice;
  final String Function(String prefix) newId;
  final void Function(MaterialBill bill, List<MaterialEntry> items) onSubmit;

  const MaterialBillForm({
    super.key,
    required this.file,
    required this.parsed,
    this.notice,
    required this.newId,
    required this.onSubmit,
  });

  @override
  State<MaterialBillForm> createState() => _MaterialBillFormState();
}

class _MaterialBillFormState extends State<MaterialBillForm> {
  final _formKey = GlobalKey<FormState>();
  late final _supplierController = TextEditingController(text: widget.parsed.supplier);
  late final _billNumberController = TextEditingController(text: widget.parsed.billNumber);
  late DateTime _date = widget.parsed.date ?? DateTime.now();
  late final List<MaterialEntry> _items;

  /// Item ids still to be looked at. Editing an item clears it.
  final Set<String> _toCheck = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = [
      for (final line in widget.parsed.lines)
        MaterialEntry(
          id: widget.newId('m'),
          date: _date,
          name: line.name,
          quantity: line.quantity,
          unit: line.unit,
          rate: line.rate,
        ),
    ];
    for (var i = 0; i < _items.length; i++) {
      if (widget.parsed.lines[i].needsCheck) _toCheck.add(_items[i].id);
    }
  }

  @override
  void dispose() {
    _supplierController.dispose();
    _billNumberController.dispose();
    super.dispose();
  }

  double get _itemsTotal => _items.fold(0, (sum, item) => sum + item.amount);

  void _editItem(MaterialEntry item) {
    showAppForm(
      context,
      MaterialForm(
        newId: item.id,
        material: item,
        askSupplierAndDate: false,
        onSubmit: (edited) {
          Navigator.of(context).pop();
          setState(() {
            _items[_items.indexWhere((i) => i.id == item.id)] = edited;
            _toCheck.remove(item.id);
            _error = null;
          });
        },
      ),
    );
  }

  void _addItem() {
    showAppForm(
      context,
      MaterialForm(
        newId: widget.newId('m'),
        askSupplierAndDate: false,
        onSubmit: (item) {
          Navigator.of(context).pop();
          setState(() {
            _items.add(item);
            _error = null;
          });
        },
      ),
    );
  }

  void _removeItem(MaterialEntry item) {
    setState(() {
      _items.remove(item);
      _toCheck.remove(item.id);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one item from this bill.');
      return;
    }
    if (_items.any((item) => item.amount <= 0)) {
      setState(() => _error = 'Add the quantity and rate for the highlighted items.');
      return;
    }

    final supplier = _supplierController.text.trim();
    final bill = MaterialBill(
      id: widget.newId('mb'),
      file: widget.file,
      supplier: supplier,
      billNumber: _billNumberController.text.trim(),
      date: _date,
    );
    widget.onSubmit(bill, [
      for (final item in _items) item.copyWith(date: _date, supplier: supplier, billId: bill.id),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final count = _items.length;
    final total = widget.parsed.total;

    return AppFormShell(
      formKey: _formKey,
      icon: Icons.document_scanner_rounded,
      title: 'Review Bill',
      subtitle: 'Check the items read from this bill, then save them',
      submitLabel: count == 1 ? 'Save 1 Item' : 'Save $count Items',
      submitKey: const ValueKey('bill-submit'),
      onSubmit: _submit,
      children: [
        if (widget.notice != null) _Note(key: const ValueKey('bill-notice'), text: widget.notice!),
        AppTextField(
          key: const ValueKey('bill-supplier'),
          controller: _supplierController,
          label: 'Supplier (optional)',
          prefixIcon: const Icon(Icons.storefront_outlined),
        ),
        AppTextField(
          key: const ValueKey('bill-number'),
          controller: _billNumberController,
          label: 'Bill No. (optional)',
          prefixIcon: const Icon(Icons.tag_rounded),
        ),
        AppDateField(label: 'Received on', value: _date, onChanged: (d) => setState(() => _date = d)),
        Text(
          count == 1 ? '1 item' : '$count items',
          style: AppTypography.labelMedium.copyWith(color: AppColors.textSecondaryLight, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < count; i++)
          _BillItemRow(
            key: ValueKey('bill-item-$i'),
            item: _items[i],
            needsCheck: _toCheck.contains(_items[i].id),
            editKey: ValueKey('bill-item-edit-$i'),
            onEdit: () => _editItem(_items[i]),
            deleteKey: ValueKey('bill-item-delete-$i'),
            onDelete: () => _removeItem(_items[i]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const ValueKey('bill-add-item'),
            onPressed: _addItem,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Item'),
          ),
        ),
        const SizedBox(height: 6),
        _TotalRow(label: 'Items total', amount: _itemsTotal),
        if (total != null) ...[
          _TotalRow(label: 'Total on the bill', amount: total),
          if ((total - _itemsTotal).abs() >= 1)
            _Note(
              key: const ValueKey('bill-total-difference'),
              text: 'Differs from the items by ${MoneyText.exact((total - _itemsTotal).abs())}. '
                  'This can be GST or transport; add it as an item if it should count.',
            ),
        ],
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_error!, style: AppTypography.caption.copyWith(color: AppColors.error)),
          ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double amount;

  const _TotalRow({required this.label, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondaryLight)),
          ),
          Text(
            MoneyText.exact(amount),
            style: AppTypography.titleSmall.copyWith(color: AppColors.brandDeep, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  final String text;

  const _Note({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.accentGold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTypography.bodySmall.copyWith(color: AppColors.textPrimaryLight)),
          ),
        ],
      ),
    );
  }
}

/// MaterialBillView shows a saved bill's details and its items with their
/// edit buttons. It follows [listenable] so edits show right away.
class MaterialBillView extends StatelessWidget {
  final Listenable listenable;
  final ConstructionProject project;
  final MaterialBill bill;
  final ValueChanged<MaterialEntry> onEdit;

  const MaterialBillView({
    super.key,
    required this.listenable,
    required this.project,
    required this.bill,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final details = [
      if (bill.supplier.isNotEmpty) bill.supplier,
      if (bill.billNumber.isNotEmpty) 'Bill ${bill.billNumber}',
      DateText.shortDate(bill.date),
    ].join(' · ');

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final items = project.materialsOfBill(bill.id);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Material Bill', style: AppTypography.displaySmall.copyWith(color: AppColors.textPrimaryLight)),
                      Text(details, style: AppTypography.bodySmall.copyWith(color: AppColors.textMutedLight)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final item in items)
              _BillItemRow(
                key: ValueKey('saved-bill-item-${item.id}'),
                item: item,
                editKey: ValueKey('saved-bill-item-edit-${item.id}'),
                // Edits the whole material, not just this bill's share of it.
                onEdit: () => onEdit(project.materialById(item.id) ?? item),
              ),
            const SizedBox(height: 6),
            _TotalRow(label: 'Items total', amount: items.fold(0, (sum, item) => sum + item.amount)),
          ],
        );
      },
    );
  }
}
