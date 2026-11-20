import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { SchemaTypes, Types } from 'mongoose';
import type { HydratedDocument } from 'mongoose';

// Same names as the app's enums.
export const BOOKING_TYPES = ['withoutConstruction', 'withConstruction'];
export const PAYMENT_PARTS = ['plot', 'construction'];
export const PAYMENT_MODES = ['fullPayment', 'loan'];
export const LOAN_STATUSES = ['applied', 'sanctioned', 'partlyDisbursed', 'disbursed'];
/** Statuses set by hand; the disbursed ones follow loan disbursement payments. */
export const MANUAL_LOAN_STATUSES = ['applied', 'sanctioned'];
export const PAYMENT_METHODS = ['cash', 'upi', 'cheque', 'bankTransfer', 'loanDisbursement'];

@Schema({ _id: false })
class Customer {
  @Prop({ type: String, required: true })
  name: string;

  @Prop({ type: String, required: true })
  mobile: string;

  @Prop({ type: String, default: '' })
  email: string;

  @Prop({ type: String, default: '' })
  address: string;
}

@Schema({ _id: false })
class Loan {
  @Prop({ type: String, required: true })
  bankName: string;

  @Prop({ type: Number, required: true })
  amountPaise: number;

  @Prop({ type: String, default: '' })
  reference: string;

  @Prop({ type: String, enum: LOAN_STATUSES, default: 'applied' })
  status: string;
}

@Schema({ _id: false })
export class PaymentPlan {
  @Prop({ type: String, required: true, enum: PAYMENT_PARTS })
  part: string;

  @Prop({ type: Number, required: true })
  valuePaise: number;

  @Prop({ type: String, required: true, enum: PAYMENT_MODES })
  mode: string;

  @Prop({ type: SchemaFactory.createForClass(Loan), default: null })
  loan: Loan | null;
}

@Schema({ timestamps: true, collection: 'bookings' })
export class Booking {
  @Prop({ type: SchemaTypes.ObjectId, required: true, index: true })
  siteId: Types.ObjectId;

  @Prop({ type: String, required: true })
  siteName: string;

  @Prop({ type: SchemaTypes.ObjectId, default: null })
  plotId: Types.ObjectId | null;

  @Prop({ type: String, required: true })
  plotNumber: string;

  /** Trimmed, lowercase plot number, for the double-booking index below. */
  @Prop({ type: String, required: true })
  plotKey: string;

  @Prop({ type: String, default: null })
  plotSize: string | null;

  @Prop({ type: String, default: null })
  facing: string | null;

  @Prop({ type: SchemaFactory.createForClass(Customer), required: true })
  customer: Customer;

  @Prop({ type: String, required: true, enum: BOOKING_TYPES })
  type: string;

  @Prop({ type: [SchemaFactory.createForClass(PaymentPlan)], required: true })
  plans: PaymentPlan[];

  @Prop({ type: String, required: true, enum: ['pending', 'approved', 'rejected'], default: 'pending' })
  status: string;

  /** False once rejected, which frees the plot for someone else. */
  @Prop({ type: Boolean, default: true })
  live: boolean;

  @Prop({ type: String, required: true })
  bookedOn: string;

  @Prop({ type: SchemaTypes.ObjectId, required: true })
  bookedById: Types.ObjectId;

  @Prop({ type: String, required: true })
  bookedByName: string;

  @Prop({ type: Number, default: 0 })
  totalPaidPaise: number;
}

export type BookingDocument = HydratedDocument<Booking>;
export const BookingSchema = SchemaFactory.createForClass(Booking);

// The database itself refuses a second live booking of a plot, so two people
// booking at the same moment cannot both succeed.
BookingSchema.index({ siteId: 1, plotKey: 1 }, { unique: true, partialFilterExpression: { live: true } });

@Schema({ timestamps: true, collection: 'payments' })
export class Payment {
  @Prop({ type: SchemaTypes.ObjectId, required: true, index: true })
  bookingId: Types.ObjectId;

  @Prop({ type: String, required: true, enum: PAYMENT_PARTS })
  part: string;

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

export type PaymentDocument = HydratedDocument<Payment>;
export const PaymentSchema = SchemaFactory.createForClass(Payment);
