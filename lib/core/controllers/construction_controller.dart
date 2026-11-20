import 'package:flutter/foundation.dart';

import '../../models/app_user.dart';
import '../../models/booking.dart';
import '../../models/construction.dart';
import '../../models/site.dart';
import '../api/api_client.dart';
import '../utils/date_text.dart';
import '../repositories/construction_repository.dart';
import '../utils/material_bill_parser.dart';
import 'booking_controller.dart';

/// ConstructionController holds the construction work for every approved
/// With Construction booking: stages, daily updates, workers, materials, and
/// the worker and material payments. Site Incharges see only projects assigned
/// to them.
///
/// The app's [instance] loads from and saves to the server, which opens a
/// project when its booking is approved, and throws an ApiException if it
/// refuses a change. Other controllers work on sample data in memory, opening
/// a project the first time its booking is seen approved.
class ConstructionController extends ChangeNotifier {
  ConstructionController(this._bookings) : _repository = null {
    _bookings.addListener(notifyListeners);
    _seed();
  }

  ConstructionController._server(this._bookings) : _repository = ConstructionRepository() {
    _bookings.addListener(notifyListeners);
    // Site staff cannot see bookings, but an Admin approving one opens a house.
    _bookings.onServerChange = load;
  }

  static final ConstructionController instance = ConstructionController._server(BookingController.instance);

  final BookingController _bookings;
  final ConstructionRepository? _repository;
  final Map<String, ConstructionProject> _projects = {};
  int _nextId = 1;

  String _id(String prefix) => '$prefix${_nextId++}';

  @override
  void dispose() {
    _bookings.removeListener(notifyListeners);
    super.dispose();
  }

  /// Bookings that get a construction project.
  static bool qualifies(Booking b) => b.type == BookingType.withConstruction && b.status == BookingStatus.approved;

  /// Every project, opening new ones for newly approved bookings. The
  /// project always carries the latest copy of its booking.
  List<ConstructionProject> get projects {
    if (_repository != null) return _projects.values.toList();
    return [for (final booking in _bookings.bookings.where(qualifies)) _projectFor(booking)];
  }

  /// Fetches the projects this user may see from the server.
  Future<void> load() async {
    final repository = _repository;
    if (repository == null) return;
    final latest = await repository.fetchProjects();
    _projects.removeWhere((id, _) => !latest.any((p) => p.id == id));
    latest.forEach(_keep);
    notifyListeners();
  }

  /// Forgets everything on sign-out, so the next user cannot see it.
  void clear() {
    _projects.clear();
    notifyListeners();
  }

  /// Updates the project in place, so screens already holding it stay current.
  void _keep(ConstructionProject latest) {
    final existing = _projects[latest.id];
    if (existing != null) {
      existing.updateFrom(latest);
    } else {
      _projects[latest.id] = latest;
    }
  }

  Future<void> _save(Future<ConstructionProject> saving) async {
    _keep(await saving);
    notifyListeners();
  }

  ConstructionProject _projectFor(Booking booking) {
    final existing = _projects[booking.id];
    if (existing != null) return existing..booking = booking;
    return _projects[booking.id] = ConstructionProject(
      booking: booking,
      stages: [for (final name in ConstructionStage.defaultNames) ConstructionStage(id: _id('st'), name: name)],
    );
  }

  /// Projects [user] works on: all of them, or for a Site Incharge only
  /// those assigned to them.
  List<ConstructionProject> projectsFor(AppUser user) =>
      user.role == UserRole.siteIncharge ? projects.where((p) => p.inchargeId == user.id).toList() : projects;

  ConstructionProject? projectById(String bookingId) {
    if (_repository != null) return _projects[bookingId];
    final booking = _bookings.bookingById(bookingId);
    return booking != null && qualifies(booking) ? _projectFor(booking) : null;
  }

  Future<void> assignIncharge(String projectId, String? inchargeId) async {
    final repository = _repository;
    if (repository != null) return _save(repository.assignIncharge(projectId, inchargeId));
    projectById(projectId)?.inchargeId = inchargeId;
    notifyListeners();
  }

