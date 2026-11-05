import 'package:flutter/foundation.dart';
import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/construction.dart';
import 'booking_controller.dart';

/// ConstructionController holds the construction work for every approved
/// With Construction booking (in memory for now): stages, daily updates,
/// workers, materials, and the worker and material payments.
///
/// A project is opened with the standard stages the first time its booking
/// is seen approved. Site Incharges see only projects assigned to them.
class ConstructionController extends ChangeNotifier {
  ConstructionController(this._bookings) {
    _bookings.addListener(notifyListeners);
    _seed();
  }

  static final ConstructionController instance = ConstructionController(BookingController.instance);

  final BookingController _bookings;
  final Map<String, ConstructionProject> _projects = {};
  int _nextId = 1;

  String _id(String prefix) => '$prefix${_nextId++}';

  @override
  void dispose() {
    _bookings.removeListener(notifyListeners);
    super.dispose();
  }

  /// Bookings that get a construction project.
  static bool qualifies(Booking b) =>
      b.type == BookingType.withConstruction && b.status == BookingStatus.approved;

  /// Every project, opening new ones for newly approved bookings. The
  /// project always carries the latest copy of its booking.
  List<ConstructionProject> get projects {
    return [
      for (final booking in _bookings.bookings.where(qualifies)) _projectFor(booking),
    ];
  }

  ConstructionProject _projectFor(Booking booking) {
    final existing = _projects[booking.id];
    if (existing != null) return existing..booking = booking;
    return _projects[booking.id] = ConstructionProject(
      booking: booking,
      stages: [
        for (final name in ConstructionStage.defaultNames) ConstructionStage(id: _id('st'), name: name),
      ],
    );
  }

  /// Projects [user] works on: all of them, or for a Site Incharge only
  /// those assigned to them.
  List<ConstructionProject> projectsFor(AppUser user) => user.role == UserRole.siteIncharge
      ? projects.where((p) => p.inchargeId == user.id).toList()
      : projects;

  ConstructionProject? projectById(String bookingId) {
    final booking = _bookings.bookingById(bookingId);
    return booking != null && qualifies(booking) ? _projectFor(booking) : null;
  }

  void assignIncharge(String projectId, String? inchargeId) {
    projectById(projectId)?.inchargeId = inchargeId;
    notifyListeners();
  }

  void updateStage(String projectId, String stageId, {required StageStatus status, required int progress, String note = ''}) {
    final stage = projectById(projectId)?.stageById(stageId);
    if (stage == null) return;
    // Completed means 100%; not started means 0%.
    stage
      ..status = status
      ..progress = switch (status) {
        StageStatus.completed => 100,
        StageStatus.notStarted => 0,
        StageStatus.inProgress => progress.clamp(1, 99),
      }
      ..note = note;
    notifyListeners();
  }

  void addDailyWork(String projectId, DailyWork work) {
    final project = projectById(projectId);
    if (project == null) return;
    project.dailyWork.add(work);
    // Work on a stage that had not started marks it in progress.
    final stage = project.stageById(work.stageId);
    if (stage != null && stage.status == StageStatus.notStarted) {
      stage
        ..status = StageStatus.inProgress
        ..progress = 5;
    }
    notifyListeners();
  }

  void addWorker(String projectId, Worker worker) {
    projectById(projectId)?.workers.add(worker);
    notifyListeners();
  }

  void addMaterial(String projectId, MaterialEntry material) {
    projectById(projectId)?.materials.add(material);
    notifyListeners();
  }

  /// Saves a scanned [bill] with the materials reviewed from it.
  void addMaterialBill(String projectId, MaterialBill bill, List<MaterialEntry> materials) {
    final project = projectById(projectId);
    if (project == null) return;
    project.bills.add(bill);
    project.materials.addAll(materials);
    notifyListeners();
  }

  void updateMaterial(String projectId, MaterialEntry material) {
    final materials = projectById(projectId)?.materials;
    final index = materials?.indexWhere((m) => m.id == material.id) ?? -1;
    if (index == -1) return;
    materials![index] = material;
    notifyListeners();
  }

