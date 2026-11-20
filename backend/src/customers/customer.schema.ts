import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { SchemaTypes, Types } from 'mongoose';
import type { HydratedDocument } from 'mongoose';

/**
 * A Customer is a buyer's own record, made when a lead is converted. Bookings
 * still carry a copy of the customer's details; the two meet on the mobile number.
 */
@Schema({ timestamps: true, collection: 'customers' })
export class Customer {
  @Prop({ type: String, required: true })
  name: string;

  @Prop({ type: String, required: true })
  mobile: string;

  /** The last 10 digits; one customer per number. */
  @Prop({ type: String, required: true, unique: true })
  mobileKey: string;

  @Prop({ type: String, default: '' })
  alternateMobile: string;

  @Prop({ type: String, default: '' })
  email: string;

  @Prop({ type: String, default: '' })
  address: string;

  @Prop({ type: String, default: '' })
  occupation: string;

  @Prop({ type: String, default: '' })
  notes: string;

  /** The lead this customer came from, and how that lead heard of us. */
  @Prop({ type: SchemaTypes.ObjectId, default: null })
  leadId: Types.ObjectId | null;

  @Prop({ type: String, default: null })
  source: string | null;

  @Prop({ type: SchemaTypes.ObjectId, required: true })
  ownerId: Types.ObjectId;

  @Prop({ type: String, required: true })
  ownerName: string;
}
export type CustomerDocument = HydratedDocument<Customer>;
export const CustomerSchema = SchemaFactory.createForClass(Customer);

export function toCustomerJson(customer: CustomerDocument) {
  return {
    id: customer.id as string,
    name: customer.name,
    mobile: customer.mobile,
    alternateMobile: customer.alternateMobile,
    email: customer.email,
    address: customer.address,
    occupation: customer.occupation,
    notes: customer.notes,
    leadId: customer.leadId?.toString() ?? null,
    source: customer.source,
    ownerName: customer.ownerName,
    createdAt: ((customer as unknown as { createdAt?: Date }).createdAt ?? new Date()).toISOString(),
  };
}