  Future<void> updateStage(
    String projectId,
    String stageId, {
    required StageStatus status,
    required int progress,
    String note = '',
  }) async {
    final repository = _repository;
    if (repository != null) return _save(repository.updateStage(projectId, stageId, status, progress, note));
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

  Future<void> addDailyWork(String projectId, DailyWork work) async {
    final repository = _repository;
    if (repository != null) return _save(repository.addDailyWork(projectId, work));
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

  Future<void> addWorker(String projectId, Worker worker) async {
    final repository = _repository;
    if (repository != null) return _save(repository.addWorker(projectId, worker));
    projectById(projectId)?.workers.add(worker);
    notifyListeners();
  }

  Future<void> addMaterial(String projectId, MaterialEntry material) async {
    final repository = _repository;
    if (repository != null) return _save(repository.addMaterial(projectId, material));
    projectById(projectId)?.receive([material], newId: () => _id('mr'));
    notifyListeners();
  }

  /// Whether bills are read by AI on the server, which handles scans and
  /// handwriting. Without a server they are read on the device.
  bool get readsBillsOnServer => _repository != null;

  /// Reads [file] on the server: the uploaded file, what was read, and notes.
  /// Throws an ApiException, e.g. AI_READING_OFF when the server has no AI
  /// reader set up.
  Future<(SiteFile, ParsedBill, String)> readBill(SiteFile file) => _repository!.readBill(file);

  /// Saves a scanned [bill] with the materials reviewed from it. A bill
  /// that looks scanned before is refused with DUPLICATE_BILL, unless
  /// [allowDuplicate].
  Future<void> addMaterialBill(
    String projectId,
    MaterialBill bill,
    List<MaterialEntry> materials, {
    bool allowDuplicate = false,
  }) async {
    final repository = _repository;
    if (repository != null) {
      return _save(repository.addMaterialBill(projectId, bill, materials, allowDuplicate: allowDuplicate));
    }
    final project = projectById(projectId);
    if (project == null) return;
    final earlier = allowDuplicate
        ? null
        : project.earlierBill(file: bill.file, supplier: bill.supplier, billNumber: bill.billNumber);
    if (earlier != null) {
      throw ApiException(
        'DUPLICATE_BILL',
        'This bill was already scanned on ${DateText.shortDate(earlier.scannedOn)}.',
      );
    }
    final saved = MaterialBill(
      id: bill.id,
      file: bill.file,
      date: bill.date,
      supplier: bill.supplier,
      billNumber: bill.billNumber,
      scannedAt: DateTime.now(),
    );
    project.bills.add(saved);
    project.receive(materials, newId: () => _id('mr'), bill: saved);
    notifyListeners();
  }

  Future<void> updateMaterial(String projectId, MaterialEntry material) async {
    final repository = _repository;
    if (repository != null) return _save(repository.updateMaterial(projectId, material));
    final materials = projectById(projectId)?.materials;
    final index = materials?.indexWhere((m) => m.id == material.id) ?? -1;
    if (index == -1) return;
    // The form edits the totals; the deliveries stay as they were.
    materials![index] = material.copyWith(history: materials[index].history);
    notifyListeners();
  }

  Future<void> addPayment(String projectId, ExpensePayment payment) async {
    final repository = _repository;
    if (repository != null) return _save(repository.addPayment(projectId, payment));
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
      MaterialEntry(
        id: 'm1',
        date: DateTime(2026, 9, 28),
        name: 'Cement (OPC 53)',
        quantity: 200,
        unit: 'bags',
        rate: 380,
        supplier: 'Sri Sai Traders',
      ),
      MaterialEntry(
        id: 'm2',
        date: DateTime(2026, 9, 30),
        name: 'TMT Steel',
        quantity: 2500,
        unit: 'kg',
        rate: 62,
        supplier: 'Vizag Steels Dealer',
      ),
      MaterialEntry(
        id: 'm3',
        date: DateTime(2026, 10, 15),
        name: 'Red Bricks',
        quantity: 20000,
        unit: 'nos',
        rate: 8,
        supplier: 'Lakshmi Bricks',
      ),
      MaterialEntry(
        id: 'm4',
        date: DateTime(2026, 10, 16),
        name: 'River Sand',
        quantity: 10,
        unit: 'loads',
        rate: 6500,
      ),
    ]);

    project.payments.addAll([
      ExpensePayment(
        id: 'e1',
        kind: ExpenseKind.material,
        targetId: 'm1',
        amount: 76000,
        date: DateTime(2026, 9, 28),
        method: PaymentMethod.bankTransfer,
        reference: 'NEFT 1102',
      ),
      ExpensePayment(
        id: 'e2',
        kind: ExpenseKind.material,
        targetId: 'm2',
        amount: 100000,
        date: DateTime(2026, 10, 1),
        method: PaymentMethod.cheque,
        reference: 'CHQ 778201',
      ),
      ExpensePayment(
        id: 'e3',
        kind: ExpenseKind.material,
        targetId: 'm3',
        amount: 160000,
        date: DateTime(2026, 10, 15),
        method: PaymentMethod.upi,
      ),
      ExpensePayment(
        id: 'e4',
        kind: ExpenseKind.worker,
        targetId: 'w1',
        amount: 1800,
        date: DateTime(2026, 10, 21),
        method: PaymentMethod.cash,
      ),
      ExpensePayment(
        id: 'e5',
        kind: ExpenseKind.worker,
        targetId: 'w3',
        amount: 1200,
        date: DateTime(2026, 10, 21),
        method: PaymentMethod.cash,
      ),
    ]);
  }
}
