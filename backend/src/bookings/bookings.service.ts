import { HttpStatus, Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { isValidObjectId, Types } from 'mongoose';
import type { ClientSession, Connection, Model } from 'mongoose';
import { AppError } from '../common/app-error.js';
import { todayInIndia } from '../common/validators.js';
import { ProjectsService } from '../projects/projects.service.js';
import { SitesService } from '../sites/sites.service.js';
import type { PlotStatus } from '../sites/site.schema.js';
import type { UserDocument } from '../users/user.schema.js';
import { Booking, Payment } from './booking.schema.js';
import type { BookingDocument, PaymentDocument } from './booking.schema.js';
import { AddPaymentDto, CreateBookingDto, UpdateBookingDto, UpdateLoanStatusDto } from './dto/booking.dto.js';
import { MANUAL_LOAN_STATUSES } from './booking.schema.js';

const notFound = () => new AppError('BOOKING_NOT_FOUND', 'This booking no longer exists.', HttpStatus.NOT_FOUND);
const conflict = (code: string, message: string) => new AppError(code, message, HttpStatus.CONFLICT);
const partLabel = (part: string) => (part === 'plot' ? 'plot value' : 'construction value');
const rupees = (paise: number) => `₹${(paise / 100).toLocaleString('en-IN')}`;

const totalValue = (booking: BookingDocument) => booking.plans.reduce((sum, plan) => sum + plan.valuePaise, 0);
const isFullyPaid = (booking: BookingDocument) => totalValue(booking) > 0 && booking.totalPaidPaise >= totalValue(booking);

@Injectable()
export class BookingsService {
  constructor(
    @InjectConnection() private readonly connection: Connection,
    @InjectModel(Booking.name) private readonly bookings: Model<Booking>,
    @InjectModel(Payment.name) private readonly payments: Model<Payment>,
    private readonly sites: SitesService,
    private readonly projects: ProjectsService,
  ) {}

  async list() {
    const [bookings, payments] = await Promise.all([
      this.bookings.find().sort({ createdAt: 1 }),
      this.payments.find().sort({ date: 1, createdAt: 1 }),
    ]);
    return bookings.map((booking) => this.toJson(booking, payments));
  }

  async get(id: string) {
    const booking = isValidObjectId(id) ? await this.bookings.findById(id) : null;
    if (!booking) throw notFound();
    return this.toJson(booking, await this.payments.find({ bookingId: booking._id }).sort({ date: 1, createdAt: 1 }));
  }

  /** Creates the booking and marks its unit booked, together or not at all. */
  async create(dto: CreateBookingDto, me: UserDocument) {
    const site = await this.sites.findSite(dto.siteId);
    if (site.status === 'completed') {
      throw conflict('SITE_COMPLETED', `${site.name} is completed, so it has nothing left to book.`);
    }
    this.validatePlans(dto);
    for (const plan of dto.plans) {
      if (plan.loan && !MANUAL_LOAN_STATUSES.includes(plan.loan.status)) {
        throw new AppError('INVALID_PLANS', 'A new loan is Applied or Sanctioned.', HttpStatus.BAD_REQUEST);
      }
    }

    try {
      const booking = await this.connection.transaction(async (session) => {
        const plot = dto.plotId && isValidObjectId(dto.plotId) ? await this.sites.findPlot(site._id, dto.plotId, session) : null;
        if (dto.plotId && !plot) throw conflict('PLOT_NOT_FOUND', 'This plot is no longer on the layout.');
        if (plot && plot.status !== 'available') throw conflict('PLOT_TAKEN', `Plot ${plot.number} is already booked.`);

        const plotNumber = plot?.number ?? dto.plotNumber;
        const [created] = await this.bookings.create(
          [
            {
              siteId: site._id,
              siteName: site.name,
              plotId: plot?._id ?? null,
              plotNumber,
              plotKey: plotNumber.trim().toLowerCase(),
              plotSize: dto.plotSize ?? null,
              facing: plot?.facing ?? dto.facing ?? null,
              customer: dto.customer,
              type: dto.type,
              plans: dto.plans.map((plan) => ({ ...plan, loan: plan.mode === 'loan' ? plan.loan : null })),
              bookedOn: todayInIndia(),
              bookedById: me._id,
              bookedByName: me.name,
            },
          ],
          { session },
        );
        await this.sites.moveUnit(site._id, created.plotId, 'available', 'booked', session);

        const paid = dto.initialPayments ?? [];
        if (paid.length > 0) {
          await this.payments.create(
            paid.map((payment) => ({
              ...payment,
              reference: payment.reference ?? '',
              bookingId: created._id,
              createdBy: me._id,
            })),
            { session, ordered: true },
          );
          created.totalPaidPaise = paid.reduce((sum, payment) => sum + payment.amountPaise, 0);
          await created.save({ session });
        }
        return created;
      });
      return this.get(booking.id as string);
    } catch (error) {
      if ((error as { code?: number })?.code === 11000) {
        throw conflict('PLOT_TAKEN', `Plot ${dto.plotNumber} is already booked.`);
      }
      throw error;
    }
  }

  async approve(id: string) {
    await this.connection.transaction(async (session) => {
      const booking = await this.findPending(id, session);
      booking.status = 'approved';
      await booking.save({ session });
      if (isFullyPaid(booking)) await this.moveUnit(booking, 'booked', 'sold', session);
      if (booking.type === 'withConstruction') await this.projects.openFor(booking._id, session);
    });
    return this.get(id);
  }

  /** Frees the plot for other customers. */
  async reject(id: string) {
    await this.connection.transaction(async (session) => {
      const booking = await this.findPending(id, session);
      booking.status = 'rejected';
      booking.live = false;
      await booking.save({ session });
      await this.moveUnit(booking, 'booked', 'available', session);
    });
    return this.get(id);
  }

  /**
   * Records a payment against one part. Updating the booking in the same
   * transaction makes two payments at once take turns, so together they
   * cannot exceed the balance.
   */
  async addPayment(id: string, dto: AddPaymentDto, me: UserDocument) {
    await this.connection.transaction(async (session) => {
      const booking = isValidObjectId(id) ? await this.bookings.findById(id).session(session) : null;
      if (!booking) throw notFound();
      if (booking.status === 'rejected') throw conflict('BOOKING_REJECTED', 'A rejected booking cannot take payments.');
      if (booking.status !== 'approved') {
        throw conflict('NOT_APPROVED', 'Payments are recorded once the booking is approved.');
      }

      const plan = booking.plans.find((candidate) => candidate.part === dto.part);
      if (!plan) throw conflict('NO_SUCH_PART', 'This booking has no such part to pay for.');

      const paidSoFar = await this.payments.find({ bookingId: booking._id, part: dto.part }).session(session);
      const balance = plan.valuePaise - paidSoFar.reduce((sum, payment) => sum + payment.amountPaise, 0);
      if (dto.amountPaise > balance) {
        throw conflict('MORE_THAN_BALANCE', `More than the balance of ${rupees(balance)}.`);
      }

      // Money from the bank counts against the loan, and moves its status.
      if (dto.method === 'loanDisbursement') {
        if (plan.mode !== 'loan' || !plan.loan) {
          throw conflict('NO_LOAN', `The ${partLabel(plan.part)} is not paid with a bank loan.`);
        }
        const disbursed = paidSoFar
          .filter((payment) => payment.method === 'loanDisbursement')
          .reduce((sum, payment) => sum + payment.amountPaise, 0);
        const toCome = plan.loan.amountPaise - disbursed;
        if (dto.amountPaise > toCome) {
          throw conflict('MORE_THAN_LOAN', `More than the loan still to come, ${rupees(toCome)}.`);
        }
        plan.loan.status = disbursed + dto.amountPaise >= plan.loan.amountPaise ? 'disbursed' : 'partlyDisbursed';
        booking.markModified('plans');
      }

      const wasFullyPaid = isFullyPaid(booking);
      await this.payments.create([{ ...dto, reference: dto.reference ?? '', bookingId: booking._id, createdBy: me._id }], { session });
      booking.totalPaidPaise += dto.amountPaise;
      await booking.save({ session });

      if (booking.status === 'approved' && isFullyPaid(booking) && !wasFullyPaid) {
        await this.moveUnit(booking, 'booked', 'sold', session);
      }
    });
    return this.get(id);
  }

  /**
   * Corrects an approved booking: customer, part values, payment mode and
   * loan. Nothing may drop below what has already been paid, and a loan
   * the bank has paid out on stays a loan, its status following the money.
   */
  async update(id: string, dto: UpdateBookingDto) {
    await this.connection.transaction(async (session) => {
      const booking = isValidObjectId(id) ? await this.bookings.findById(id).session(session) : null;
      if (!booking) throw notFound();
      if (booking.status !== 'approved') {
        throw conflict('NOT_APPROVED', 'Only approved bookings can be edited here; send a rejected one for re-approval.');
      }
      const wasFullyPaid = isFullyPaid(booking);
      await this.applyEdits(booking, dto, session);
      await booking.save({ session });

      // A changed value can finish or reopen the sale.
      const nowFullyPaid = isFullyPaid(booking);
      if (nowFullyPaid && !wasFullyPaid) await this.moveUnit(booking, 'booked', 'sold', session);
      if (!nowFullyPaid && wasFullyPaid) await this.moveUnit(booking, 'sold', 'booked', session);
    });
    return this.get(id);
  }

  /**
   * Sends a rejected booking, with any corrections, back for approval. Its
   * plot is held again, unless someone else has booked it meanwhile.
   */
  async resubmit(id: string, dto: UpdateBookingDto) {
    let plotNumber = '';
    try {
      await this.connection.transaction(async (session) => {
        const booking = isValidObjectId(id) ? await this.bookings.findById(id).session(session) : null;
        if (!booking) throw notFound();
        if (booking.status !== 'rejected') {
          throw conflict('NOT_REJECTED', 'Only a rejected booking can be sent for re-approval.');
        }
        plotNumber = booking.plotNumber;
        const site = await this.sites.findSite(booking.siteId.toString());
        if (site.status === 'completed') {
          throw conflict('SITE_COMPLETED', `${site.name} is completed, so it has nothing left to book.`);
        }
        if (booking.plotId) {
          const plot = await this.sites.findPlot(site._id, booking.plotId.toString(), session);
          if (!plot) throw conflict('PLOT_NOT_FOUND', 'This plot is no longer on the layout.');
          if (plot.status !== 'available') throw conflict('PLOT_TAKEN', `Plot ${plot.number} is already booked.`);
        }

        await this.applyEdits(booking, dto, session);
        booking.status = 'pending';
        booking.live = true;
        await booking.save({ session });
        await this.moveUnit(booking, 'available', 'booked', session);
      });
    } catch (error) {
      // Another live booking holds this plot number.
      if ((error as { code?: number })?.code === 11000) {
        throw conflict('PLOT_TAKEN', `Plot ${plotNumber} is already booked.`);
      }
      throw error;
    }
    return this.get(id);
  }

  /** Checks corrections against what is already paid, then applies them. */
  private async applyEdits(booking: BookingDocument, dto: UpdateBookingDto, session: ClientSession) {
    this.validatePlans({ ...dto, type: booking.type } as CreateBookingDto);

    const payments = await this.payments.find({ bookingId: booking._id }).session(session);
    const sum = (part: string, loanOnly: boolean) =>
      payments
        .filter((payment) => payment.part === part && (!loanOnly || payment.method === 'loanDisbursement'))
        .reduce((total, payment) => total + payment.amountPaise, 0);

    const plans = dto.plans.map((plan) => {
      const label = partLabel(plan.part);
      const paid = sum(plan.part, false);
      if (plan.valuePaise < paid) {
        throw conflict('BELOW_PAID', `${rupees(paid)} is already paid, so the ${label} cannot be less.`);
      }
      const received = sum(plan.part, true);
      if (plan.mode !== 'loan') {
        if (received > 0) {
          throw conflict('LOAN_DISBURSING', `The bank has already paid ${rupees(received)} on the ${label}, so it stays a loan.`);
        }
        return { ...plan, loan: null };
      }
      const loan = plan.loan!;
      if (loan.amountPaise < received) {
        throw conflict('LOAN_BELOW_RECEIVED', `The bank has already paid ${rupees(received)}, so the loan cannot be less.`);
      }
      let status = loan.status;
      if (received > 0) {
        status = received >= loan.amountPaise ? 'disbursed' : 'partlyDisbursed';
      } else if (!MANUAL_LOAN_STATUSES.includes(status)) {
        throw new AppError('INVALID_PLANS', 'A loan with nothing paid out is Applied or Sanctioned.', HttpStatus.BAD_REQUEST);
      }
      return { ...plan, loan: { ...loan, reference: loan.reference ?? '', status } };
    });

    booking.customer = { email: '', address: '', ...dto.customer } as typeof booking.customer;
    booking.plans = plans as typeof booking.plans;
  }

  /**
   * Marks a part's loan Applied or Sanctioned. Once money has come from the
   * bank, its status follows the disbursements instead.
   */
  async updateLoanStatus(id: string, part: string, dto: UpdateLoanStatusDto) {
    const booking = isValidObjectId(id) ? await this.bookings.findById(id) : null;
    if (!booking) throw notFound();
    if (booking.status === 'rejected') throw conflict('BOOKING_REJECTED', 'A rejected booking cannot be changed.');
    if (booking.status !== 'approved') throw conflict('NOT_APPROVED', 'The loan is updated once the booking is approved.');
    const plan = booking.plans.find((candidate) => candidate.part === part);
    if (!plan?.loan) throw conflict('NO_LOAN', 'This part is not paid with a bank loan.');
    if (plan.loan.status === 'partlyDisbursed' || plan.loan.status === 'disbursed') {
      throw conflict('LOAN_DISBURSING', 'The bank has already paid out on this loan, so its status follows the disbursements.');
    }
    plan.loan.status = dto.status;
    booking.markModified('plans');
    await booking.save();
    return this.get(id);
  }

  private moveUnit(booking: BookingDocument, from: PlotStatus, to: PlotStatus, session: ClientSession) {
    return this.sites.moveUnit(booking.siteId, booking.plotId, from, to, session);
  }

  private async findPending(id: string, session: ClientSession): Promise<BookingDocument> {
    const booking = isValidObjectId(id) ? await this.bookings.findById(id).session(session) : null;
    if (!booking) throw notFound();
    if (booking.status !== 'pending') throw conflict('ALREADY_DECIDED', `This booking is already ${booking.status}.`);
    return booking;
  }

  private validatePlans(dto: CreateBookingDto): void {
    const parts = dto.plans.map((plan) => plan.part);
    const expected = dto.type === 'withConstruction' ? ['construction', 'plot'] : ['plot'];
    if ([...parts].sort().join() !== expected.join()) {
      throw new AppError('INVALID_PLANS', 'The payment plans do not match the booking type.', HttpStatus.BAD_REQUEST);
    }
    for (const plan of dto.plans) {
      if (plan.mode === 'loan' && !plan.loan) {
        throw new AppError('INVALID_PLANS', 'Please enter the loan details.', HttpStatus.BAD_REQUEST);
      }
      if (plan.mode === 'loan' && plan.loan && plan.loan.amountPaise > plan.valuePaise) {
        throw new AppError('INVALID_PLANS', 'A loan cannot be more than the value it pays for.', HttpStatus.BAD_REQUEST);
      }
    }

    // At booking the customer pays from their own share; the bank's part
    // arrives later as loan disbursements.
    for (const plan of dto.plans) {
      const paid = (dto.initialPayments ?? [])
        .filter((payment) => payment.part === plan.part)
        .reduce((sum, payment) => sum + payment.amountPaise, 0);
      const ownShare = plan.valuePaise - (plan.mode === 'loan' ? (plan.loan?.amountPaise ?? 0) : 0);
      if (paid > ownShare) {
        throw new AppError(
          'MORE_THAN_SHARE',
          `The amount paid is more than the customer's own share of ${rupees(ownShare)}.`,
          HttpStatus.BAD_REQUEST,
        );
      }
    }
    for (const payment of dto.initialPayments ?? []) {
      if (payment.method === 'loanDisbursement') {
        throw new AppError('NOT_OWN_PAYMENT', 'Loan disbursements are recorded after booking.', HttpStatus.BAD_REQUEST);
      }
      if (!parts.includes(payment.part)) {
        throw new AppError('NO_SUCH_PART', 'This booking has no such part to pay for.', HttpStatus.BAD_REQUEST);
      }
    }
  }

  private toJson(booking: BookingDocument, payments: PaymentDocument[]) {
    return {
      id: booking.id as string,
      siteId: booking.siteId.toString(),
      siteName: booking.siteName,
      plotId: booking.plotId?.toString() ?? null,
      plotNumber: booking.plotNumber,
      plotSize: booking.plotSize,
      facing: booking.facing,
      customer: booking.customer,
      type: booking.type,
      plans: booking.plans,
      status: booking.status,
      bookedOn: booking.bookedOn,
      bookedBy: booking.bookedByName,
      payments: payments
        .filter((payment) => payment.bookingId.equals(booking._id))
        .map((payment) => ({
          id: payment.id as string,
          part: payment.part,
          amountPaise: payment.amountPaise,
          date: payment.date,
          method: payment.method,
          reference: payment.reference,
        })),
    };
  }
}
