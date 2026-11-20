import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsIn,
  IsInt,
  IsMongoId,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
  ValidateIf,
} from 'class-validator';
import { IsDay, trim } from '../../common/validators.js';
import { FOLLOW_UP_MODES, INTEREST_TYPES, LEAD_SOURCES, LEAD_STATUSES } from '../lead.schema.js';

/** A lead's basic details, for adding or editing one. */
export class SaveLeadDto {
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: "Please enter the person's name." })
  @MaxLength(150)
  name: string;

  @Transform(trim)
  @IsString()
  @Matches(/^(\+91)?[\s-]*(\d[\s-]*){10}$/, { message: 'Enter a 10-digit mobile number.' })
  mobile: string;

  @IsOptional()
  @Transform(trim)
  @ValidateIf((dto: SaveLeadDto) => !!dto.email)
  @IsEmail({}, { message: 'Enter a valid email, or leave it empty.' })
  @MaxLength(200)
  email?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(200)
  area?: string;

  @IsIn(LEAD_SOURCES)
  source: string;

  @IsOptional()
  @ValidateIf((dto: SaveLeadDto) => dto.siteId !== null)
  @IsMongoId()
  siteId?: string | null;

  @IsOptional()
  @ValidateIf((dto: SaveLeadDto) => dto.interest !== null)
  @IsIn(INTEREST_TYPES)
  interest?: string | null;

  @IsOptional()
  @ValidateIf((dto: SaveLeadDto) => dto.budgetPaise !== null)
  @IsInt()
  @Min(0)
  budgetPaise?: number | null;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(1000)
  notes?: string;

  /** When to call them next. */
  @IsOptional()
  @ValidateIf((dto: SaveLeadDto) => dto.nextFollowUp !== null)
  @IsDay()
  nextFollowUp?: string | null;
}

/** The customer's details, filled in from the lead and completed. */
export class ConvertLeadDto {
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: "Please enter the customer's name." })
  @MaxLength(150)
  name: string;

  @Transform(trim)
  @IsString()
  @Matches(/^(\+91)?[\s-]*(\d[\s-]*){10}$/, { message: 'Enter a 10-digit mobile number.' })
  mobile: string;

  @IsOptional()
  @Transform(trim)
  @ValidateIf((dto: ConvertLeadDto) => !!dto.alternateMobile)
  @Matches(/^(\+91)?[\s-]*(\d[\s-]*){10}$/, { message: 'Enter a 10-digit alternate number, or leave it empty.' })
  alternateMobile?: string;

  @IsOptional()
  @Transform(trim)
  @ValidateIf((dto: ConvertLeadDto) => !!dto.email)
  @IsEmail({}, { message: 'Enter a valid email, or leave it empty.' })
  @MaxLength(200)
  email?: string;

  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: "Please enter the customer's address." })
  @MaxLength(500)
  address: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(100)
  occupation?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(1000)
  notes?: string;
}

export class AddFollowUpDto {
  @IsDay()
  date: string;

  @IsIn(FOLLOW_UP_MODES)
  mode: string;

  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Please note what was discussed.' })
  @MaxLength(1000)
  note: string;

  @IsIn(LEAD_STATUSES)
  status: string;

  @IsOptional()
  @ValidateIf((dto: AddFollowUpDto) => dto.nextDate !== null)
  @IsDay()
  nextDate?: string | null;
}
