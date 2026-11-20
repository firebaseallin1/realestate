import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { Booking, BookingSchema } from '../bookings/booking.schema.js';
import { FilesModule } from '../files/files.module.js';
import { User, UserSchema } from '../users/user.schema.js';
import {
  DailyWork,
  DailyWorkSchema,
  ExpensePayment,
  ExpensePaymentSchema,
  Material,
  MaterialBill,
  MaterialBillSchema,
  MaterialSchema,
  Project,
  ProjectSchema,
  Worker,
  WorkerSchema,
} from './project.schema.js';
import { ProjectsController } from './projects.controller.js';
import { ProjectsService } from './projects.service.js';

@Module({
  imports: [
    FilesModule,
    MongooseModule.forFeature([
      { name: Project.name, schema: ProjectSchema },
      { name: Worker.name, schema: WorkerSchema },
      { name: DailyWork.name, schema: DailyWorkSchema },
      { name: MaterialBill.name, schema: MaterialBillSchema },
      { name: Material.name, schema: MaterialSchema },
      { name: ExpensePayment.name, schema: ExpensePaymentSchema },
      { name: Booking.name, schema: BookingSchema },
      { name: User.name, schema: UserSchema },
    ]),
  ],
  controllers: [ProjectsController],
  providers: [ProjectsService],
  exports: [ProjectsService],
})
export class ProjectsModule {}
