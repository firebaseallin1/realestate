import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Booking, BookingSchema } from '../bookings/booking.schema.js';
import { FilesModule } from '../files/files.module.js';
import { Location, LocationSchema, Plot, PlotSchema, Site, SiteSchema } from './site.schema.js';
import { SitesController } from './sites.controller.js';
import { SitesService } from './sites.service.js';

@Module({
  imports: [
    FilesModule,
    MongooseModule.forFeature([
      { name: Site.name, schema: SiteSchema },
      { name: Plot.name, schema: PlotSchema },
      { name: Location.name, schema: LocationSchema },
      { name: Booking.name, schema: BookingSchema },
    ]),
  ],
  controllers: [SitesController],
  providers: [SitesService],
  exports: [SitesService],
})
export class SitesModule {}
