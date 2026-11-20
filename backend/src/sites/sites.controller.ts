import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, Put } from '@nestjs/common';
import { Roles } from '../auth/roles.decorator.js';
import { UserRole } from '../users/user.schema.js';
import { CreateLocationDto, SavePlotsDto, SaveSiteDto, SetLocationPointDto } from './dto/site.dto.js';
import { SitesService } from './sites.service.js';

/** Every role reads sites and locations; only Admins change them. */
@Controller()
export class SitesController {
  constructor(private readonly sites: SitesService) {}

  @Get('locations')
  async listLocations() {
    return { items: await this.sites.listLocations() };
  }

  @Post('locations')
  @Roles(UserRole.admin)
  addLocation(@Body() dto: CreateLocationDto) {
    return this.sites.addLocation(dto);
  }

  /** Sets or clears where a location is on the map. */
  @Patch('locations/:id')
  @Roles(UserRole.admin)
  setLocationPoint(@Param('id') id: string, @Body() dto: SetLocationPointDto) {
    return this.sites.setLocationPoint(id, dto);
  }

  @Get('sites')
  async listSites() {
    return { items: await this.sites.listSites() };
  }

  @Post('sites')
  @Roles(UserRole.admin)
  createSite(@Body() dto: SaveSiteDto) {
    return this.sites.createSite(dto);
  }

  @Patch('sites/:id')
  @Roles(UserRole.admin)
  updateSite(@Param('id') id: string, @Body() dto: SaveSiteDto) {
    return this.sites.updateSite(id, dto);
  }

  @Delete('sites/:id')
  @Roles(UserRole.admin)
  @HttpCode(204)
  async deleteSite(@Param('id') id: string) {
    await this.sites.deleteSite(id);
  }

  @Put('sites/:id/plots')
  @Roles(UserRole.admin)
  savePlots(@Param('id') id: string, @Body() dto: SavePlotsDto) {
    return this.sites.savePlots(id, dto);
  }
}
