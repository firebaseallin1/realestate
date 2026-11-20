import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { SchemaTypes, Types } from 'mongoose';

/**
 * A long-lived sign-in, stored only as a hash. Each refresh replaces the
 * token; [familyId] links the chain from one sign-in, so a stolen token being
 * replayed can end that whole sign-in.
 */
@Schema({ timestamps: true, collection: 'refreshTokens' })
export class RefreshToken {
  @Prop({ type: SchemaTypes.ObjectId, required: true, index: true })
  userId: Types.ObjectId;

  @Prop({ type: String, required: true, index: true })
  familyId: string;

  @Prop({ type: String, required: true, unique: true })
  tokenHash: string;

  /** MongoDB deletes the record once this passes. */
  @Prop({ type: Date, required: true, expires: 0 })
  expiresAt: Date;

  @Prop({ type: Date, default: null })
  revokedAt: Date | null;
}

export const RefreshTokenSchema = SchemaFactory.createForClass(RefreshToken);
