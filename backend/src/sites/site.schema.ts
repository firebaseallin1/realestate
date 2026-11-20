import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { SchemaTypes, Types } from 'mongoose';
import type { HydratedDocument } from 'mongoose';

// Same names as the app's enums.
export const SITE_TYPES = ['plots', 'apartments', 'villas', 'commercial'];
export const SITE_STATUSES = ['upcoming', 'active', 'completed'];
export const PLOT_FACINGS = ['north', 'northEast', 'east', 'southEast', 'south', 'southWest', 'west', 'northWest'];
export const PLOT_STATUSES = ['available', 'booked', 'sold'];

export type PlotStatus = 'available' | 'booked' | 'sold';

@Schema({ timestamps: true, collection: 'locations' })
export class Location {
  @Prop({ type: String, required: true, trim: true })
  name: string;

  /** Lowercase, so "hyderabad" and "Hyderabad" stay one location. */
  @Prop({ type: String, required: true, unique: true })
  nameKey: string;

  /** Where it is on the map, when picked. Both or neither. */
  @Prop({ type: Number, min: -90, max: 90 })
  latitude?: number;

  @Prop({ type: Number, min: -180, max: 180 })
  longitude?: number;
}
export const LocationSchema = SchemaFactory.createForClass(Location);

@Schema({ timestamps: true, collection: 'sites' })
export class Site {
  @Prop({ type: String, required: true, trim: true })
  name: string;

  @Prop({ type: String, required: true, index: true })
  location: string;

  @Prop({ type: String, required: true, enum: SITE_TYPES })
  type: string;

  @Prop({ type: String, required: true, enum: SITE_STATUSES })
  status: string;

  @Prop({ type: Number, required: true, min: 0 })
  totalUnits: number;

  @Prop({ type: Number, default: 0, min: 0 })
  soldUnits: number;

  @Prop({ type: Number, default: 0, min: 0 })
  bookedUnits: number;

  @Prop({ type: String, default: '' })
  ownerName: string;

  @Prop({ type: Number, default: 0 })
  totalArea: number;

  @Prop({ type: Number, default: 0 })
  salesArea: number;

  @Prop({ type: Number, default: 0 })
  roadArea: number;

  @Prop({ type: Number, default: 0 })
  gardenArea: number;

  @Prop({ type: Number, default: 0 })
  otherArea: number;

  @Prop({ type: SchemaTypes.ObjectId, default: null })
  siteMapFileId: Types.ObjectId | null;

  @Prop({ type: SchemaTypes.ObjectId, default: null })
  brochureFileId: Types.ObjectId | null;
}
export type SiteDocument = HydratedDocument<Site>;
export const SiteSchema = SchemaFactory.createForClass(Site);

/** Separate from the site, so a booking changing one plot's status cannot be overwritten by a layout save. */
@Schema({ timestamps: true, collection: 'plots' })
export class Plot {
  @Prop({ type: SchemaTypes.ObjectId, required: true, index: true })
  siteId: Types.ObjectId;

  @Prop({ type: String, required: true })
  number: string;

  @Prop({ type: Number, required: true })
  widthFt: number;

  @Prop({ type: Number, required: true })
  lengthFt: number;

  @Prop({ type: String, required: true, enum: PLOT_FACINGS })
  facing: string;

  @Prop({ type: String, required: true, enum: PLOT_STATUSES })
  status: PlotStatus;

  @Prop({ type: Number, default: null })
  pricePaise: number | null;

  /** Where it sits on the layout, in fractions of the layout's size. */
  @Prop({ type: { x: Number, y: Number, w: Number, h: Number }, required: true, _id: false })
  rect: { x: number; y: number; w: number; h: number };
}
export type PlotDocument = HydratedDocument<Plot>;
export const PlotSchema = SchemaFactory.createForClass(Plot);
