import { Transform, Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsIn,
  IsInt,
  IsMongoId,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  Min,
  ValidateNested,
} from 'class-validator';
import { IsDay, trim } from '../../common/validators.js';
import { PLOT_FACINGS } from '../../sites/site.schema.js';
import {
  BOOKING_TYPES,
  LOAN_STATUSES,
  MANUAL_LOAN_STATUSES,
  PAYMENT_METHODS,
  PAYMENT_MODES,
  PAYMENT_PARTS,
} from '../booking.schema.js';

class CustomerDto {
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
  @IsString()
  @MaxLength(200)
  email?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(500)
  address?: string;
}

class LoanDto {
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Please enter the bank name.' })
  @MaxLength(100)
  bankName: string;

  @IsInt()
  @Min(1)
  amountPaise: number;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(100)
  reference?: string;

  @IsIn(LOAN_STATUSES)
  status: string;
}

class PlanDto {
  @IsIn(PAYMENT_PARTS)
  part: string;

  @IsInt()
  @Min(1, { message: 'Enter the value of each part.' })
  valuePaise: number;

  @IsIn(PAYMENT_MODES)
  mode: string;

  @IsOptional()
  @ValidateNested()
  @Type(() => LoanDto)
  loan?: LoanDto | null;
}

export class CreateBookingDto {
  @IsMongoId()
  siteId: string;

  /** Set when the plot was picked from the site's drawn layout. */
  @IsOptional()
  @IsString()
  plotId?: string | null;

  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Please enter the plot number.' })
  @MaxLength(30)
  plotNumber: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(50)
  plotSize?: string | null;

  @IsOptional()
  @IsIn(PLOT_FACINGS)
  facing?: string | null;

  @ValidateNested()
  @Type(() => CustomerDto)
  customer: CustomerDto;

  @IsIn(BOOKING_TYPES)
  type: string;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(2)
  @ValidateNested({ each: true })
  @Type(() => PlanDto)
  plans: PlanDto[];

  /**
   * What the customer paid at booking, by purpose (plot or construction).
   * Saved with the booking, so a booking never exists without them.
   */
  @IsOptional()
  @IsArray()
  @ArrayMaxSize(2)
  @ValidateNested({ each: true })
  @Type(() => AddPaymentDto)
  initialPayments?: AddPaymentDto[];
}

export class AddPaymentDto {
  @IsIn(PAYMENT_PARTS)
  part: string;

  @IsInt()
  @Min(1, { message: 'Enter the amount received.' })
  amountPaise: number;

  @IsDay()
  date: string;

  @IsIn(PAYMENT_METHODS)
  method: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(100)
  reference?: string;
}

export class UpdateLoanStatusDto {
  @IsIn(MANUAL_LOAN_STATUSES, { message: 'A loan can be marked Applied or Sanctioned; disbursements set the rest.' })
  status: string;
}

/** Corrects an approved booking: its customer and its payment plans. */
export class UpdateBookingDto {
  @ValidateNested()
  @Type(() => CustomerDto)
  customer: CustomerDto;

  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(2)
  @ValidateNested({ each: true })
  @Type(() => PlanDto)
  plans: PlanDto[];
}
