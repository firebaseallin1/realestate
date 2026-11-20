import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { AppSettings, AppSettingsSchema } from './app-settings.schema.js';
import { SettingsService } from './settings.service.js';
import { ThemeController } from './theme.controller.js';

@Module({
  imports: [MongooseModule.forFeature([{ name: AppSettings.name, schema: AppSettingsSchema }])],
  controllers: [ThemeController],
  providers: [SettingsService],
  exports: [SettingsService],
})
export class SettingsModule {}
