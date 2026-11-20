import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { isValidObjectId, Types } from 'mongoose';
import type { Connection, Model } from 'mongoose';
import { AppError } from '../common/app-error.js';
import { todayInIndia } from '../common/validators.js';
import { Customer, toCustomerJson } from '../customers/customer.schema.js';
import type { CustomerDocument } from '../customers/customer.schema.js';
import { Site } from '../sites/site.schema.js';
import { UserRole } from '../users/user.schema.js';
import type { UserDocument } from '../users/user.schema.js';
import { AddFollowUpDto, ConvertLeadDto, SaveLeadDto } from './dto/lead.dto.js';
import { CLOSED_STATUSES, Lead } from './lead.schema.js';
import type { LeadDocument } from './lead.schema.js';

const notFound = () => new AppError('NOT_FOUND', 'This lead no longer exists.', HttpStatus.NOT_FOUND);
const conflict = (code: string, message: string) => new AppError(code, message, HttpStatus.CONFLICT);

/** The last 10 digits: "+91 98480-12345" and "9848012345" are the same person. */
const mobileKey = (mobile: string) => mobile.replace(/\D/g, '').slice(-10);

/**
 * LeadsService keeps enquiries and their follow-ups. Sales Executives see
 * the leads they look after; Admins see every lead.
 */
