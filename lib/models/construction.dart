import 'package:flutter/material.dart';

import '../core/api/json.dart';
import 'booking.dart';
import 'site.dart';

/// StageStatus is where one construction stage stands.
enum StageStatus {
  notStarted('Not Started', Color(0xFF8A968A), Icons.radio_button_unchecked_rounded),
  inProgress('In Progress', Color(0xFFC98A2E), Icons.timelapse_rounded),
  completed('Completed', Color(0xFF3F8F5A), Icons.check_circle_rounded);

  const StageStatus(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

/// ConstructionStage is one step of building the house, e.g. Foundation.
class ConstructionStage {
  final String id;
  final String name;
  StageStatus status;

  /// 0–100.
  int progress;
  String note;

  ConstructionStage({
    required this.id,
    required this.name,
    this.status = StageStatus.notStarted,
    this.progress = 0,
    this.note = '',
  });

  factory ConstructionStage.fromJson(Map<String, dynamic> json) => ConstructionStage(
    id: json['id'] as String,
    name: json['name'] as String,
    status: StageStatus.values.byName(json['status'] as String),
    progress: json['progress'] as int,
    note: json['note'] as String? ?? '',
  );

  /// The usual stages of an independent house, in order.
  static const defaultNames = [
    'Foundation',
    'Plinth Beam',
    'Walls & Brickwork',
    'Roof Slab',
    'Plastering',
    'Electrical & Plumbing',
    'Flooring & Tiling',
    'Painting & Finishing',
    'Handover',
  ];
}

enum WorkerTrade {
  mason('Mason'),
  helper('Helper'),
  carpenter('Carpenter'),
  barBender('Bar Bender'),
  electrician('Electrician'),
  plumber('Plumber'),
  tiler('Tiler'),
  painter('Painter');

  const WorkerTrade(this.label);

  final String label;
}

/// Worker on a construction project, paid a daily wage.
class Worker {
  final String id;
  final String name;
  final WorkerTrade trade;
  final double dailyWage;
  final String phone;

  const Worker({required this.id, required this.name, required this.trade, required this.dailyWage, this.phone = ''});

  factory Worker.fromJson(Map<String, dynamic> json) => Worker(
    id: json['id'] as String,
    name: json['name'] as String,
    trade: WorkerTrade.values.byName(json['trade'] as String),
    dailyWage: fromPaise(json['dailyWagePaise'] as num),
    phone: json['phone'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'trade': trade.name,
    'dailyWagePaise': toPaise(dailyWage),
    'phone': phone,
  };
}

/// DailyWork is one day's update: the stage worked on, what was done and
/// which workers were present (their attendance, which earns wages).
class DailyWork {
  final String id;
  final DateTime date;
  final String stageId;
  final String description;
  final List<String> workerIds;
  final String updatedBy;

  const DailyWork({
    required this.id,
    required this.date,
    required this.stageId,
    required this.description,
    required this.workerIds,
    required this.updatedBy,
  });

  factory DailyWork.fromJson(Map<String, dynamic> json) => DailyWork(
    id: json['id'] as String,
    date: dayFromJson(json['date'] as String),
    stageId: json['stageId'] as String,
    description: json['description'] as String,
    workerIds: List<String>.from(json['workerIds'] as List<dynamic>),
    updatedBy: json['updatedBy'] as String,
  );

  /// The server records who made the update.
  Map<String, dynamic> toJson() => {
    'date': dayToJson(date),
    'stageId': stageId,
    'description': description,
    'workerIds': workerIds,
  };
}

/// MaterialReceipt is one delivery of a material: from a scanned bill or
/// added by hand.
class MaterialReceipt {
  final String id;
  final DateTime date;
  final double quantity;
  final double rate;
  final String supplier;
  final String? billId;
  final String billNumber;

  /// When it was scanned or entered.
  final DateTime addedAt;

  const MaterialReceipt({
    required this.id,
    required this.date,
    required this.quantity,
    required this.rate,
    required this.addedAt,
    this.supplier = '',
    this.billId,
    this.billNumber = '',
  });

  factory MaterialReceipt.fromJson(Map<String, dynamic> json) => MaterialReceipt(
    id: json['id'] as String,
    date: dayFromJson(json['date'] as String),
    quantity: (json['quantity'] as num).toDouble(),
    rate: fromPaise(json['ratePaise'] as num),
    supplier: json['supplier'] as String? ?? '',
    billId: json['billId'] as String?,
    billNumber: json['billNumber'] as String? ?? '',
    addedAt: DateTime.parse(json['addedAt'] as String).toLocal(),
  );

  double get amount => (quantity * toPaise(rate)).round() / 100;
}

/// MaterialEntry is material received at site, e.g. 200 bags of cement.
/// The same material received again is added to it: [quantity] is the
/// total, [rate] the latest price, and [history] each delivery.
class MaterialEntry {
  final String id;
  final DateTime date;
  final String name;
  final double quantity;
  final String unit;
  final double rate;
  final String supplier;

  /// The latest bill this came from, when it was scanned from one.
  final String? billId;

  /// Every delivery, oldest first. Empty for one not yet saved.
  final List<MaterialReceipt> history;

  const MaterialEntry({
    required this.id,
    required this.date,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.rate,
    this.supplier = '',
    this.billId,
    this.history = const [],
  });

  factory MaterialEntry.fromJson(Map<String, dynamic> json) => MaterialEntry(
    id: json['id'] as String,
    date: dayFromJson(json['date'] as String),
    name: json['name'] as String,
    quantity: (json['quantity'] as num).toDouble(),
    unit: json['unit'] as String,
    rate: fromPaise(json['ratePaise'] as num),
    supplier: json['supplier'] as String? ?? '',
    billId: json['billId'] as String?,
    history: [
      for (final row in json['history'] as List<dynamic>? ?? const [])
        MaterialReceipt.fromJson(row as Map<String, dynamic>),
    ],
  );

  /// The server works out the amount, the same way as [amount].
  Map<String, dynamic> toJson() => {
    'date': dayToJson(date),
    'name': name,
    'quantity': quantity,
    'unit': unit,
    'ratePaise': toPaise(rate),
    'supplier': supplier,
  };

  static const units = ['bags', 'kg', 'tons', 'nos', 'loads', 'cft', 'sqft', 'litres'];

  /// Rounded to paise, like a bill. Worked out in paise to match the server.
  double get amount => (quantity * toPaise(rate)).round() / 100;

  /// The same material, however it was typed: "Cement  OPC" and "cement opc".
  String get key => '${name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase()}|${unit.trim().toLowerCase()}';

  /// Each delivery; one with no history counts as a single delivery.
  List<MaterialReceipt> get receipts => history.isNotEmpty
      ? history
      : [
          MaterialReceipt(
            id: id,
            date: date,
            quantity: quantity,
            rate: rate,
            supplier: supplier,
            billId: billId,
            addedAt: date,
          ),
        ];

  MaterialEntry copyWith({DateTime? date, String? supplier, String? billId, List<MaterialReceipt>? history}) =>
      MaterialEntry(
        id: id,
        date: date ?? this.date,
        name: name,
        quantity: quantity,
        unit: unit,
        rate: rate,
        supplier: supplier ?? this.supplier,
        billId: billId ?? this.billId,
        history: history ?? this.history,
      );
}

double _paise(double amount) => (amount * 100).round() / 100;

/// MaterialBill is a supplier's bill kept with the materials scanned from it.
class MaterialBill {
  final String id;
  final SiteFile file;
  final String supplier;
  final String billNumber;
  final DateTime date;

  /// When it was scanned; null before it is saved.
  final DateTime? scannedAt;

  const MaterialBill({
    required this.id,
    required this.file,
    required this.date,
    this.supplier = '',
    this.billNumber = '',
    this.scannedAt,
  });

  DateTime get scannedOn => scannedAt ?? date;

  factory MaterialBill.fromJson(Map<String, dynamic> json) => MaterialBill(
    id: json['id'] as String,
    file: SiteFile.fromJson(json['file'] as Map<String, dynamic>),
    date: dayFromJson(json['date'] as String),
    supplier: json['supplier'] as String? ?? '',
    billNumber: json['billNumber'] as String? ?? '',
    scannedAt: json['scannedAt'] == null ? null : DateTime.parse(json['scannedAt'] as String).toLocal(),
  );
}

/// What a construction expense pays for.
enum ExpenseKind {
  worker('Worker Payment', Icons.engineering_outlined),
  material('Material Payment', Icons.inventory_2_outlined);

  const ExpenseKind(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// ExpensePayment is money paid out: wages to a worker or a material bill.
/// [targetId] is the worker's or the material entry's id.
class ExpensePayment {
  final String id;
  final ExpenseKind kind;
  final String targetId;
  final double amount;
  final DateTime date;
  final PaymentMethod method;
  final String reference;

  const ExpensePayment({
    required this.id,
    required this.kind,
    required this.targetId,
    required this.amount,
    required this.date,
    required this.method,
    this.reference = '',
  });

  factory ExpensePayment.fromJson(Map<String, dynamic> json) => ExpensePayment(
    id: json['id'] as String,
    kind: ExpenseKind.values.byName(json['kind'] as String),
    targetId: json['targetId'] as String,
    amount: fromPaise(json['amountPaise'] as num),
    date: dayFromJson(json['date'] as String),
    method: PaymentMethod.values.byName(json['method'] as String),
    reference: json['reference'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'targetId': targetId,
    'amountPaise': toPaise(amount),
    'date': dayToJson(date),
    'method': method.name,
    'reference': reference,
  };
}

/// ConstructionProject is the house being built for one With Construction
/// booking: its stages, daily updates, workers, materials and expenses.
class ConstructionProject {
  /// The latest copy of the booking (it changes as payments come in).
  Booking booking;
  String? inchargeId;
  final List<ConstructionStage> stages;
  final List<Worker> workers = [];
  final List<DailyWork> dailyWork = [];
  final List<MaterialEntry> materials = [];
  final List<MaterialBill> bills = [];
  final List<ExpensePayment> payments = [];

  ConstructionProject({required this.booking, required this.stages, this.inchargeId});

  factory ConstructionProject.fromJson(Map<String, dynamic> json) {
    List<T> rows<T>(String key, T Function(Map<String, dynamic>) fromJson) => [
      for (final row in json[key] as List<dynamic>) fromJson(row as Map<String, dynamic>),
    ];

    return ConstructionProject(
        booking: Booking.fromJson(json['booking'] as Map<String, dynamic>),
        inchargeId: json['inchargeId'] as String?,
        stages: rows('stages', ConstructionStage.fromJson),
      )
      ..workers.addAll(rows('workers', Worker.fromJson))
      ..dailyWork.addAll(rows('dailyWork', DailyWork.fromJson))
      ..materials.addAll(rows('materials', MaterialEntry.fromJson))
      ..bills.addAll(rows('bills', MaterialBill.fromJson))
      ..payments.addAll(rows('payments', ExpensePayment.fromJson));
  }

  /// Takes on the server's latest copy, staying the same object so screens
  /// holding this project keep showing the current data.
  void updateFrom(ConstructionProject latest) {
    void replace<T>(List<T> list, List<T> rows) {
      list
        ..clear()
        ..addAll(rows);
    }

    booking = latest.booking;
    inchargeId = latest.inchargeId;
    replace(stages, latest.stages);
    replace(workers, latest.workers);
    replace(dailyWork, latest.dailyWork);
    replace(materials, latest.materials);
    replace(bills, latest.bills);
    replace(payments, latest.payments);
  }

  String get id => booking.id;

  /// The construction value agreed in the booking.
  double get budget => booking.plan(PaymentPart.construction)?.value ?? 0;

  /// Average of the stages' progress, 0–100.
  int get progress => stages.isEmpty ? 0 : (stages.fold<int>(0, (sum, s) => sum + s.progress) / stages.length).round();

  /// The first stage not yet completed, or null when all are done.
  ConstructionStage? get currentStage {
    for (final stage in stages) {
      if (stage.status != StageStatus.completed) return stage;
    }
    return null;
  }

  ConstructionStage? stageById(String id) {
    for (final stage in stages) {
      if (stage.id == id) return stage;
    }
    return null;
  }

  Worker? workerById(String id) {
    for (final worker in workers) {
      if (worker.id == id) return worker;
    }
    return null;
  }

  MaterialEntry? materialById(String id) {
    for (final material in materials) {
      if (material.id == id) return material;
    }
    return null;
  }

  MaterialBill? billById(String id) {
    for (final bill in bills) {
      if (bill.id == id) return bill;
    }
    return null;
  }

  /// What [billId] brought: one entry per item, at the bill's quantity and
  /// rate, with the material's id.
  List<MaterialEntry> materialsOfBill(String billId) => [
    for (final material in materials)
      for (final receipt in material.receipts)
        if (receipt.billId == billId)
          MaterialEntry(
            id: material.id,
            date: receipt.date,
            name: material.name,
            quantity: receipt.quantity,
            unit: material.unit,
            rate: receipt.rate,
            supplier: receipt.supplier,
            billId: billId,
          ),
  ];

  /// A bill saved before that this looks like: the same file, or the same
  /// bill number from the same supplier.
  MaterialBill? earlierBill({SiteFile? file, String supplier = '', String billNumber = ''}) {
    String plain(String text) => text.trim().toLowerCase();
    final hash = file?.contentHash;
    for (final bill in bills) {
      if (hash != null && bill.file.contentHash == hash) return bill;
      if (plain(billNumber).isNotEmpty &&
          plain(bill.billNumber) == plain(billNumber) &&
          plain(bill.supplier) == plain(supplier)) {
        return bill;
      }
    }
    return null;
  }

  /// Adds delivered [items], as the server does: one already on the list
  /// (same name and unit) gets the quantity added and takes the new rate.
  void receive(List<MaterialEntry> items, {required String Function() newId, MaterialBill? bill}) {
    for (final item in items) {
      final receipt = MaterialReceipt(
        id: newId(),
        date: bill?.date ?? item.date,
        quantity: item.quantity,
        rate: item.rate,
        supplier: bill?.supplier ?? item.supplier,
        billId: bill?.id,
        billNumber: bill?.billNumber ?? '',
        addedAt: DateTime.now(),
      );
      final index = materials.indexWhere((m) => m.key == item.key);
      if (index == -1) {
        materials.add(
          MaterialEntry(
            id: item.id,
            date: receipt.date,
            name: item.name.trim(),
            quantity: item.quantity,
            unit: item.unit.trim(),
            rate: item.rate,
            supplier: receipt.supplier,
            billId: bill?.id,
            history: [receipt],
          ),
        );
        continue;
      }
      final material = materials[index];
      materials[index] = MaterialEntry(
        id: material.id,
        date: receipt.date,
        name: material.name,
        quantity: ((material.quantity + item.quantity) * 1000).round() / 1000,
        unit: material.unit,
        rate: item.rate,
        supplier: receipt.supplier.isEmpty ? material.supplier : receipt.supplier,
        billId: bill?.id ?? material.billId,
        history: [...material.receipts, receipt],
      );
    }
  }

  // Labour
  int daysWorked(String workerId) => dailyWork.where((d) => d.workerIds.contains(workerId)).length;

  double wagesEarned(String workerId) => daysWorked(workerId) * (workerById(workerId)?.dailyWage ?? 0);

  double paidTo(String workerId) => _paid(ExpenseKind.worker, workerId);

  double wagesDue(String workerId) => wagesEarned(workerId) - paidTo(workerId);

  /// Wages for the workers present on [day].
  double labourCostOf(DailyWork day) => day.workerIds.fold(0, (sum, id) => sum + (workerById(id)?.dailyWage ?? 0));

  double get labourCost => workers.fold(0, (sum, w) => sum + wagesEarned(w.id));
  double get labourPaid => _paidAll(ExpenseKind.worker);

  // Materials
  double materialPaid(String materialId) => _paid(ExpenseKind.material, materialId);

  double materialDue(String materialId) => _paise((materialById(materialId)?.amount ?? 0) - materialPaid(materialId));

  double get materialCost => materials.fold(0, (sum, m) => sum + m.amount);
  double get materialPaidTotal => _paidAll(ExpenseKind.material);

  // Totals
  /// Everything owed so far: wages earned plus materials received.
  double get totalCost => labourCost + materialCost;
  double get totalPaid => labourPaid + materialPaidTotal;
  double get totalDue => totalCost - totalPaid;

  double _paid(ExpenseKind kind, String targetId) =>
      payments.where((p) => p.kind == kind && p.targetId == targetId).fold(0, (sum, p) => sum + p.amount);

  double _paidAll(ExpenseKind kind) => payments.where((p) => p.kind == kind).fold(0, (sum, p) => sum + p.amount);
}
