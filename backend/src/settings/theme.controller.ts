import { Body, Controller, Get, Put } from '@nestjs/common';
import { IsIn, IsOptional } from 'class-validator';
import { Public } from '../auth/public.decorator.js';
import { Roles } from '../auth/roles.decorator.js';
import { UserRole } from '../users/user.schema.js';
import { APP_FONTS, APP_THEMES, TEXT_SIZES } from './app-settings.schema.js';
import type { AppFont, AppTheme, TextSize } from './app-settings.schema.js';
import { SettingsService } from './settings.service.js';

/** Any of the three; parts left out stay as they are. */
export class SetAppearanceDto {
  @IsOptional()
  @IsIn(APP_THEMES, { message: 'Choose one of the listed themes.' })
  theme?: AppTheme;

  @IsOptional()
  @IsIn(APP_FONTS, { message: 'Choose one of the listed fonts.' })
  font?: AppFont;

  @IsOptional()
  @IsIn(TEXT_SIZES, { message: 'Choose one of the listed text sizes.' })
  textSize?: TextSize;
}

/** Settings > Theme and Text: how the app looks for everyone. */
@Controller('settings/theme')
export class ThemeController {
  constructor(private readonly settings: SettingsService) {}

  /** Open to all, so the sign-in screen looks the same. */
  @Public()
  @Get()
  async get() {
    return { ...(await this.settings.appearance()), themes: APP_THEMES, fonts: APP_FONTS, textSizes: TEXT_SIZES };
  }

  @Put()
  @Roles(UserRole.admin)
  async set(@Body() dto: SetAppearanceDto) {
    await this.settings.setAppearance({ theme: dto.theme, font: dto.font, textSize: dto.textSize });
    return this.get();
  }
}
