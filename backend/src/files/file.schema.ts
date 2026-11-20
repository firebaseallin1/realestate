import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { SchemaTypes, Types } from 'mongoose';
import type { HydratedDocument } from 'mongoose';

/** The details of an uploaded file. The bytes live in storage, not MongoDB. */
@Schema({ timestamps: true, collection: 'files' })
export class StoredFile {
  @Prop({ type: String, required: true })
  storageKey: string;

  @Prop({ type: String, required: true })
  name: string;

  @Prop({ type: String, required: true })
  contentType: string;

  @Prop({ type: Number, required: true })
  size: number;

  @Prop({ type: SchemaTypes.ObjectId, required: true })
  uploadedBy: Types.ObjectId;

  /** SHA-256 of the bytes, to spot the same file uploaded again. */
  @Prop({ type: String, default: '' })
  sha256: string;
}

export type StoredFileDocument = HydratedDocument<StoredFile>;
export const StoredFileSchema = SchemaFactory.createForClass(StoredFile);

export function toFileJson(file: StoredFileDocument) {
  return { id: file.id as string, name: file.name, contentType: file.contentType, size: file.size, sha256: file.sha256 ?? '' };
}
