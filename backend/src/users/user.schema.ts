import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import type { HydratedDocument } from 'mongoose';

/** Same names as the app's UserRole enum. */
export enum UserRole {
  admin = 'admin',
  salesExecutive = 'salesExecutive',
  siteManager = 'siteManager',
  siteIncharge = 'siteIncharge',
}

@Schema({ timestamps: true, collection: 'users' })
export class User {
  @Prop({ type: String, required: true, trim: true })
  name: string;

  /** Stored lowercase, so sign-in ignores case. */
  @Prop({ type: String, required: true, unique: true, lowercase: true, trim: true })
  username: string;

  /** Never returned by a query unless asked for. */
  @Prop({ type: String, required: true, select: false })
  passwordHash: string;

  @Prop({ type: String, required: true, enum: Object.values(UserRole) })
  role: UserRole;

  @Prop({ type: String, default: '', trim: true })
  phone: string;

  /** Removed users stay on record, as bookings and work updates refer to them. */
  @Prop({ type: Boolean, default: true })
  active: boolean;
}

export type UserDocument = HydratedDocument<User>;
export const UserSchema = SchemaFactory.createForClass(User);

/** What the API shows of a user: an explicit list, so secrets cannot leak. */
export function toPublicUser(user: UserDocument) {
  return {
    id: user.id as string,
    name: user.name,
    username: user.username,
    role: user.role,
    phone: user.phone,
  };
}
