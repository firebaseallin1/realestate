import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { isValidObjectId, Types } from 'mongoose';
import type { ClientSession, Connection, Model } from 'mongoose';
import { Booking } from '../bookings/booking.schema.js';
import type { BookingDocument } from '../bookings/booking.schema.js';
import { AppError } from '../common/app-error.js';
import { toFileJson } from '../files/file.schema.js';
import { FilesService } from '../files/files.service.js';
import { User, UserRole } from '../users/user.schema.js';
import type { UserDocument } from '../users/user.schema.js';
import {
  AddDailyWorkDto,
  AddExpensePaymentDto,
  AddMaterialBillDto,
  AddWorkerDto,
  SaveMaterialDto,
  UpdateStageDto,
} from './dto/project.dto.js';
import {
  DailyWork,
  DEFAULT_STAGES,
  ExpensePayment,
  Material,
  MaterialBill,
  MaterialReceipt,
  Project,
  Worker,
} from './project.schema.js';
import type {
  DailyWorkDocument,
  ExpensePaymentDocument,
  MaterialBillDocument,
  MaterialDocument,
  ProjectDocument,
  WorkerDocument,
} from './project.schema.js';

const notFound = (what = 'This project') =>
  new AppError('NOT_FOUND', `${what} no longer exists.`, HttpStatus.NOT_FOUND);
const conflict = (code: string, message: string) => new AppError(code, message, HttpStatus.CONFLICT);
const rupees = (paise: number) => `₹${(paise / 100).toLocaleString('en-IN')}`;

/** Rounded to the paisa, like a bill. */
const amountOf = (quantity: number, ratePaise: number) => Math.round(quantity * ratePaise);

/** The same material, however it was typed: "Cement  OPC" and "cement opc". */
const materialKey = (name: string, unit: string) =>
  `${name.trim().replace(/\s+/g, ' ').toLowerCase()}|${unit.trim().toLowerCase()}`;

/** A day such as "12 Nov 2026". */
const dayLabel = (date: Date) =>
  date.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'Asia/Kolkata' });

type Delivery = { date: string; supplier: string; billId: Types.ObjectId | null; billNumber: string };
type DeliveredItem = { name: string; quantity: number; unit: string; ratePaise: number };

/**
 * ProjectsService is the house being built for one With Construction booking.
 * A project is addressed by its booking's ID, as the app does.
 */
