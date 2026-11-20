import { Body, Controller, Get, HttpCode, Post, Put } from '@nestjs/common';
import { IsIn } from 'class-validator';
import { Roles } from '../auth/roles.decorator.js';
import { FILE_STORAGES } from '../settings/app-settings.schema.js';
import type { FileStorage } from '../settings/app-settings.schema.js';
import { SettingsService } from '../settings/settings.service.js';
import { UserRole } from '../users/user.schema.js';
import { FilesService } from './files.service.js';

export class SetFileStorageDto {
  @IsIn(FILE_STORAGES, { message: 'Choose database or folder.' })
  storage: FileStorage;
}

/** Settings > File Storage, for Admins: where new uploads go, and moving old ones. */
@Controller('settings/file-storage')
@Roles(UserRole.admin)
export class FileStorageController {
  constructor(
    private readonly settings: SettingsService,
    private readonly files: FilesService,
  ) {}

  @Get()
  async get() {
    return { storage: await this.settings.fileStorage(), ...(await this.files.storageSummary()) };
  }

  /** New uploads go here; files already saved stay where they are. */
  @Put()
  async set(@Body() dto: SetFileStorageDto) {
    await this.settings.setFileStorage(dto.storage);
    return this.get();
  }

  /** Moves every file saved elsewhere into the chosen storage. */
  @Post('move')
  @HttpCode(200)
  async move() {
    const result = await this.files.moveAll(await this.settings.fileStorage());
    return { ...result, ...(await this.get()) };
  }
}