@Injectable()
export class LeadsService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel(Lead.name) private readonly leads: Model<Lead>,
    @InjectModel(Site.name) private readonly sites: Model<Site>,
    @InjectModel(Customer.name) private readonly customers: Model<Customer>,
  ) {}

  async list(me: UserDocument) {
    const filter = me.role === UserRole.admin ? {} : { ownerId: me._id };
    const leads = await this.leads.find(filter).sort({ createdAt: -1 });
    return leads.map((lead) => this.toJson(lead));
  }

  async create(dto: SaveLeadDto, me: UserDocument) {
    const key = mobileKey(dto.mobile);
    await this.checkMobile(key);
    const lead = await this.leads.create({
      ...(await this.details(dto)),
      mobileKey: key,
      status: 'newLead',
      ownerId: me._id,
      ownerName: me.name,
    });
    return this.toJson(lead);
  }

  async update(id: string, dto: SaveLeadDto, me: UserDocument) {
    const lead = await this.find(id, me);
    const key = mobileKey(dto.mobile);
    await this.checkMobile(key, lead._id);
    lead.set({ ...(await this.details(dto)), mobileKey: key });
    // A closed lead has nothing to follow up.
    if (CLOSED_STATUSES.includes(lead.status)) lead.nextFollowUp = null;
    await lead.save();
    return this.toJson(lead);
  }

  /** Records a contact; the lead takes its status and next follow-up date. */
  async addFollowUp(id: string, dto: AddFollowUpDto, me: UserDocument) {
    const lead = await this.find(id, me);
    if (dto.date > todayInIndia()) throw conflict('FUTURE_DATE', 'A follow-up cannot be dated in the future.');
    const closed = CLOSED_STATUSES.includes(dto.status);
    const nextDate = closed ? null : (dto.nextDate ?? null);
    if (nextDate && nextDate < dto.date) {
      throw conflict('NEXT_BEFORE_DATE', 'The next follow-up must be on or after this one.');
    }

    lead.followUps.push({ ...dto, nextDate, byId: me._id, byName: me.name, addedAt: new Date() });
    lead.status = dto.status;
    lead.nextFollowUp = nextDate;
    await lead.save();
    return this.toJson(lead);
  }

  /**
   * Makes the lead a customer with the details given, together or not at
   * all. The lead is marked Won and needs no more follow-ups.
   */
  async convert(id: string, dto: ConvertLeadDto, me: UserDocument) {
    const lead = await this.find(id, me);
    if (lead.customerId) throw conflict('ALREADY_CONVERTED', `${lead.name} is already a customer.`);
    const key = mobileKey(dto.mobile);
    const existing = await this.customers.findOne({ mobileKey: key });
    if (existing) throw conflict('DUPLICATE_CUSTOMER', `${existing.name} is already a customer with this mobile number.`);

    let customer: CustomerDocument | undefined;
    try {
      await this.connection.transaction(async (session) => {
        [customer] = await this.customers.create(
          [{
            name: dto.name,
            mobile: dto.mobile,
            mobileKey: key,
            alternateMobile: dto.alternateMobile ?? '',
            email: dto.email ?? '',
            address: dto.address,
            occupation: dto.occupation ?? '',
            notes: dto.notes ?? '',
            leadId: lead._id,
            source: lead.source,
            ownerId: me._id,
            ownerName: me.name,
          }],
          { session },
        );
        lead.set({ customerId: customer._id, convertedAt: new Date(), status: 'won', nextFollowUp: null });
        await lead.save({ session });
      });
    } catch (error) {
      // Two conversions with the same number at once: the index keeps one.
      if ((error as { code?: number }).code === 11000) {
        throw conflict('DUPLICATE_CUSTOMER', 'Someone is already a customer with this mobile number.');
      }
      throw error;
    }
    return { lead: this.toJson(lead), customer: toCustomerJson(customer!) };
  }

  /** The same mobile number may belong to only one lead. */
  private async checkMobile(key: string, except?: Types.ObjectId) {
    const other = await this.leads.findOne({ mobileKey: key, ...(except ? { _id: { $ne: except } } : {}) });
    if (other) {
      throw conflict('DUPLICATE_LEAD', `${other.name} already has this mobile number, looked after by ${other.ownerName}.`);
    }
  }

  /** The basic details as stored, with the site's name looked up. */
  private async details(dto: SaveLeadDto) {
    let siteName = '';
    if (dto.siteId) {
      const site = await this.sites.findById(dto.siteId);
      if (!site) throw new AppError('NOT_FOUND', 'This site no longer exists.', HttpStatus.NOT_FOUND);
      siteName = site.name;
    }
    return {
      name: dto.name,
      mobile: dto.mobile,
      email: dto.email ?? '',
      area: dto.area ?? '',
      source: dto.source,
      siteId: dto.siteId ? new Types.ObjectId(dto.siteId) : null,
      siteName,
      interest: dto.interest ?? null,
      budgetPaise: dto.budgetPaise ?? null,
      notes: dto.notes ?? '',
      nextFollowUp: dto.nextFollowUp ?? null,
    };
  }

  /** Finds the lead, keeping a Sales Executive to their own. */
  private async find(id: string, me: UserDocument): Promise<LeadDocument> {
    const lead = isValidObjectId(id) ? await this.leads.findById(id) : null;
    if (!lead) throw notFound();
    if (me.role !== UserRole.admin && !lead.ownerId.equals(me._id)) {
      throw new AppError('FORBIDDEN', 'This lead is looked after by someone else.', HttpStatus.FORBIDDEN);
    }
    return lead;
  }

  private toJson(lead: LeadDocument) {
    const created = (lead as unknown as { createdAt?: Date }).createdAt ?? new Date();
    return {
      id: lead.id as string,
      name: lead.name,
      mobile: lead.mobile,
      email: lead.email,
      area: lead.area,
      source: lead.source,
      siteId: lead.siteId?.toString() ?? null,
      siteName: lead.siteName,
      interest: lead.interest,
      budgetPaise: lead.budgetPaise,
      notes: lead.notes,
      status: lead.status,
      nextFollowUp: lead.nextFollowUp,
      ownerId: lead.ownerId.toString(),
      ownerName: lead.ownerName,
      customerId: lead.customerId?.toString() ?? null,
      convertedAt: lead.convertedAt?.toISOString() ?? null,
      createdAt: created.toISOString(),
      followUps: lead.followUps.map((followUp) => ({
        id: followUp._id.toString(),
        date: followUp.date,
        mode: followUp.mode,
        note: followUp.note,
        status: followUp.status,
        nextDate: followUp.nextDate,
        by: followUp.byName,
        addedAt: followUp.addedAt.toISOString(),
      })),
    };
  }
}