@Injectable()
export class ProjectsService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel(Project.name) private readonly projects: Model<Project>,
    @InjectModel(Booking.name) private readonly bookings: Model<Booking>,
    @InjectModel(User.name) private readonly users: Model<User>,
    @InjectModel(Worker.name) private readonly workers: Model<Worker>,
    @InjectModel(DailyWork.name) private readonly dailyWork: Model<DailyWork>,
    @InjectModel(MaterialBill.name) private readonly bills: Model<MaterialBill>,
    @InjectModel(Material.name) private readonly materials: Model<Material>,
    @InjectModel(ExpensePayment.name) private readonly expenses: Model<ExpensePayment>,
    private readonly files: FilesService,
  ) {}

  /** Opened when a With Construction booking is approved. */
  async openFor(bookingId: Types.ObjectId, session: ClientSession): Promise<void> {
    await this.projects.create(
      [{ bookingId, inchargeId: null, stages: DEFAULT_STAGES.map((name) => ({ name })) }],
      { session },
    );
  }

  /** Site Incharges get only the houses assigned to them. */
  async list(me: UserDocument) {
    const filter = me.role === UserRole.siteIncharge ? { inchargeId: me._id } : {};
    const projects = await this.projects.find(filter).sort({ createdAt: 1 });
    return this.toJson(projects);
  }

  async assignIncharge(bookingId: string, inchargeId: string | null | undefined, me: UserDocument) {
    const project = await this.find(bookingId, me);
    if (inchargeId) {
      const incharge = await this.users.exists({ _id: inchargeId, role: UserRole.siteIncharge, active: true });
      if (!incharge) throw conflict('NOT_AN_INCHARGE', 'Please choose an active Site Incharge.');
    }
    project.inchargeId = inchargeId ? new Types.ObjectId(inchargeId) : null;
    await project.save();
    return this.one(project);
  }

  async updateStage(bookingId: string, stageId: string, dto: UpdateStageDto, me: UserDocument) {
    const project = await this.find(bookingId, me);
    const stage = isValidObjectId(stageId) ? project.stages.id(stageId) : null;
    if (!stage) throw notFound('This stage');

    stage.status = dto.status;
    // Completed means 100%; not started means 0%.
    stage.progress = dto.status === 'completed' ? 100 : dto.status === 'notStarted' ? 0 : Math.min(Math.max(dto.progress, 1), 99);
    stage.note = dto.note ?? '';
    await project.save();
    return this.one(project);
  }

  async addWorker(bookingId: string, dto: AddWorkerDto, me: UserDocument) {
    const project = await this.find(bookingId, me);
    await this.workers.create({ ...dto, phone: dto.phone ?? '', projectId: project._id });
    return this.one(project);
  }

  /** A work update also starts its stage, and records attendance for wages. */
  async addDailyWork(bookingId: string, dto: AddDailyWorkDto, me: UserDocument) {
    const project = await this.find(bookingId, me);
    const stage = project.stages.id(dto.stageId);
    if (!stage) throw notFound('This stage');

    const present = await this.workers.countDocuments({ _id: { $in: dto.workerIds }, projectId: project._id });
    if (present !== new Set(dto.workerIds).size) throw conflict('UNKNOWN_WORKER', 'A selected worker is not on this site.');

    await this.connection.transaction(async (session) => {
      await this.dailyWork.create(
        [{ ...dto, projectId: project._id, updatedById: me._id, updatedByName: me.name }],
        { session },
      );
      if (stage.status === 'notStarted') {
        stage.status = 'inProgress';
        stage.progress = 5;
        await project.save({ session });
      }
    });
    return this.one(project);
  }

  /** Material already on the list gets the new quantity added. */
  async addMaterial(bookingId: string, dto: SaveMaterialDto, me: UserDocument) {
    const project = await this.find(bookingId, me);
    const delivery = { date: dto.date, supplier: dto.supplier ?? '', billId: null, billNumber: '' };
    await this.connection.transaction((session) => this.receive(project._id, [dto], delivery, session));
    return this.one(project);
  }

  /**
   * Adds delivered items to the materials list. An item already on it
   * (same name and unit) has its quantity added and takes the new rate;
   * either way the delivery goes into the material's history.
   */
  private async receive(projectId: Types.ObjectId, items: DeliveredItem[], delivery: Delivery, session: ClientSession) {
    const existing = await this.materials.find({ projectId }).session(session);
    const byKey = new Map(existing.map((material) => [materialKey(material.name, material.unit), material]));
    const changed = new Set<MaterialDocument>();

    for (const item of items) {
      const receipt = { ...delivery, quantity: item.quantity, ratePaise: item.ratePaise, addedAt: new Date() };
      const key = materialKey(item.name, item.unit);
      const material = byKey.get(key);
      if (!material) {
        const created = new this.materials({
          projectId,
          name: item.name.trim(),
          unit: item.unit.trim(),
          quantity: item.quantity,
          ratePaise: item.ratePaise,
          amountPaise: amountOf(item.quantity, item.ratePaise),
          date: delivery.date,
          supplier: delivery.supplier,
          billId: delivery.billId,
          history: [receipt],
        });
        byKey.set(key, created);
        changed.add(created);
        continue;
      }
      // Saved before histories were kept: its first delivery is what it holds.
      if (material.history.length === 0) {
        material.history.push({
          date: material.date,
          quantity: material.quantity,
          ratePaise: material.ratePaise,
          supplier: material.supplier,
          billId: material.billId,
          billNumber: '',
          addedAt: (material as unknown as { createdAt?: Date }).createdAt ?? new Date(),
        });
      }
      const quantity = Math.round((material.quantity + item.quantity) * 1000) / 1000;
      material.set({
        quantity,
        ratePaise: item.ratePaise,
        amountPaise: amountOf(quantity, item.ratePaise),
        date: delivery.date,
        supplier: delivery.supplier || material.supplier,
        billId: delivery.billId ?? material.billId,
      });
      material.history.push(receipt);
      changed.add(material);
    }
    for (const material of changed) await material.save({ session });
  }

  async updateMaterial(bookingId: string, materialId: string, dto: SaveMaterialDto, me: UserDocument) {
    const project = await this.find(bookingId, me);
    const material = isValidObjectId(materialId)
      ? await this.materials.findOne({ _id: materialId, projectId: project._id })
      : null;
    if (!material) throw notFound('This material');

    const amountPaise = amountOf(dto.quantity, dto.ratePaise);
    const paid = await this.paidTowards(project._id, 'material', material._id);
    if (amountPaise < paid) throw conflict('BELOW_PAID', `${rupees(paid)} is already paid on this material.`);

    material.set({ ...dto, supplier: dto.supplier ?? '', amountPaise });
    await material.save();
    return this.one(project);
  }

  /**
   * Saves a reviewed bill and its items, together or not at all. The same
   * file, or the same bill number from the same supplier, is refused
   * unless [allowDuplicate] says to save it again.
   */
  async addMaterialBill(bookingId: string, dto: AddMaterialBillDto, me: UserDocument) {
    const project = await this.find(bookingId, me);
    const file = await this.files.findOrThrow(dto.fileId);
    const supplier = dto.supplier ?? '';
    const billNumber = dto.billNumber ?? '';

    if (!dto.allowDuplicate) {
      const same = (a: string, b: string) => a.trim().toLowerCase() === b.trim().toLowerCase();
      const earlier = (await this.bills.find({ projectId: project._id }).sort({ createdAt: 1 })).find(
        (bill) =>
          (file.sha256 && bill.fileSha256 === file.sha256) ||
          (billNumber && same(bill.billNumber, billNumber) && same(bill.supplier, supplier)),
      );
      if (earlier) {
        const scanned = (earlier as unknown as { createdAt?: Date }).createdAt ?? new Date();
        throw conflict('DUPLICATE_BILL', `This bill was already scanned on ${dayLabel(scanned)}.`);
      }
    }

    await this.connection.transaction(async (session) => {
      const [bill] = await this.bills.create(
        [{ projectId: project._id, fileId: file._id, fileSha256: file.sha256 ?? '', supplier, billNumber, date: dto.date }],
        { session },
      );
      await this.receive(project._id, dto.items, { date: dto.date, supplier, billId: bill._id, billNumber }, session);
    });
    return this.one(project);
  }

  /** Pays wages or a material bill, up to what is due. */
  async addExpensePayment(bookingId: string, dto: AddExpensePaymentDto, me: UserDocument) {
    const project = await this.find(bookingId, me);
    await this.connection.transaction(async (session) => {
      // Touching the project makes payments at the same moment take turns,
      // so together they cannot exceed what is due.
      await this.projects.updateOne({ _id: project._id }, { $inc: { revision: 1 } }, { session });

      const targetId = new Types.ObjectId(dto.targetId);
      const owed = dto.kind === 'worker'
        ? await this.wagesEarned(project._id, targetId, session)
        : await this.materialAmount(project._id, targetId, session);
      const due = owed - (await this.paidTowards(project._id, dto.kind, targetId, session));
      if (dto.amountPaise > due) throw conflict('MORE_THAN_DUE', `More than the ${rupees(due)} due.`);

      await this.expenses.create(
        [{ ...dto, targetId, reference: dto.reference ?? '', projectId: project._id, createdBy: me._id }],
        { session },
      );
    });
    return this.one(project);
  }

  private async wagesEarned(projectId: Types.ObjectId, workerId: Types.ObjectId, session: ClientSession) {
    const worker = await this.workers.findOne({ _id: workerId, projectId }).session(session);
    if (!worker) throw notFound('This worker');
    const days = await this.dailyWork.countDocuments({ projectId, workerIds: workerId }).session(session);
    return days * worker.dailyWagePaise;
  }

  private async materialAmount(projectId: Types.ObjectId, materialId: Types.ObjectId, session: ClientSession) {
    const material = await this.materials.findOne({ _id: materialId, projectId }).session(session);
    if (!material) throw notFound('This material');
    return material.amountPaise;
  }

  private async paidTowards(projectId: Types.ObjectId, kind: string, targetId: Types.ObjectId, session?: ClientSession) {
    const payments = await this.expenses.find({ projectId, kind, targetId }).session(session ?? null);
    return payments.reduce((sum, payment) => sum + payment.amountPaise, 0);
  }

  /** Finds the project, keeping a Site Incharge to their own houses. */
  private async find(bookingId: string, me: UserDocument): Promise<ProjectDocument> {
    const project = isValidObjectId(bookingId) ? await this.projects.findOne({ bookingId }) : null;
    if (!project) throw notFound();
    if (me.role === UserRole.siteIncharge && !project.inchargeId?.equals(me._id)) {
      throw new AppError('FORBIDDEN', 'This house is not assigned to you.', HttpStatus.FORBIDDEN);
    }
    return project;
  }

  private async one(project: ProjectDocument) {
    return (await this.toJson([project]))[0];
  }

  private async toJson(projects: ProjectDocument[]) {
    const ids = projects.map((project) => project._id);
    const child = { projectId: { $in: ids } };
    const [bookings, workers, dailyWork, materials, bills, expenses] = await Promise.all([
      this.bookings.find({ _id: { $in: projects.map((project) => project.bookingId) } }),
      this.workers.find(child).sort({ createdAt: 1 }),
      this.dailyWork.find(child).sort({ createdAt: 1 }),
      this.materials.find(child).sort({ createdAt: 1 }),
      this.bills.find(child).sort({ createdAt: 1 }),
      this.expenses.find(child).sort({ createdAt: 1 }),
    ]);
    const files = await this.files.findMany(bills.map((bill) => bill.fileId));
    const belongs = (project: ProjectDocument) => (row: { projectId: Types.ObjectId }) => row.projectId.equals(project._id);

    return projects.map((project) => {
      const mine = belongs(project);
      return {
        booking: this.bookingJson(bookings.find((booking) => booking._id.equals(project.bookingId))),
        inchargeId: project.inchargeId?.toString() ?? null,
        stages: project.stages.map((stage) => ({
          id: stage._id.toString(),
          name: stage.name,
          status: stage.status,
          progress: stage.progress,
          note: stage.note,
        })),
        workers: workers.filter(mine).map((row: WorkerDocument) => ({
          id: row.id as string,
          name: row.name,
          trade: row.trade,
          dailyWagePaise: row.dailyWagePaise,
          phone: row.phone,
        })),
        dailyWork: dailyWork.filter(mine).map((row: DailyWorkDocument) => ({
          id: row.id as string,
          date: row.date,
          stageId: row.stageId.toString(),
          description: row.description,
          workerIds: row.workerIds.map(String),
          updatedBy: row.updatedByName,
        })),
        materials: materials.filter(mine).map((row: MaterialDocument) => ({
          id: row.id as string,
          date: row.date,
          name: row.name,
          quantity: row.quantity,
          unit: row.unit,
          ratePaise: row.ratePaise,
          supplier: row.supplier,
          billId: row.billId?.toString() ?? null,
          history: this.historyJson(row),
        })),
        bills: bills.filter(mine).flatMap((row: MaterialBillDocument) => {
          const file = files.get(row.fileId.toString());
          return file
            ? [{
                id: row.id as string,
                file: toFileJson(file),
                supplier: row.supplier,
                billNumber: row.billNumber,
                date: row.date,
                scannedAt: ((row as unknown as { createdAt?: Date }).createdAt ?? new Date()).toISOString(),
              }]
            : [];
        }),
        payments: expenses.filter(mine).map((row: ExpensePaymentDocument) => ({
          id: row.id as string,
          kind: row.kind,
          targetId: row.targetId.toString(),
          amountPaise: row.amountPaise,
          date: row.date,
          method: row.method,
          reference: row.reference,
        })),
      };
    });
  }

  /** A material's deliveries; one saved before histories were kept counts as one. */
  private historyJson(row: MaterialDocument) {
    const receipts = row.history.length > 0
      ? row.history.map((receipt) => ({ id: receipt._id.toString(), ...this.receiptJson(receipt) }))
      : [{
          id: row.id as string,
          ...this.receiptJson({
            date: row.date,
            quantity: row.quantity,
            ratePaise: row.ratePaise,
            supplier: row.supplier,
            billId: row.billId,
            billNumber: '',
            addedAt: (row as unknown as { createdAt?: Date }).createdAt ?? new Date(),
          }),
        }];
    return receipts;
  }

  private receiptJson(receipt: MaterialReceipt) {
    return {
      date: receipt.date,
      quantity: receipt.quantity,
      ratePaise: receipt.ratePaise,
      supplier: receipt.supplier,
      billId: receipt.billId?.toString() ?? null,
      billNumber: receipt.billNumber,
      addedAt: receipt.addedAt.toISOString(),
    };
  }

  /** What site staff need of the booking. Customer contact and payments stay with sales. */
  private bookingJson(booking?: BookingDocument) {
    if (!booking) throw notFound('This booking');
    return {
      id: booking.id as string,
      siteId: booking.siteId.toString(),
      siteName: booking.siteName,
      plotNumber: booking.plotNumber,
      customer: { name: booking.customer.name, mobile: '' },
      type: booking.type,
      status: booking.status,
      bookedOn: booking.bookedOn,
      bookedBy: booking.bookedByName,
      plans: booking.plans.map((plan) => ({ part: plan.part, valuePaise: plan.valuePaise, mode: plan.mode })),
    };
  }
}
