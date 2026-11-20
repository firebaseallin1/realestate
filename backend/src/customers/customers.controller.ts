import { Controller, Get } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import type { Model } from 'mongoose';
import { Roles } from '../auth/roles.decorator.js';
import { UserRole } from '../users/user.schema.js';
import { Customer, toCustomerJson } from './customer.schema.js';

/** Customers are read by everyone in sales, like the bookings they make. */
@Controller('customers')
@Roles(UserRole.admin, UserRole.salesExecutive)
export class CustomersController {
  constructor(@InjectModel(Customer.name) private readonly customers: Model<Customer>) {}

  @Get()
  async list() {
    const customers = await this.customers.find().sort({ createdAt: -1 });
    return { items: customers.map(toCustomerJson) };
  }
}
