import { Body, Controller, Get, Param, Patch, Post } from '@nestjs/common';
import { CurrentUser } from '../auth/current-user.decorator.js';
import { Roles } from '../auth/roles.decorator.js';
import { UserRole } from '../users/user.schema.js';
import type { UserDocument } from '../users/user.schema.js';
import {
  AddDailyWorkDto,
  AddExpensePaymentDto,
  AddMaterialBillDto,
  AddWorkerDto,
  AssignInchargeDto,
  SaveMaterialDto,
  UpdateStageDto,
} from './dto/project.dto.js';
import { ProjectsService } from './projects.service.js';

/**
 * Admins and Site Managers work on every house; a Site Incharge only on those
 * assigned to them, which the service checks. Sales have no access. Each change
 * returns the whole project, so the app always shows what was saved.
 */
@Controller('projects')
@Roles(UserRole.admin, UserRole.siteManager, UserRole.siteIncharge)
export class ProjectsController {
  constructor(private readonly projects: ProjectsService) {}

  @Get()
  async list(@CurrentUser() me: UserDocument) {
    return { items: await this.projects.list(me) };
  }

  @Patch(':id/incharge')
  @Roles(UserRole.admin, UserRole.siteManager)
  assign(@Param('id') id: string, @Body() dto: AssignInchargeDto, @CurrentUser() me: UserDocument) {
    return this.projects.assignIncharge(id, dto.inchargeId, me);
  }

  @Patch(':id/stages/:stageId')
  updateStage(
    @Param('id') id: string,
    @Param('stageId') stageId: string,
    @Body() dto: UpdateStageDto,
    @CurrentUser() me: UserDocument,
  ) {
    return this.projects.updateStage(id, stageId, dto, me);
  }

  @Post(':id/workers')
  addWorker(@Param('id') id: string, @Body() dto: AddWorkerDto, @CurrentUser() me: UserDocument) {
    return this.projects.addWorker(id, dto, me);
  }

  @Post(':id/daily-work')
  addDailyWork(@Param('id') id: string, @Body() dto: AddDailyWorkDto, @CurrentUser() me: UserDocument) {
    return this.projects.addDailyWork(id, dto, me);
  }

  @Post(':id/materials')
  addMaterial(@Param('id') id: string, @Body() dto: SaveMaterialDto, @CurrentUser() me: UserDocument) {
    return this.projects.addMaterial(id, dto, me);
  }

  @Patch(':id/materials/:materialId')
  updateMaterial(
    @Param('id') id: string,
    @Param('materialId') materialId: string,
    @Body() dto: SaveMaterialDto,
    @CurrentUser() me: UserDocument,
  ) {
    return this.projects.updateMaterial(id, materialId, dto, me);
  }

  @Post(':id/material-bills')
  addMaterialBill(@Param('id') id: string, @Body() dto: AddMaterialBillDto, @CurrentUser() me: UserDocument) {
    return this.projects.addMaterialBill(id, dto, me);
  }

  @Post(':id/expense-payments')
  addExpensePayment(@Param('id') id: string, @Body() dto: AddExpensePaymentDto, @CurrentUser() me: UserDocument) {
    return this.projects.addExpensePayment(id, dto, me);
  }
}