  void addPayment(String projectId, ExpensePayment payment) {
    projectById(projectId)?.payments.add(payment);
    notifyListeners();
  }

  String newId(String prefix) => _id(prefix);

  /// Sample work on Kiran Varma's house (booking b3), assigned to the
  /// demo Site Incharge.
  void _seed() {
    final booking = _bookings.bookingById('b3');
    if (booking == null || !qualifies(booking)) return;
    final project = _projectFor(booking)..inchargeId = 'u4';

    final stages = project.stages;
    stages[0]
      ..status = StageStatus.completed
      ..progress = 100;
    stages[1]
      ..status = StageStatus.completed
      ..progress = 100;
    stages[2]
      ..status = StageStatus.inProgress
      ..progress = 60
      ..note = 'Ground floor walls done, first floor started';

    project.workers.addAll(const [
      Worker(id: 'w1', name: 'Raju', trade: WorkerTrade.mason, dailyWage: 900, phone: '9000012345'),
      Worker(id: 'w2', name: 'Venkatesh', trade: WorkerTrade.mason, dailyWage: 900),
      Worker(id: 'w3', name: 'Lakshmi', trade: WorkerTrade.helper, dailyWage: 600),
      Worker(id: 'w4', name: 'Srinu', trade: WorkerTrade.barBender, dailyWage: 800),
    ]);

    project.dailyWork.addAll([
      DailyWork(
        id: 'd1',
        date: DateTime(2026, 10, 20),
        stageId: stages[2].id,
        description: 'Brickwork on ground floor east side',
        workerIds: const ['w1', 'w2', 'w3'],
        updatedBy: 'Suresh Reddy',
      ),
      DailyWork(
        id: 'd2',
        date: DateTime(2026, 10, 21),
        stageId: stages[2].id,
        description: 'Ground floor walls completed, lintel steel tied',
        workerIds: const ['w1', 'w2', 'w3', 'w4'],
        updatedBy: 'Suresh Reddy',
      ),
      DailyWork(
        id: 'd3',
        date: DateTime(2026, 10, 22),
        stageId: stages[2].id,
        description: 'First floor brickwork started',
        workerIds: const ['w1', 'w3'],
        updatedBy: 'Suresh Reddy',
      ),
    ]);

    project.materials.addAll([
      MaterialEntry(id: 'm1', date: DateTime(2026, 9, 28), name: 'Cement (OPC 53)', quantity: 200, unit: 'bags', rate: 380, supplier: 'Sri Sai Traders'),
      MaterialEntry(id: 'm2', date: DateTime(2026, 9, 30), name: 'TMT Steel', quantity: 2500, unit: 'kg', rate: 62, supplier: 'Vizag Steels Dealer'),
      MaterialEntry(id: 'm3', date: DateTime(2026, 10, 15), name: 'Red Bricks', quantity: 20000, unit: 'nos', rate: 8, supplier: 'Lakshmi Bricks'),
      MaterialEntry(id: 'm4', date: DateTime(2026, 10, 16), name: 'River Sand', quantity: 10, unit: 'loads', rate: 6500),
    ]);

    project.payments.addAll([
      ExpensePayment(id: 'e1', kind: ExpenseKind.material, targetId: 'm1', amount: 76000, date: DateTime(2026, 9, 28), method: PaymentMethod.bankTransfer, reference: 'NEFT 1102'),
      ExpensePayment(id: 'e2', kind: ExpenseKind.material, targetId: 'm2', amount: 100000, date: DateTime(2026, 10, 1), method: PaymentMethod.cheque, reference: 'CHQ 778201'),
      ExpensePayment(id: 'e3', kind: ExpenseKind.material, targetId: 'm3', amount: 160000, date: DateTime(2026, 10, 15), method: PaymentMethod.upi),
      ExpensePayment(id: 'e4', kind: ExpenseKind.worker, targetId: 'w1', amount: 1800, date: DateTime(2026, 10, 21), method: PaymentMethod.cash),
      ExpensePayment(id: 'e5', kind: ExpenseKind.worker, targetId: 'w3', amount: 1200, date: DateTime(2026, 10, 21), method: PaymentMethod.cash),
    ]);
  }
}
