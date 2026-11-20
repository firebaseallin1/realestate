import { Body, Controller, Get, HttpCode, Param, Patch, Post } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { Roles } from '../auth/roles.decorator.js';
import { UserRole } from '../users/user.schema.js';
import type { UserDocument } from '../users/user.schema.js';
import { BookingsService } from './bookings.service.js';
import { AddPaymentDto, CreateBookingDto, UpdateBookingDto, UpdateLoanStatusDto } from './dto/booking.dto.js';

/** Sales raise bookings and record payments; only Admins decide on them. */
@Controller('bookings')
@Roles(UserRole.admin, UserRole.salesExecutive)
export class BookingsController {
  constructor(private readonly bookings: BookingsService) {}

  @Get()
  async list() {
    return { items: await this.bookings.list() };
  }

  @Post()
  create(@Body() dto: CreateBookingDto, @CurrentUser() me: UserDocument) {
    return this.bookings.create(dto, me);
  }

  @Post(':id/approve')
  @Roles(UserRole.admin)
  @HttpCode(200)
  approve(@Param('id') id: string) {
    return this.bookings.approve(id);
  }

  @Post(':id/reject')
  @Roles(UserRole.admin)
  @HttpCode(200)
  reject(@Param('id') id: string) {
    return this.bookings.reject(id);
  }

  /** Corrects an approved booking. */
  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateBookingDto) {
    return this.bookings.update(id, dto);
  }

  /** Sends a rejected booking, with corrections, back for approval. */
  @Post(':id/resubmit')
  @HttpCode(200)
  resubmit(@Param('id') id: string, @Body() dto: UpdateBookingDto) {
    return this.bookings.resubmit(id, dto);
  }

  @Patch(':id/loans/:part')
  updateLoanStatus(@Param('id') id: string, @Param('part') part: string, @Body() dto: UpdateLoanStatusDto) {
    return this.bookings.updateLoanStatus(id, part, dto);
  }

  @Post(':id/payments')
  addPayment(@Param('id') id: string, @Body() dto: AddPaymentDto, @CurrentUser() me: UserDocument) {
    return this.bookings.addPayment(id, dto, me);
  }
}
