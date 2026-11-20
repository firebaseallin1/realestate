import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { SchemaTypes, Types } from 'mongoose';
import type { HydratedDocument } from 'mongoose';
import { PAYMENT_METHODS } from '../bookings/booking.schema.js';

// Same names as the app's enums.
export const STAGE_STATUSES = ['notStarted', 'inProgress', 'completed'];
export const WORKER_TRADES = ['mason', 'helper', 'carpenter', 'barBender', 'electrician', 'plumber', 'tiler', 'painter'];
export const EXPENSE_KINDS = ['worker', 'material'];

/** The usual stages of an independent house, in order. */
export const DEFAULT_STAGES = [
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

@Schema()
export class Stage {
  @Prop({ type: String, required: true })
  name: string;

  @Prop({ type: String, enum: STAGE_STATUSES, default: 'notStarted' })
  status: string;

  @Prop({ type: Number, default: 0 })
  progress: number;

  @Prop({ type: String, default: '' })
  note: string;
}

@Schema({ timestamps: true, collection: 'projects' })
export class Project {
  @Prop({ type: SchemaTypes.ObjectId, required: true, unique: true })
  bookingId: Types.ObjectId;

  @Prop({ type: SchemaTypes.ObjectId, default: null, index: true })
  inchargeId: Types.ObjectId | null;

  @Prop({ type: [SchemaFactory.createForClass(Stage)], required: true })
  stages: Types.DocumentArray<Stage & { _id: Types.ObjectId }>;

  /** Changed by every payment, so payments at the same moment take turns. */
  @Prop({ type: Number, default: 0 })
  revision: number;
}
export type ProjectDocument = HydratedDocument<Project>;
export const ProjectSchema = SchemaFactory.createForClass(Project);

const childOfProject = { type: SchemaTypes.ObjectId, required: true, index: true };

@Schema({ timestamps: true, collection: 'workers' })
export class Worker {
  @Prop(childOfProject)
  projectId: Types.ObjectId;

  @Prop({ type: String, required: true })
  name: string;

  @Prop({ type: String, required: true, enum: WORKER_TRADES })
  trade: string;

  @Prop({ type: Number, required: true })
  dailyWagePaise: number;

  @Prop({ type: String, default: '' })
  phone: string;
}
export type WorkerDocument = HydratedDocument<Worker>;
export const WorkerSchema = SchemaFactory.createForClass(Worker);

@Schema({ timestamps: true, collection: 'dailyWork' })
export class DailyWork {
  @Prop(childOfProject)
  projectId: Types.ObjectId;

  @Prop({ type: String, required: true })
  date: string;

  @Prop({ type: SchemaTypes.ObjectId, required: true })
  stageId: Types.ObjectId;

  @Prop({ type: String, required: true })
  description: string;

  @Prop({ type: [SchemaTypes.ObjectId], required: true })
  workerIds: Types.ObjectId[];

  @Prop({ type: SchemaTypes.ObjectId, required: true })
  updatedById: Types.ObjectId;

  @Prop({ type: String, required: true })
  updatedByName: string;
}
export type DailyWorkDocument = HydratedDocument<DailyWork>;
export const DailyWorkSchema = SchemaFactory.createForClass(DailyWork);

@Schema({ timestamps: true, collection: 'materialBills' })
export class MaterialBill {
  @Prop(childOfProject)
  projectId: Types.ObjectId;

  @Prop({ type: SchemaTypes.ObjectId, required: true })
  fileId: Types.ObjectId;

  @Prop({ type: String, default: '' })
  supplier: string;

  @Prop({ type: String, default: '' })
  billNumber: string;

  @Prop({ type: String, required: true })
  date: string;

  /** The file's SHA-256, to spot the same bill scanned again. */
  @Prop({ type: String, default: '' })
  fileSha256: string;
}
export type MaterialBillDocument = HydratedDocument<MaterialBill>;
export const MaterialBillSchema = SchemaFactory.createForClass(MaterialBill);

/** One delivery of a material, from a scanned bill or added by hand. */
@Schema()
export class MaterialReceipt {
  @Prop({ type: String, required: true })
  date: string;

  @Prop({ type: Number, required: true })
  quantity: number;

  @Prop({ type: Number, required: true })
  ratePaise: number;

  @Prop({ type: String, default: '' })
  supplier: string;

  @Prop({ type: SchemaTypes.ObjectId, default: null })
  billId: Types.ObjectId | null;

  @Prop({ type: String, default: '' })
  billNumber: string;

  /** When it was scanned or entered. */
  @Prop({ type: Date, default: () => new Date() })
  addedAt: Date;
}
export const MaterialReceiptSchema = SchemaFactory.createForClass(MaterialReceipt);

@Schema({ timestamps: true, collection: 'materials' })
export class Material {
  @Prop(childOfProject)
  projectId: Types.ObjectId;

  @Prop({ type: SchemaTypes.ObjectId, default: null })
  billId: Types.ObjectId | null;

  @Prop({ type: String, required: true })
  date: string;

  @Prop({ type: String, required: true })
  name: string;

  @Prop({ type: Number, required: true })
  quantity: number;

  @Prop({ type: String, required: true })
  unit: string;

  @Prop({ type: Number, required: true })
  ratePaise: number;

  /** Calculated here from quantity and rate, never taken from the app. */
  @Prop({ type: Number, required: true })
  amountPaise: number;

  /** Every delivery, oldest first. Quantity is their total; rate the latest. */
  @Prop({ type: [MaterialReceiptSchema], default: [] })
  history: Types.DocumentArray<MaterialReceipt & { _id: Types.ObjectId }>;

  @Prop({ type: String, default: '' })
  supplier: string;
}
export type MaterialDocument = HydratedDocument<Material>;
export const MaterialSchema = SchemaFactory.createForClass(Material);

@Schema({ timestamps: true, collection: 'expensePayments' })
export class ExpensePayment {
  @Prop(childOfProject)
  projectId: Types.ObjectId;

  @Prop({ type: String, required: true, enum: EXPENSE_KINDS })
  kind: string;

  /** The worker's or the material's ID. */
  @Prop({ type: SchemaTypes.ObjectId, required: true })
  targetId: Types.ObjectId;

  @Prop({ type: Number, required: true })
  amountPaise: number;

  @Prop({ type: String, required: true })
  date: string;

  @Prop({ type: String, required: true, enum: PAYMENT_METHODS })
  method: string;

  @Prop({ type: String, default: '' })
  reference: string;

  @Prop({ type: SchemaTypes.ObjectId, required: true })
  createdBy: Types.ObjectId;
}
export type ExpensePaymentDocument = HydratedDocument<ExpensePayment>;
export const ExpensePaymentSchema = SchemaFactory.createForClass(ExpensePayment);
