import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { CustomersModule } from '../customers/customers.module.js';
import { Site, SiteSchema } from '../sites/site.schema.js';
import { Lead, LeadSchema } from './lead.schema.js';
import { LeadsController } from './leads.controller.js';
import { LeadsService } from './leads.service.js';

@Module({
  imports: [
    CustomersModule,
    MongooseModule.forFeature([
      { name: Lead.name, schema: LeadSchema },
      { name: Site.name, schema: SiteSchema },
    ]),
  ],
  controllers: [LeadsController],
  providers: [LeadsService],
})
export class LeadsModule {}
