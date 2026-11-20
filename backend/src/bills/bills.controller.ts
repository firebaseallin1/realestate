import { Body, Controller, HttpCode, Post } from '@nestjs/common';
import { IsMongoId } from 'class-validator';
import { Throttle } from '@nestjs/throttler';
import { Roles } from '../auth/roles.decorator.js';
import { UserRole } from '../users/user.schema.js';
import { BillReaderService } from './bill-reader.service.js';

export class ReadBillDto {
  @IsMongoId()
  fileId: string;
}

/** Construction staff read bills before saving their materials. */
@Controller('bills')
@Roles(UserRole.admin, UserRole.siteManager, UserRole.siteIncharge)
export class BillsController {
  constructor(private readonly reader: BillReaderService) {}

  /** Reads an uploaded bill; nothing is saved. Each read has a cost, so it is limited. */
  @Post('read')
  @HttpCode(200)
  @Throttle({ default: { ttl: 60_000, limit: 20 } })
  read(@Body() dto: ReadBillDto) {
    return this.reader.read(dto.fileId);
  }
}
