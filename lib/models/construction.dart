import 'package:flutter/material.dart';
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

  const Worker({
    required this.id,
    required this.name,
    required this.trade,
    required this.dailyWage,
    this.phone = '',
  });
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
}

/// MaterialEntry is material received at site, e.g. 200 bags of cement.
class MaterialEntry {
  final String id;
  final DateTime date;
  final String name;
  final double quantity;
  final String unit;
  final double rate;
  final String supplier;

  /// The bill this came from, when it was scanned from one.
  final String? billId;

  const MaterialEntry({
    required this.id,
    required this.date,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.rate,
    this.supplier = '',
    this.billId,
  });

  static const units = ['bags', 'kg', 'tons', 'nos', 'loads', 'cft', 'sqft', 'litres'];

  /// Rounded to paise, like a bill.
  double get amount => _paise(quantity * rate);

  MaterialEntry copyWith({DateTime? date, String? supplier, String? billId}) => MaterialEntry(
        id: id,
        date: date ?? this.date,
        name: name,
        quantity: quantity,
        unit: unit,
        rate: rate,
        supplier: supplier ?? this.supplier,
        billId: billId ?? this.billId,
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

  const MaterialBill({
    required this.id,
    required this.file,
    required this.date,
    this.supplier = '',
    this.billNumber = '',
  });
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

  String get id => booking.id;

  /// The construction value agreed in the booking.
  double get budget => booking.plan(PaymentPart.construction)?.value ?? 0;

  /// Average of the stages' progress, 0–100.
  int get progress =>
      stages.isEmpty ? 0 : (stages.fold<int>(0, (sum, s) => sum + s.progress) / stages.length).round();

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

  List<MaterialEntry> materialsOfBill(String billId) => materials.where((m) => m.billId == billId).toList();

  // Labour
  int daysWorked(String workerId) => dailyWork.where((d) => d.workerIds.contains(workerId)).length;

  double wagesEarned(String workerId) => daysWorked(workerId) * (workerById(workerId)?.dailyWage ?? 0);

  double paidTo(String workerId) => _paid(ExpenseKind.worker, workerId);

  double wagesDue(String workerId) => wagesEarned(workerId) - paidTo(workerId);

  /// Wages for the workers present on [day].
  double labourCostOf(DailyWork day) =>
      day.workerIds.fold(0, (sum, id) => sum + (workerById(id)?.dailyWage ?? 0));

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

  double _paid(ExpenseKind kind, String targetId) => payments
      .where((p) => p.kind == kind && p.targetId == targetId)
      .fold(0, (sum, p) => sum + p.amount);

  double _paidAll(ExpenseKind kind) => payments.where((p) => p.kind == kind).fold(0, (sum, p) => sum + p.amount);
}
