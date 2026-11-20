import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, Query } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { Roles } from '../auth/roles.decorator.js';
import { CreateUserDto, ListUsersDto, UpdateUserDto } from './dto/user.dto.js';
import { toPublicUser, UserRole } from './user.schema.js';
import type { UserDocument } from './user.schema.js';
import { UsersService } from './users.service.js';

@Controller('users')
@Roles(UserRole.admin)
export class UsersController {
  constructor(private readonly users: UsersService) {}

  /** Site Managers see only Site Incharges, to assign them to houses. */
  @Get()
  @Roles(UserRole.admin, UserRole.siteManager)
  async list(@Query() query: ListUsersDto, @CurrentUser() me: UserDocument) {
    const role = me.role === UserRole.siteManager ? UserRole.siteIncharge : query.role;
    const { items, ...page } = await this.users.list({ ...query, role });
    return { items: items.map(toPublicUser), ...page };
  }

  @Post()
  async create(@Body() dto: CreateUserDto) {
    return toPublicUser(await this.users.create(dto));
  }

  @Patch(':id')
  async update(@Param('id') id: string, @Body() dto: UpdateUserDto, @CurrentUser() me: UserDocument) {
    return toPublicUser(await this.users.update(id, dto, me.id as string));
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(@Param('id') id: string, @CurrentUser() me: UserDocument) {
    await this.users.remove(id, me.id as string);
  }
}
