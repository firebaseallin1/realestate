import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsIn,
  IsInt,
  IsMongoId,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { trim } from '../../common/validators.js';
import { PLOT_FACINGS, PLOT_STATUSES, SITE_STATUSES, SITE_TYPES } from '../site.schema.js';

export class CreateLocationDto {
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Please enter a location name.' })
  @MaxLength(100)
  name: string;

  @IsOptional()
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  latitude?: number;

  @IsOptional()
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  longitude?: number;
}

/** Sets a location's map point, or clears it when both are null. */
export class SetLocationPointDto {
  @IsOptional()
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  latitude?: number | null;

  @IsOptional()
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  longitude?: number | null;
}

export class SaveSiteDto {
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Please enter a site name.' })
  @MaxLength(150)
  name: string;

  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Please select a location.' })
  @MaxLength(100)
  location: string;

  @IsIn(SITE_TYPES)
  type: string;

  @IsIn(SITE_STATUSES)
  status: string;

  @IsInt()
  @Min(0)
  totalUnits: number;

  @IsInt()
  @Min(0)
  soldUnits: number;

  @IsInt()
  @Min(0)
  bookedUnits: number;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(150)
  ownerName?: string;

  @IsNumber()
  @Min(0)
  totalArea: number;

  @IsNumber()
  @Min(0)
  salesArea: number;

  @IsNumber()
  @Min(0)
  roadArea: number;

  @IsNumber()
  @Min(0)
  gardenArea: number;

  @IsNumber()
  @Min(0)
  otherArea: number;

  /** Null removes the file. */
  @IsOptional()
  @IsMongoId()
  siteMapFileId?: string | null;

  @IsOptional()
  @IsMongoId()
  brochureFileId?: string | null;
}

class PlotRectDto {
  @IsNumber()
  @Min(0)
  @Max(1)
  x: number;

  @IsNumber()
  @Min(0)
  @Max(1)
  y: number;

  @IsNumber()
  @Min(0)
  @Max(1)
  w: number;

  @IsNumber()
  @Min(0)
  @Max(1)
  h: number;
}

export class SavePlotDto {
  /** An existing plot's ID. Anything else, like the app's temporary IDs, adds a new plot. */
  @IsOptional()
  @IsString()
  id?: string;

  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Every plot needs a number.' })
  @MaxLength(30)
  number: string;

  @IsNumber()
  @Min(0.01)
  widthFt: number;

  @IsNumber()
  @Min(0.01)
  lengthFt: number;

  @IsIn(PLOT_FACINGS)
  facing: string;

  @IsIn(PLOT_STATUSES)
  status: 'available' | 'booked' | 'sold';

  @IsOptional()
  @IsInt()
  @Min(0)
  pricePaise?: number | null;

  @ValidateNested()
  @Type(() => PlotRectDto)
  rect: PlotRectDto;
}

export class SavePlotsDto {
  @IsArray()
  @ArrayMaxSize(5000)
  @ValidateNested({ each: true })
  @Type(() => SavePlotDto)
  plots: SavePlotDto[];
}
