import { Transform, Type } from 'class-transformer';
import {
  IsBoolean,
  ArrayMaxSize,
  ArrayMinSize,
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
import { PAYMENT_METHODS } from '../../bookings/booking.schema.js';
import { IsDay, trim } from '../../common/validators.js';
import { EXPENSE_KINDS, STAGE_STATUSES, WORKER_TRADES } from '../project.schema.js';

export class AssignInchargeDto {
  /** Null removes the Site Incharge. */
  @IsOptional()
  @IsMongoId()
  inchargeId?: string | null;
}

export class UpdateStageDto {
  @IsIn(STAGE_STATUSES)
  status: string;

  @IsInt()
  @Min(0)
  @Max(100)
  progress: number;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(500)
  note?: string;
}

export class AddWorkerDto {
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: "Please enter the worker's name." })
  @MaxLength(100)
  name: string;

  @IsIn(WORKER_TRADES)
  trade: string;

  @IsInt()
  @Min(1, { message: 'Enter the daily wage.' })
  dailyWagePaise: number;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(30)
  phone?: string;
}

export class AddDailyWorkDto {
  @IsDay()
  date: string;

  @IsMongoId()
  stageId: string;

  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Please describe the work done.' })
  @MaxLength(1000)
  description: string;

  @IsArray()
  @ArrayMinSize(1, { message: 'Select the workers present.' })
  @IsMongoId({ each: true })
  workerIds: string[];
}

export class SaveMaterialDto {
  @IsDay()
  date: string;

  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Please enter the material.' })
  @MaxLength(200)
  name: string;

  @IsNumber()
  @Min(0.001, { message: 'Enter quantity.' })
  quantity: number;

  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  unit: string;

  @IsInt()
  @Min(1, { message: 'Enter the rate.' })
  ratePaise: number;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(150)
  supplier?: string;
}

class BillItemDto {
  @Transform(trim)
  @IsString()
  @IsNotEmpty({ message: 'Please enter the material.' })
  @MaxLength(200)
  name: string;

  @IsNumber()
  @Min(0.001, { message: 'Add the quantity and rate for every item.' })
  quantity: number;

  @Transform(trim)
  @IsString()
  @IsNotEmpty()
  @MaxLength(20)
  unit: string;

  @IsInt()
  @Min(1, { message: 'Add the quantity and rate for every item.' })
  ratePaise: number;
}

export class AddMaterialBillDto {
  @IsMongoId()
  fileId: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(150)
  supplier?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MaxLength(50)
  billNumber?: string;

  @IsDay()
  date: string;

  /** Saves it even though it looks like a bill scanned before. */
  @IsOptional()
  @IsBoolean()
  allowDuplicate?: boolean;

  @IsArray()
  @ArrayMinSize(1, { message: 'Add at least one item from this bill.' })
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => BillItemDto)
  items: BillItemDto[];
}

export class AddExpensePaymentDto {
  @IsIn(EXPENSE_KINDS)
  kind: string;

  @IsMongoId()
  targetId: string;

  @IsInt()
  @Min(1, { message: 'Enter the amount paid.' })
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
