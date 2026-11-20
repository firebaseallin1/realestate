import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { isValidObjectId, Types } from 'mongoose';
import type { ClientSession, Connection, Model } from 'mongoose';
import { Booking } from '../bookings/booking.schema.js';
import { AppError } from '../common/app-error.js';
import { toFileJson } from '../files/file.schema.js';
import { FilesService } from '../files/files.service.js';
import { CreateLocationDto, SaveSiteDto, SavePlotsDto, SetLocationPointDto } from './dto/site.dto.js';
import { Location, Plot, Site } from './site.schema.js';
import type { PlotDocument, PlotStatus, SiteDocument } from './site.schema.js';

const notFound = () => new AppError('SITE_NOT_FOUND', 'This site no longer exists.', HttpStatus.NOT_FOUND);
const conflict = (code: string, message: string) => new AppError(code, message, HttpStatus.CONFLICT);

@Injectable()
export class SitesService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel(Site.name) private readonly sites: Model<Site>,
    @InjectModel(Plot.name) private readonly plots: Model<Plot>,
    @InjectModel(Location.name) private readonly locations: Model<Location>,
    @InjectModel(Booking.name) private readonly bookings: Model<Booking>,
    private readonly files: FilesService,
  ) {}

  // Locations

  async listLocations() {
    const locations = await this.locations.find().sort({ name: 1 });
    return locations.map((location) => this.toLocationJson(location));
  }

  async addLocation(dto: CreateLocationDto) {
    const { name } = dto;
    const point = this.checkPoint(dto.latitude, dto.longitude);
    const nameKey = name.toLowerCase();
    if (await this.locations.exists({ nameKey })) {
      throw conflict('LOCATION_EXISTS', `${name} is already a location.`);
    }
    const location = await this.locations.create({ name, nameKey, ...point });
    return this.toLocationJson(location);
  }

  /** Sets a location's map point, or clears it when both are null. */
  async setLocationPoint(id: string, dto: SetLocationPointDto) {
    const missing = () =>
      new AppError('LOCATION_NOT_FOUND', 'This location no longer exists.', HttpStatus.NOT_FOUND);
    if (!isValidObjectId(id)) throw missing();
    const point = this.checkPoint(dto.latitude, dto.longitude);
    const location = await this.locations.findByIdAndUpdate(
      id,
      point ? { $set: point } : { $unset: { latitude: 1, longitude: 1 } },
      { returnDocument: 'after' },
    );
    if (!location) throw missing();
    return this.toLocationJson(location);
  }

  /** A map point needs both halves; neither means no point. */
  private checkPoint(latitude?: number | null, longitude?: number | null) {
    if ((latitude == null) !== (longitude == null)) {
      throw new AppError('INCOMPLETE_POINT', 'A map point needs both latitude and longitude.', HttpStatus.BAD_REQUEST);
    }
    return latitude == null || longitude == null ? null : { latitude, longitude };
  }

  private toLocationJson(location: { _id: unknown; name: string; latitude?: number; longitude?: number }) {
    return {
      id: String(location._id),
      name: location.name,
      latitude: location.latitude ?? null,
      longitude: location.longitude ?? null,
    };
  }

  /** The stored spelling of [name], adding it if it is new. */
  private async ensureLocation(name: string, session?: ClientSession): Promise<string> {
    const location = await this.locations.findOneAndUpdate(
      { nameKey: name.toLowerCase() },
      { $setOnInsert: { name, nameKey: name.toLowerCase() } },
      { upsert: true, returnDocument: 'after', session },
    );
    return location.name;
  }

  // Sites

  async listSites() {
    const [sites, plots] = await Promise.all([
      this.sites.find().sort({ createdAt: 1 }),
      this.plots.find().sort({ createdAt: 1 }),
    ]);
    return this.toJson(sites, plots);
  }

  async getSite(id: string) {
    const site = await this.findSite(id);
    const plots = await this.plots.find({ siteId: site._id }).sort({ createdAt: 1 });
    return (await this.toJson([site], plots))[0];
  }

  async createSite(dto: SaveSiteDto) {
    this.validate(dto);
    const site = await this.connection.transaction(async (session) => {
      const location = await this.ensureLocation(dto.location, session);
      const [created] = await this.sites.create([{ ...this.fields(dto), location }], { session });
      return created;
    });
    return this.getSite(site.id as string);
  }

  async updateSite(id: string, dto: SaveSiteDto) {
    const site = await this.findSite(id);
    const hasLayout = (await this.plots.countDocuments({ siteId: site._id })) > 0;
    // A drawn layout owns the unit counts.
    this.validate(hasLayout ? { ...dto, soldUnits: 0, bookedUnits: 0 } : dto);

    await this.connection.transaction(async (session) => {
      const location = await this.ensureLocation(dto.location, session);
      const { totalUnits, soldUnits, bookedUnits, ...others } = this.fields(dto);
      site.set({ ...others, location, ...(hasLayout ? {} : { totalUnits, soldUnits, bookedUnits }) });
      await site.save({ session });
    });
    return this.getSite(id);
  }

  /** History depends on the site, so it cannot go once it has bookings. */
  async deleteSite(id: string): Promise<void> {
    const site = await this.findSite(id);
    if (await this.bookings.exists({ siteId: site._id })) {
      throw conflict('SITE_HAS_BOOKINGS', `${site.name} has bookings, so it cannot be deleted.`);
    }
    await this.connection.transaction(async (session) => {
      await this.plots.deleteMany({ siteId: site._id }, { session });
      await this.sites.deleteOne({ _id: site._id }, { session });
    });
  }

  // Plots

  /** Replaces the site's layout with [dto], keeping what bookings depend on. */
  async savePlots(id: string, dto: SavePlotsDto) {
    const numbers = dto.plots.map((plot) => plot.number.toLowerCase());
    const repeated = numbers.find((number, i) => numbers.indexOf(number) !== i);
    if (repeated) throw conflict('PLOT_NUMBER_TAKEN', `Plot ${repeated} appears twice.`);

    await this.connection.transaction(async (session) => {
      const site = await this.sites.findById(id).session(session);
      if (!site) throw notFound();

      const existing = await this.plots.find({ siteId: site._id }).session(session);
      const held = await this.bookings.distinct('plotId', { siteId: site._id, live: true, plotId: { $ne: null } }).session(session);
      const heldIds = new Set(held.map(String));
      const keptIds = new Set(dto.plots.map((plot) => plot.id).filter((plotId) => plotId && isValidObjectId(plotId)));

      for (const plot of existing) {
        if (heldIds.has(plot.id as string) && !keptIds.has(plot.id as string)) {
          throw conflict('PLOT_HAS_BOOKING', `Plot ${plot.number} has a booking, so it cannot be deleted.`);
        }
      }
      await this.plots.deleteMany({ siteId: site._id, _id: { $nin: [...keptIds] } }, { session });

      const byId = new Map(existing.map((plot) => [plot.id as string, plot]));
      for (const { id: plotId, pricePaise, ...fields } of dto.plots) {
        const current = plotId ? byId.get(plotId) : undefined;
        if (!current) {
          await this.plots.create([{ ...fields, pricePaise: pricePaise ?? null, siteId: site._id }], { session });
          continue;
        }
        const isHeld = heldIds.has(current.id as string);
        if (isHeld && current.number !== fields.number) {
          throw conflict('PLOT_HAS_BOOKING', `Plot ${current.number} has a booking, so its number cannot change.`);
        }
        // A booked plot's status follows its booking, not a possibly stale screen.
        current.set({ ...fields, pricePaise: pricePaise ?? null, status: isHeld ? current.status : fields.status });
        await current.save({ session });
      }
      await this.recount(site, session);
    });
    return this.getSite(id);
  }

  /**
   * Moves a booking's unit between statuses: the drawn plot when it has one,
   * otherwise the site's booked and sold counts. Runs inside the caller's
   * transaction, so a booking and its unit always change together.
   */
  async moveUnit(
    siteId: Types.ObjectId,
    plotId: Types.ObjectId | null,
    from: PlotStatus,
    to: PlotStatus,
    session: ClientSession,
  ): Promise<void> {
    if (from === to) return;
    const site = await this.sites.findById(siteId).session(session);
    if (!site) return;

    const hasLayout = (await this.plots.countDocuments({ siteId }).session(session)) > 0;
    if (hasLayout && plotId) {
      await this.plots.updateOne({ _id: plotId, siteId }, { status: to }, { session });
      await this.recount(site, session);
      return;
    }
    const delta = (status: PlotStatus) => (to === status ? 1 : 0) - (from === status ? 1 : 0);
    const clamp = (value: number) => Math.min(Math.max(value, 0), site.totalUnits);
    site.bookedUnits = clamp(site.bookedUnits + delta('booked'));
    site.soldUnits = clamp(site.soldUnits + delta('sold'));
    await site.save({ session });
  }

  async findSite(id: string): Promise<SiteDocument> {
    const site = isValidObjectId(id) ? await this.sites.findById(id) : null;
    if (!site) throw notFound();
    return site;
  }

  findPlot(siteId: Types.ObjectId, plotId: string, session: ClientSession) {
    return this.plots.findOne({ _id: plotId, siteId }).session(session);
  }

  /** The plots drawn on the layout decide the site's unit counts. */
  private async recount(site: SiteDocument, session: ClientSession): Promise<void> {
    const plots = await this.plots.find({ siteId: site._id }).session(session);
    if (plots.length === 0) return;
    site.totalUnits = plots.length;
    site.soldUnits = plots.filter((plot) => plot.status === 'sold').length;
    site.bookedUnits = plots.filter((plot) => plot.status === 'booked').length;
    await site.save({ session });
  }

  private validate(dto: SaveSiteDto): void {
    if (dto.soldUnits + dto.bookedUnits > dto.totalUnits) {
      throw new AppError('TOO_FEW_UNITS', 'Sold and booked units cannot exceed the total.', HttpStatus.BAD_REQUEST);
    }
    const allocated = dto.salesArea + dto.roadArea + dto.gardenArea + dto.otherArea;
    if (allocated - dto.totalArea > 0.005) {
      throw new AppError('AREA_TOO_LARGE', 'The areas add up to more than the total area.', HttpStatus.BAD_REQUEST);
    }
  }

  private fields(dto: SaveSiteDto) {
    const toId = (id?: string | null) => (id ? new Types.ObjectId(id) : null);
    return {
      name: dto.name,
      type: dto.type,
      status: dto.status,
      totalUnits: dto.totalUnits,
      soldUnits: dto.soldUnits,
      bookedUnits: dto.bookedUnits,
      ownerName: dto.ownerName ?? '',
      totalArea: dto.totalArea,
      salesArea: dto.salesArea,
      roadArea: dto.roadArea,
      gardenArea: dto.gardenArea,
      otherArea: dto.otherArea,
      siteMapFileId: toId(dto.siteMapFileId),
      brochureFileId: toId(dto.brochureFileId),
    };
  }

  private async toJson(sites: SiteDocument[], plots: PlotDocument[]) {
    const fileIds = sites.flatMap((site) => [site.siteMapFileId, site.brochureFileId]).filter((id) => id !== null);
    const files = await this.files.findMany(fileIds);
    const fileJson = (id: Types.ObjectId | null) => {
      const file = id ? files.get(id.toString()) : undefined;
      return file ? toFileJson(file) : null;
    };

    return sites.map((site) => ({
      id: site.id as string,
      name: site.name,
      location: site.location,
      type: site.type,
      status: site.status,
      totalUnits: site.totalUnits,
      soldUnits: site.soldUnits,
      bookedUnits: site.bookedUnits,
      ownerName: site.ownerName,
      totalArea: site.totalArea,
      salesArea: site.salesArea,
      roadArea: site.roadArea,
      gardenArea: site.gardenArea,
      otherArea: site.otherArea,
      siteMap: fileJson(site.siteMapFileId),
      brochure: fileJson(site.brochureFileId),
      plots: plots
        .filter((plot) => plot.siteId.equals(site._id))
        .map((plot) => ({
          id: plot.id as string,
          number: plot.number,
          widthFt: plot.widthFt,
          lengthFt: plot.lengthFt,
          facing: plot.facing,
          status: plot.status,
          pricePaise: plot.pricePaise,
          rect: plot.rect,
        })),
    }));
  }
}
