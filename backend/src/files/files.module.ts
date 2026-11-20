import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { SettingsModule } from '../settings/settings.module.js';
import { StoredFile, StoredFileSchema } from './file.schema.js';
import { FileStorageController } from './file-storage.controller.js';
import { FilesController } from './files.controller.js';
import { FilesService } from './files.service.js';
import { StorageService } from './storage.service.js';

@Module({
  imports: [SettingsModule, MongooseModule.forFeature([{ name: StoredFile.name, schema: StoredFileSchema }])],
  controllers: [FilesController, FileStorageController],
  providers: [FilesService, StorageService],
  exports: [FilesService],
})
export class FilesModule {}
