import { Body, Controller, Get, HttpCode, Param, Patch, Post } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { Roles } from '../auth/roles.decorator.js';
import { UserRole } from '../users/user.schema.js';
import type { UserDocument } from '../users/user.schema.js';
import { AddFollowUpDto, ConvertLeadDto, SaveLeadDto } from './dto/lead.dto.js';
import { LeadsService } from './leads.service.js';

/** Sales Executives work their own leads; Admins see and work all of them. */
@Controller('leads')
@Roles(UserRole.admin, UserRole.salesExecutive)
export class LeadsController {
  constructor(private readonly leads: LeadsService) {}

  @Get()
  async list(@CurrentUser() me: UserDocument) {
    return { items: await this.leads.list(me) };
  }

  @Post()
  create(@Body() dto: SaveLeadDto, @CurrentUser() me: UserDocument) {
    return this.leads.create(dto, me);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: SaveLeadDto, @CurrentUser() me: UserDocument) {
    return this.leads.update(id, dto, me);
  }

  /** Makes the lead a customer; returns both. */
  @Post(':id/convert')
  @HttpCode(200)
  convert(@Param('id') id: string, @Body() dto: ConvertLeadDto, @CurrentUser() me: UserDocument) {
    return this.leads.convert(id, dto, me);
  }

  @Post(':id/follow-ups')
  addFollowUp(@Param('id') id: string, @Body() dto: AddFollowUpDto, @CurrentUser() me: UserDocument) {
    return this.leads.addFollowUp(id, dto, me);
  }
}
