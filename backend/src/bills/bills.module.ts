import { Module } from '@nestjs/common';
import { FilesModule } from '../files/files.module.js';
import { BillReaderService } from './bill-reader.service.js';
import { BillsController } from './bills.controller.js';

@Module({
  imports: [FilesModule],
  controllers: [BillsController],
  providers: [BillReaderService],
})
export class BillsModule {}
