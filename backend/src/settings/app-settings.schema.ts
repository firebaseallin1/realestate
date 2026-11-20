import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import type { HydratedDocument } from 'mongoose';

/** Where new uploads are kept: in MongoDB (GridFS) or in a folder on the server. */
export const FILE_STORAGES = ['database', 'folder'] as const;
export type FileStorage = (typeof FILE_STORAGES)[number];

/** The colour themes the app offers; everyone sees the one an Admin picks. */
export const APP_THEMES = ['sage', 'ocean', 'indigo', 'terracotta', 'graphite', 'plum'] as const;
export type AppTheme = (typeof APP_THEMES)[number];

/** The fonts and text sizes the app offers. */
export const APP_FONTS = ['josefin', 'poppins', 'serif', 'system'] as const;
export type AppFont = (typeof APP_FONTS)[number];
export const TEXT_SIZES = ['small', 'normal', 'large', 'extraLarge'] as const;
export type TextSize = (typeof TEXT_SIZES)[number];

/** How the app looks for everyone. */
export interface Appearance {
  theme: AppTheme;
  font: AppFont;
  textSize: TextSize;
}

/** App-wide settings that Admins change: one document, key "app". */
@Schema({ timestamps: true, collection: 'settings' })
export class AppSettings {
  @Prop({ type: String, required: true, unique: true, default: 'app' })
  key: string;

  @Prop({ type: String, enum: FILE_STORAGES, default: 'database' })
  fileStorage: FileStorage;

  @Prop({ type: String, enum: APP_THEMES, default: 'sage' })
  theme: AppTheme;

  @Prop({ type: String, enum: APP_FONTS, default: 'josefin' })
  font: AppFont;

  @Prop({ type: String, enum: TEXT_SIZES, default: 'normal' })
  textSize: TextSize;
}
export type AppSettingsDocument = HydratedDocument<AppSettings>;
export const AppSettingsSchema = SchemaFactory.createForClass(AppSettings);
