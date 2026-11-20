import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { SchemaTypes, Types } from 'mongoose';
import type { HydratedDocument } from 'mongoose';
import { BOOKING_TYPES } from '../bookings/booking.schema.js';

// Same names as the app's enums.
export const LEAD_SOURCES = ['walkIn', 'phoneCall', 'website', 'referral', 'socialMedia', 'advertisement', 'other'];
export const LEAD_STATUSES = ['newLead', 'contacted', 'interested', 'siteVisit', 'negotiation', 'won', 'lost'];
export const FOLLOW_UP_MODES = ['call', 'whatsApp', 'siteVisit', 'meeting', 'email'];

/** Won and lost leads need no more follow-ups. */
export const CLOSED_STATUSES = ['won', 'lost'];

export { BOOKING_TYPES as INTEREST_TYPES };

/** One contact with the lead: what was discussed and what happens next. */
@Schema()
export class FollowUp {
  @Prop({ type: String, required: true })
  date: string;

  @Prop({ type: String, required: true, enum: FOLLOW_UP_MODES })
  mode: string;

  @Prop({ type: String, required: true })
  note: string;

  /** Where the lead stood after this contact. */
  @Prop({ type: String, required: true, enum: LEAD_STATUSES })
  status: string;

  @Prop({ type: String, default: null })
  nextDate: string | null;

  @Prop({ type: SchemaTypes.ObjectId, required: true })
  byId: Types.ObjectId;

  @Prop({ type: String, required: true })
  byName: string;

  @Prop({ type: Date, default: () => new Date() })
  addedAt: Date;
}
export const FollowUpSchema = SchemaFactory.createForClass(FollowUp);

/** A Lead is someone enquiring about a plot, before they book. */
@Schema({ timestamps: true, collection: 'leads' })
export class Lead {
  @Prop({ type: String, required: true })
  name: string;

  @Prop({ type: String, required: true })
  mobile: string;

  /** The last 10 digits, to find the same person however the number was typed. */
  @Prop({ type: String, required: true, index: true })
  mobileKey: string;

  @Prop({ type: String, default: '' })
  email: string;

  @Prop({ type: String, default: '' })
  area: string;

  @Prop({ type: String, required: true, enum: LEAD_SOURCES })
  source: string;

  @Prop({ type: SchemaTypes.ObjectId, default: null })
  siteId: Types.ObjectId | null;

  @Prop({ type: String, default: '' })
  siteName: string;

  /** Plot only, or plot with a house built. */
  @Prop({ type: String, default: null, enum: [...BOOKING_TYPES, null] })
  interest: string | null;

  @Prop({ type: Number, default: null })
  budgetPaise: number | null;

  @Prop({ type: String, default: '' })
  notes: string;

  @Prop({ type: String, default: 'newLead', enum: LEAD_STATUSES })
  status: string;

  @Prop({ type: String, default: null, index: true })
  nextFollowUp: string | null;

  /** The Sales Executive looking after the lead. */
  @Prop({ type: SchemaTypes.ObjectId, required: true, index: true })
  ownerId: Types.ObjectId;

  @Prop({ type: String, required: true })
  ownerName: string;

  /** Set once the lead becomes a customer. */
  @Prop({ type: SchemaTypes.ObjectId, default: null })
  customerId: Types.ObjectId | null;

  @Prop({ type: Date, default: null })
  convertedAt: Date | null;

  @Prop({ type: [FollowUpSchema], default: [] })
  followUps: Types.DocumentArray<FollowUp & { _id: Types.ObjectId }>;
}
export type LeadDocument = HydratedDocument<Lead>;
export const LeadSchema = SchemaFactory.createForClass(Lead);
