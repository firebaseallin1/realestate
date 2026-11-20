import type { INestApplication } from '@nestjs/common';
import { Types } from 'mongoose';
import { getConnectionToken } from '@nestjs/mongoose';
import { Test } from '@nestjs/testing';
import { mkdtemp, readdir, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { MongoMemoryReplSet } from 'mongodb-memory-server';
import type { Connection } from 'mongoose';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

const PASSWORD = 'correct-horse';
const PDF = Buffer.from('%PDF-1.4 test bill');
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2, 3]);

const siteBody = {
  name: 'Green Meadows',
  location: 'Hyderabad',
  type: 'plots',
  status: 'active',
  totalUnits: 10,
  soldUnits: 0,
  bookedUnits: 0,
  ownerName: 'Ramesh',
  totalArea: 1000,
  salesArea: 700,
  roadArea: 200,
  gardenArea: 50,
  otherArea: 0,
};
const customer = { name: 'Kiran', mobile: '98765 43210' };
const plotOnly = (siteId: string, plotNumber = '12', valuePaise = 100_000) => ({
  siteId,
  plotNumber,
  customer,
  type: 'withoutConstruction',
  plans: [{ part: 'plot', valuePaise, mode: 'fullPayment' }],
});
const withHouse = (siteId: string, plotNumber = '27') => ({
  siteId,
  plotNumber,
  customer,
  type: 'withConstruction',
  plans: [
    { part: 'plot', valuePaise: 100_000, mode: 'fullPayment' },
    { part: 'construction', valuePaise: 900_000, mode: 'fullPayment' },
  ],
});
const plot = (number: string, extra: object = {}) => ({
  number,
  widthFt: 30,
  lengthFt: 40,
  facing: 'east',
  status: 'available',
  rect: { x: 0.1, y: 0.1, w: 0.2, h: 0.2 },
  ...extra,
});

describe('Sites, bookings and construction', () => {
  let mongo: MongoMemoryReplSet;
  let app: INestApplication;
  let http: ReturnType<typeof request>;
  let auth: Record<string, { Authorization: string }>;
  let ids: Record<string, string>;

  const as = (who: string) => ({
    get: (url: string) => http.get(`/api/v1${url}`).set(auth[who]),
    post: (url: string, body: object = {}) => http.post(`/api/v1${url}`).set(auth[who]).send(body),
    patch: (url: string, body: object = {}) => http.patch(`/api/v1${url}`).set(auth[who]).send(body),
    put: (url: string, body: object = {}) => http.put(`/api/v1${url}`).set(auth[who]).send(body),
    delete: (url: string) => http.delete(`/api/v1${url}`).set(auth[who]),
  });

  const newSite = async (body: object = {}) => (await as('admin').post('/sites', { ...siteBody, ...body }).expect(201)).body;
  const sites = async () => (await as('admin').get('/sites').expect(200)).body.items;
  const siteById = async (id: string) => (await sites()).find((s: { id: string }) => s.id === id);

  /** An approved With Construction booking, its house assigned to the incharge. */
  async function newProject() {
    const site = await newSite();
    const booking = (await as('sales').post('/bookings', withHouse(site.id)).expect(201)).body;
    await as('admin').post(`/bookings/${booking.id}/approve`).expect(200);
    await as('manager').patch(`/projects/${booking.id}/incharge`, { inchargeId: ids.incharge }).expect(200);
    return booking.id as string;
  }

  const project = async (id: string, who = 'admin') =>
    (await as(who).get('/projects').expect(200)).body.items.find((p: { booking: { id: string } }) => p.booking.id === id);

  beforeAll(async () => {
    mongo = await MongoMemoryReplSet.create({ replSet: { count: 1 } });
    process.env.MONGODB_URI = mongo.getUri('kaira_business_test');
    process.env.JWT_SECRET = 'test-secret-that-is-at-least-32-characters-long';
    process.env.NODE_ENV = 'test';
    process.env.LOGIN_RATE_LIMIT = '100000';
    process.env.UPLOAD_DIR = await mkdtemp(join(tmpdir(), 'kaira-uploads-'));

    const { AppModule } = await import('../src/app.module.js');
    const { configureApp } = await import('../src/app.setup.js');
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication();
    configureApp(app);
    await app.init();
    http = request(app.getHttpServer());
  }, 180_000);

  afterAll(async () => {
    await app?.close();
    await mongo?.stop();
  });

  beforeEach(async () => {
    const connection = app.get<Connection>(getConnectionToken());
    for (const model of Object.values(connection.models)) await model.syncIndexes();
    for (const model of Object.values(connection.models)) await model.deleteMany({});

    const { UsersService } = await import('../src/users/users.service.js');
    const users = app.get(UsersService);
    auth = {};
    ids = {};
    for (const [username, role] of [
      ['admin', 'admin'],
      ['sales', 'salesExecutive'],
      ['sales2', 'salesExecutive'],
      ['manager', 'siteManager'],
      ['incharge', 'siteIncharge'],
      ['other', 'siteIncharge'],
    ] as const) {
      const user = await users.create({ name: `${username} name`, username, password: PASSWORD, role: role as never });
      ids[username] = user.id as string;
      const { body } = await http.post('/api/v1/auth/login').send({ username, password: PASSWORD }).expect(200);
      auth[username] = { Authorization: `Bearer ${body.accessToken}` };
    }
  });

  describe('locations and sites', () => {
    it('everyone reads; only Admins change', async () => {
      const site = await newSite();
      for (const who of ['sales', 'manager', 'incharge']) {
        await as(who).get('/sites').expect(200);
        await as(who).get('/locations').expect(200);
        await as(who).post('/sites', siteBody).expect(403);
        await as(who).patch(`/sites/${site.id}`, siteBody).expect(403);
        await as(who).delete(`/sites/${site.id}`).expect(403);
        await as(who).put(`/sites/${site.id}/plots`, { plots: [] }).expect(403);
        await as(who).post('/locations', { name: 'Pune' }).expect(403);
        await as(who).patch(`/locations/${site.id}`, { latitude: 1, longitude: 1 }).expect(403);
      }
    });

    it('a new city becomes a location, and spelling is kept consistent', async () => {
      await as('admin').post('/locations', { name: 'Chennai' }).expect(201);
      const taken = await as('admin').post('/locations', { name: 'chennai' }).expect(409);
      expect(taken.body.code).toBe('LOCATION_EXISTS');

      expect((await newSite({ location: 'Pune' })).location).toBe('Pune');
      expect((await newSite({ location: 'PUNE' })).location).toBe('Pune');
      const names = (await as('admin').get('/locations')).body.items.map((l: { name: string }) => l.name);
      expect(names).toEqual(['Chennai', 'Pune']);
    });

    it("keeps a location's map point, needing both halves", async () => {
      const added = await as('admin').post('/locations', { name: 'Goa', latitude: 15.4909, longitude: 73.8278 }).expect(201);
      expect(added.body).toMatchObject({ name: 'Goa', latitude: 15.4909, longitude: 73.8278 });

      const half = await as('admin').post('/locations', { name: 'Ooty', latitude: 11.4 }).expect(400);
      expect(half.body.code).toBe('INCOMPLETE_POINT');
      await as('admin').post('/locations', { name: 'Ooty', latitude: 95, longitude: 10 }).expect(400);

      await as('admin').post('/locations', { name: 'Mysuru' }).expect(201);
      let mysuru = (await as('admin').get('/locations')).body.items.find((l: { name: string }) => l.name === 'Mysuru');
      expect(mysuru).toMatchObject({ latitude: null, longitude: null });

      await as('admin').patch(`/locations/${mysuru.id}`, { latitude: 12.2958, longitude: 76.6394 }).expect(200);
      mysuru = (await as('admin').get('/locations')).body.items.find((l: { name: string }) => l.name === 'Mysuru');
      expect(mysuru).toMatchObject({ latitude: 12.2958, longitude: 76.6394 });

      const cleared = await as('admin').patch(`/locations/${mysuru.id}`, { latitude: null, longitude: null }).expect(200);
      expect(cleared.body).toMatchObject({ latitude: null, longitude: null });
      await as('admin').patch('/locations/000000000000000000000000', { latitude: 1, longitude: 1 }).expect(404);
    });

    it('saves owner and areas, and checks they add up', async () => {
      const site = await newSite();
      expect(site).toMatchObject({ ownerName: 'Ramesh', totalArea: 1000, gardenArea: 50 });
      const { body } = await as('admin').post('/sites', { ...siteBody, salesArea: 5000 }).expect(400);
      expect(body.code).toBe('AREA_TOO_LARGE');
      expect((await as('admin').post('/sites', { ...siteBody, soldUnits: 11 }).expect(400)).body.code).toBe('TOO_FEW_UNITS');
    });

    it('updates a site, and a missing one answers 404', async () => {
      const site = await newSite();
      const { body } = await as('admin').patch(`/sites/${site.id}`, { ...siteBody, name: 'Renamed' }).expect(200);
      expect(body.name).toBe('Renamed');
      await as('admin').patch('/sites/not-an-id', siteBody).expect(404);
    });

    it('a site with bookings cannot be deleted, even a rejected one', async () => {
      const site = await newSite();
      const booking = (await as('sales').post('/bookings', plotOnly(site.id)).expect(201)).body;
      expect((await as('admin').delete(`/sites/${site.id}`).expect(409)).body.code).toBe('SITE_HAS_BOOKINGS');
      await as('admin').post(`/bookings/${booking.id}/reject`).expect(200);
      await as('admin').delete(`/sites/${site.id}`).expect(409);

      const empty = await newSite({ name: 'Empty' });
      await as('admin').put(`/sites/${empty.id}/plots`, { plots: [plot('1')] }).expect(200);
      await as('admin').delete(`/sites/${empty.id}`).expect(204);
      expect(await siteById(empty.id)).toBeUndefined();
    });
  });

  describe('plots', () => {
    it('saves a layout, and the site counts follow it', async () => {
      const site = await newSite();
      const { body } = await as('admin')
        .put(`/sites/${site.id}/plots`, { plots: [plot('1', { id: '1730000000000' }), plot('2', { status: 'sold', pricePaise: 500 })] })
        .expect(200);
      expect(body.plots.map((p: { number: string }) => p.number)).toEqual(['1', '2']);
      expect(body).toMatchObject({ totalUnits: 2, soldUnits: 1, bookedUnits: 0 });
      expect(body.plots[0].id).toMatch(/^[0-9a-f]{24}$/);

      // Same IDs update in place; a plot left out is deleted.
      const edited = await as('admin')
        .put(`/sites/${site.id}/plots`, { plots: [plot('1A', { id: body.plots[0].id })] })
        .expect(200);
      expect(edited.body.plots).toHaveLength(1);
      expect(edited.body.plots[0]).toMatchObject({ id: body.plots[0].id, number: '1A' });
      expect(edited.body.totalUnits).toBe(1);
    });

    it('refuses repeated numbers', async () => {
      const site = await newSite();
      const { body } = await as('admin').put(`/sites/${site.id}/plots`, { plots: [plot('7'), plot('7')] }).expect(409);
      expect(body.code).toBe('PLOT_NUMBER_TAKEN');
    });

    it('a booked plot cannot be removed or renumbered, and keeps its status', async () => {
      const site = await newSite();
      const saved = (await as('admin').put(`/sites/${site.id}/plots`, { plots: [plot('1'), plot('2')] }).expect(200)).body;
      const [first, second] = saved.plots;
      await as('sales').post('/bookings', { ...plotOnly(site.id, '1'), plotId: first.id }).expect(201);

      const removed = await as('admin').put(`/sites/${site.id}/plots`, { plots: [plot('2', { id: second.id })] }).expect(409);
      expect(removed.body.code).toBe('PLOT_HAS_BOOKING');
      await as('admin').put(`/sites/${site.id}/plots`, { plots: [plot('9', { id: first.id }), plot('2', { id: second.id })] }).expect(409);

      // A stale screen saying "available" does not free it.
      const stale = await as('admin')
        .put(`/sites/${site.id}/plots`, { plots: [plot('1', { id: first.id, status: 'available' }), plot('2', { id: second.id })] })
        .expect(200);
      expect(stale.body.plots[0].status).toBe('booked');
      expect(stale.body.bookedUnits).toBe(1);
    });
  });

  describe('bookings', () => {
    it('only sales and Admins can see or raise bookings', async () => {
      const site = await newSite();
      for (const who of ['manager', 'incharge']) {
        await as(who).get('/bookings').expect(403);
        await as(who).post('/bookings', plotOnly(site.id)).expect(403);
      }
      await as('sales').post('/bookings', plotOnly(site.id)).expect(201);
      await as('admin').get('/bookings').expect(200);
    });

    it('only Admins approve or reject', async () => {
      const site = await newSite();
      const booking = (await as('sales').post('/bookings', plotOnly(site.id)).expect(201)).body;
      await as('sales').post(`/bookings/${booking.id}/approve`).expect(403);
      await as('sales').post(`/bookings/${booking.id}/reject`).expect(403);
      await as('manager').post(`/bookings/${booking.id}/approve`).expect(403);
    });

    it('records who booked it and today, whatever the app sends', async () => {
      const site = await newSite();
      const { body } = await as('sales').post('/bookings', plotOnly(site.id)).expect(201);
      expect(body.bookedBy).toBe('sales name');
      expect(body.bookedOn).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      expect(body.status).toBe('pending');
      await as('sales').post('/bookings', { ...plotOnly(site.id, '13'), bookedBy: 'someone else' }).expect(400);
    });

    it('A PLOT CANNOT BE DOUBLE-BOOKED, even at the same moment', async () => {
      const site = await newSite({ totalUnits: 100 });
      const attempts = await Promise.all(
        Array.from({ length: 8 }, () => as('sales').post('/bookings', plotOnly(site.id, ' 42 '))),
      );
      const statuses = attempts.map((attempt) => attempt.status);
      expect(statuses.filter((status) => status === 201)).toHaveLength(1);
      expect(statuses.filter((status) => status === 409)).toHaveLength(7);
      expect(attempts.find((attempt) => attempt.status === 409)?.body.code).toBe('PLOT_TAKEN');

      const items = (await as('admin').get('/bookings')).body.items;
      expect(items).toHaveLength(1);
      expect((await siteById(site.id)).bookedUnits).toBe(1);

      // Ignoring case too.
      await as('sales').post('/bookings', plotOnly(site.id, 'a1')).expect(201);
      await as('sales').post('/bookings', plotOnly(site.id, 'A1')).expect(409);
    });

    it('rejecting frees the plot for someone else', async () => {
      const site = await newSite();
      const first = (await as('sales').post('/bookings', plotOnly(site.id)).expect(201)).body;
      await as('sales').post('/bookings', plotOnly(site.id)).expect(409);
      expect((await siteById(site.id)).bookedUnits).toBe(1);

      await as('admin').post(`/bookings/${first.id}/reject`).expect(200);
      expect((await siteById(site.id)).bookedUnits).toBe(0);
      await as('sales').post('/bookings', plotOnly(site.id)).expect(201);

      const decided = await as('admin').post(`/bookings/${first.id}/approve`).expect(409);
      expect(decided.body.code).toBe('ALREADY_DECIDED');
    });

    it('moves a drawn plot through booked and sold', async () => {
      const site = await newSite();
      const [plotA] = (await as('admin').put(`/sites/${site.id}/plots`, { plots: [plot('1', { facing: 'north' })] })).body.plots;
      const booking = (await as('sales').post('/bookings', { ...plotOnly(site.id, 'ignored'), plotId: plotA.id }).expect(201)).body;
      expect(booking).toMatchObject({ plotNumber: '1', facing: 'north', plotId: plotA.id });

      const again = await as('sales').post('/bookings', { ...plotOnly(site.id, '99'), plotId: plotA.id }).expect(409);
      expect(again.body.code).toBe('PLOT_TAKEN');
      expect(await siteById(site.id)).toMatchObject({ bookedUnits: 1, soldUnits: 0 });

      await as('admin').post(`/bookings/${booking.id}/approve`).expect(200);
      await as('sales')
        .post(`/bookings/${booking.id}/payments`, { part: 'plot', amountPaise: 100_000, date: '2026-10-24', method: 'upi' })
        .expect(201);
      const finished = await siteById(site.id);
      expect(finished).toMatchObject({ bookedUnits: 0, soldUnits: 1 });
      expect(finished.plots[0].status).toBe('sold');
    });

    it('checks plans, sites and mobile numbers', async () => {
      const site = await newSite();
      const plans = (body: object) => as('sales').post('/bookings', { ...plotOnly(site.id), ...body });
      expect((await plans({ type: 'withConstruction' }).expect(400)).body.code).toBe('INVALID_PLANS');
      expect((await plans({ plans: [{ part: 'plot', valuePaise: 100, mode: 'loan' }] }).expect(400)).body.message).toBe('Please enter the loan details.');
      await plans({
        plans: [{ part: 'plot', valuePaise: 100, mode: 'loan', loan: { bankName: 'SBI', amountPaise: 500, status: 'applied' } }],
      }).expect(400);
      await plans({ customer: { name: 'A', mobile: '123' } }).expect(400);

      const done = await newSite({ status: 'completed' });
      expect((await as('sales').post('/bookings', plotOnly(done.id)).expect(409)).body.code).toBe('SITE_COMPLETED');
      await as('sales').post('/bookings', plotOnly('64b000000000000000000000')).expect(404);
    });

    it('edits approved bookings only, never below what is paid', async () => {
      const site = await newSite();
      const loanPlan = (valuePaise: number, amountPaise: number, status = 'sanctioned') => ({
        part: 'plot',
        valuePaise,
        mode: 'loan',
        loan: { bankName: 'SBI', amountPaise, status },
      });
      const { body: booking } = await as('sales')
        .post('/bookings', { ...plotOnly(site.id, '60', 650_000), plans: [loanPlan(650_000, 500_000)] })
        .expect(201);
      const change = (body: object) => as('sales').patch(`/bookings/${booking.id}`, { customer, plans: [loanPlan(650_000, 500_000)], ...body });

      expect((await change({}).expect(409)).body.code).toBe('NOT_APPROVED');
      await as('admin').post(`/bookings/${booking.id}/approve`).expect(200);
      await as('manager').patch(`/bookings/${booking.id}`, { customer, plans: [loanPlan(650_000, 500_000)] }).expect(403);

      // Customer and loan details change.
      const edited = await change({
        customer: { name: 'Kiran Kumar', mobile: '98765 43210', address: 'Guntur' },
        plans: [{ ...loanPlan(700_000, 550_000, 'applied'), loan: { bankName: 'HDFC', amountPaise: 550_000, reference: 'HL-1', status: 'applied' } }],
      }).expect(200);
      expect(edited.body.customer).toMatchObject({ name: 'Kiran Kumar', address: 'Guntur' });
      expect(edited.body.plans[0]).toMatchObject({ valuePaise: 700_000, loan: { bankName: 'HDFC', amountPaise: 550_000, status: 'applied' } });
      expect((await change({ plans: [loanPlan(700_000, 550_000, 'disbursed')] }).expect(400)).body.code).toBe('INVALID_PLANS');
      expect((await change({ type: 'withConstruction' }).expect(400)).body.code).toBe('VALIDATION_FAILED');

      // Once paid: not below the payments, and the bank's loan stays a loan.
      const pay = (amountPaise: number, method: string) =>
        as('sales').post(`/bookings/${booking.id}/payments`, { part: 'plot', amountPaise, date: '2026-11-12', method }).expect(201);
      await pay(150_000, 'upi');
      await pay(200_000, 'loanDisbursement');
      expect((await change({ plans: [loanPlan(300_000, 100_000)] }).expect(409)).body.code).toBe('BELOW_PAID');
      expect((await change({ plans: [loanPlan(700_000, 100_000)] }).expect(409)).body.code).toBe('LOAN_BELOW_RECEIVED');
      expect((await change({ plans: [{ part: 'plot', valuePaise: 700_000, mode: 'fullPayment' }] }).expect(409)).body.code).toBe('LOAN_DISBURSING');

      // The status follows the money: lowering the loan to what came finishes it.
      const done = await change({ plans: [loanPlan(350_000, 200_000)] }).expect(200);
      expect(done.body.plans[0].loan.status).toBe('disbursed');
      expect((await siteById(site.id)).soldUnits).toBe(1);

      // Raising the value again reopens the sale.
      await change({ plans: [loanPlan(400_000, 200_000)] }).expect(200);
      expect(await siteById(site.id)).toMatchObject({ soldUnits: 0, bookedUnits: 1 });
    });

    it('sends a rejected booking, corrected, back for approval', async () => {
      const site = await newSite();
      await as('admin').put(`/sites/${site.id}/plots`, { plots: [plot('70'), plot('71', { rect: { x: 0.5, y: 0.1, w: 0.2, h: 0.2 } })] }).expect(200);
      const plots = (await siteById(site.id)).plots;
      const plotId = plots.find((p: { number: string }) => p.number === '70').id;
      const { body: booking } = await as('sales').post('/bookings', { ...plotOnly(site.id, '70'), plotId }).expect(201);
      const resend = (body: object = {}) =>
        as('sales').post(`/bookings/${booking.id}/resubmit`, { customer, plans: [{ part: 'plot', valuePaise: 120_000, mode: 'fullPayment' }], ...body });

      expect((await resend().expect(409)).body.code).toBe('NOT_REJECTED');
      await as('admin').post(`/bookings/${booking.id}/reject`).expect(200);
      expect((await siteById(site.id)).plots.find((p: { id: string }) => p.id === plotId).status).toBe('available');
      // Rejected bookings are not edited in place.
      expect((await as('sales').patch(`/bookings/${booking.id}`, { customer, plans: [{ part: 'plot', valuePaise: 1, mode: 'fullPayment' }] }).expect(409)).body.code).toBe('NOT_APPROVED');

      const again = await resend({ customer: { ...customer, address: 'Nellore' } }).expect(200);
      expect(again.body).toMatchObject({ status: 'pending', customer: { address: 'Nellore' }, plans: [{ valuePaise: 120_000 }] });
      expect((await siteById(site.id)).plots.find((p: { id: string }) => p.id === plotId).status).toBe('booked');
      await as('admin').post(`/bookings/${booking.id}/approve`).expect(200);

      // If someone else took the plot meanwhile, it cannot come back.
      const { body: second } = await as('sales').post('/bookings', plotOnly(site.id, '71')).expect(201);
      await as('admin').post(`/bookings/${second.id}/reject`).expect(200);
      await as('sales').post('/bookings', plotOnly(site.id, '71')).expect(201);
      const taken = await as('sales').post(`/bookings/${second.id}/resubmit`, { customer, plans: [{ part: 'plot', valuePaise: 100_000, mode: 'fullPayment' }] }).expect(409);
      expect(taken.body.code).toBe('PLOT_TAKEN');
    });

    it('moves the loan status with disbursements, and by hand before them', async () => {
      const site = await newSite();
      const { body: booking } = await as('sales')
        .post('/bookings', {
          ...plotOnly(site.id, '50', 650_000),
          plans: [{ part: 'plot', valuePaise: 650_000, mode: 'loan', loan: { bankName: 'SBI', amountPaise: 500_000, status: 'applied' } }],
        })
        .expect(201);
      const loanStatus = (body: { plans: { loan: { status: string } }[] }) => body.plans[0].loan.status;
      const disburse = (amountPaise: number) =>
        as('sales').post(`/bookings/${booking.id}/payments`, { part: 'plot', amountPaise, date: '2026-11-12', method: 'loanDisbursement' });

      // Nothing changes while the booking waits for approval.
      expect((await as('sales').patch(`/bookings/${booking.id}/loans/plot`, { status: 'sanctioned' }).expect(409)).body.code).toBe('NOT_APPROVED');
      expect((await disburse(1_000).expect(409)).body.code).toBe('NOT_APPROVED');
      await as('admin').post(`/bookings/${booking.id}/approve`).expect(200);

      expect(loanStatus((await as('sales').patch(`/bookings/${booking.id}/loans/plot`, { status: 'sanctioned' }).expect(200)).body)).toBe('sanctioned');
      await as('sales').patch(`/bookings/${booking.id}/loans/plot`, { status: 'disbursed' }).expect(400);
      await as('manager').patch(`/bookings/${booking.id}/loans/plot`, { status: 'applied' }).expect(403);

      expect(loanStatus((await disburse(200_000).expect(201)).body)).toBe('partlyDisbursed');
      expect((await disburse(300_001).expect(409)).body.code).toBe('MORE_THAN_LOAN');
      expect(loanStatus((await disburse(300_000).expect(201)).body)).toBe('disbursed');
      expect((await as('sales').patch(`/bookings/${booking.id}/loans/plot`, { status: 'applied' }).expect(409)).body.code).toBe('LOAN_DISBURSING');

      // A part paid in full has no loan to disburse.
      const { body: cash } = await as('sales').post('/bookings', plotOnly(site.id, '51')).expect(201);
      await as('admin').post(`/bookings/${cash.id}/approve`).expect(200);
      const noLoan = await as('sales')
        .post(`/bookings/${cash.id}/payments`, { part: 'plot', amountPaise: 100, date: '2026-11-12', method: 'loanDisbursement' })
        .expect(409);
      expect(noLoan.body.code).toBe('NO_LOAN');
    });

    it("records what the customer paid at booking, up to their own share", async () => {
      const site = await newSite();
      // Plot ₹6,500 with a ₹5,000 loan: the customer's own share is ₹1,500.
      const onLoan = (plotNumber: string, initialPayments: object[]) =>
        as('sales').post('/bookings', {
          ...plotOnly(site.id, plotNumber, 650_000),
          plans: [{ part: 'plot', valuePaise: 650_000, mode: 'loan', loan: { bankName: 'SBI', amountPaise: 500_000, status: 'applied' } }],
          initialPayments,
        });
      const paidNow = (amountPaise: number, part = 'plot') => ({ part, amountPaise, date: '2026-11-12', method: 'upi', reference: 'UTR1' });

      const tooMuch = await onLoan('40', [paidNow(150_001)]).expect(400);
      expect(tooMuch.body.code).toBe('MORE_THAN_SHARE');
      expect((await onLoan('40', [paidNow(1_000, 'construction')]).expect(400)).body.code).toBe('NO_SUCH_PART');

      const { body } = await onLoan('40', [paidNow(50_000)]).expect(201);
      expect(body.payments).toHaveLength(1);
      expect(body.payments[0]).toMatchObject({ part: 'plot', amountPaise: 50_000, method: 'upi', reference: 'UTR1' });

      // The rest of the own share, then the loan, arrive after approval.
      await as('admin').post(`/bookings/${body.id}/approve`).expect(200);
      await as('sales').post(`/bookings/${body.id}/payments`, paidNow(100_000)).expect(201);
      await as('sales').post(`/bookings/${body.id}/payments`, { ...paidNow(500_000), method: 'loanDisbursement' }).expect(201);
      await as('sales').post(`/bookings/${body.id}/payments`, paidNow(1)).expect(409);

      // Loan money cannot be counted as paid at booking.
      const early = await onLoan('42', [{ ...paidNow(1_000), method: 'loanDisbursement' }]).expect(400);
      expect(early.body.code).toBe('NOT_OWN_PAYMENT');

      // Nothing paid at booking is fine too.
      expect((await onLoan('41', []).expect(201)).body.payments).toHaveLength(0);
    });
  });

  describe('payments', () => {
    const approved = async (body: object) => {
      const booking = (await as('sales').post('/bookings', body).expect(201)).body;
      await as('admin').post(`/bookings/${booking.id}/approve`).expect(200);
      return booking;
    };
    const pay = (id: string, amountPaise: number, who = 'sales', part = 'plot') =>
      as(who).post(`/bookings/${id}/payments`, { part, amountPaise, date: '2026-10-24', method: 'cash', reference: 'R1' });

    it('cannot exceed the balance of that part', async () => {
      const site = await newSite();
      const booking = await approved(withHouse(site.id));
      await pay(booking.id, 60_000).expect(201);
      const over = await pay(booking.id, 50_000).expect(409);
      expect(over.body).toEqual({ code: 'MORE_THAN_BALANCE', message: 'More than the balance of ₹400.' });
      await pay(booking.id, 500_000, 'sales', 'construction').expect(201);

      const { body } = await pay(booking.id, 40_000).expect(201);
      expect(body.payments.map((p: { amountPaise: number }) => p.amountPaise)).toEqual([60_000, 500_000, 40_000]);
    });

    it('payments at the same moment cannot together exceed the balance', async () => {
      const site = await newSite();
      const booking = await approved(plotOnly(site.id, '1', 100_000));
      const results = await Promise.all(Array.from({ length: 5 }, () => pay(booking.id, 60_000)));
      expect(results.filter((r) => r.status === 201)).toHaveLength(1);
      expect(results.filter((r) => r.status === 409)).toHaveLength(4);
    });

    it('a pending booking takes none; paying an approved one in full sells it', async () => {
      const site = await newSite();
      const booking = (await as('sales').post('/bookings', plotOnly(site.id)).expect(201)).body;
      expect((await pay(booking.id, 100_000).expect(409)).body.code).toBe('NOT_APPROVED');
      await as('admin').post(`/bookings/${booking.id}/approve`).expect(200);
      expect(await siteById(site.id)).toMatchObject({ bookedUnits: 1, soldUnits: 0 });
      await pay(booking.id, 100_000).expect(201);
      expect(await siteById(site.id)).toMatchObject({ bookedUnits: 0, soldUnits: 1 });
    });

    it('rejected bookings take none; site staff cannot record any', async () => {
      const site = await newSite();
      const booking = (await as('sales').post('/bookings', plotOnly(site.id)).expect(201)).body;
      await pay(booking.id, 100, 'manager').expect(403);
      await as('admin').post(`/bookings/${booking.id}/reject`).expect(200);
      expect((await pay(booking.id, 100).expect(409)).body.code).toBe('BOOKING_REJECTED');
    });

    it('checks amounts and dates', async () => {
      const site = await newSite();
      const booking = await approved(plotOnly(site.id));
      await pay(booking.id, 0).expect(400);
      await pay(booking.id, 10.5).expect(400);
      await as('sales').post(`/bookings/${booking.id}/payments`, { part: 'plot', amountPaise: 1, date: '2026-02-31', method: 'cash' }).expect(400);
      await as('sales').post(`/bookings/${booking.id}/payments`, { part: 'construction', amountPaise: 1, date: '2026-02-01', method: 'cash' }).expect(409);
    });
  });

  describe('construction', () => {
    it('approval opens the house with the standard stages; plot-only does not', async () => {
      const site = await newSite();
      const plain = (await as('sales').post('/bookings', plotOnly(site.id)).expect(201)).body;
      await as('admin').post(`/bookings/${plain.id}/approve`).expect(200);
      expect((await as('admin').get('/projects')).body.items).toEqual([]);

      const house = (await as('sales').post('/bookings', withHouse(site.id)).expect(201)).body;
      expect((await as('admin').get('/projects')).body.items).toEqual([]);
      await as('admin').post(`/bookings/${house.id}/approve`).expect(200);

      const [opened] = (await as('admin').get('/projects')).body.items;
      expect(opened.booking.id).toBe(house.id);
      expect(opened.stages).toHaveLength(9);
      expect(opened.stages[0]).toMatchObject({ name: 'Foundation', status: 'notStarted', progress: 0 });
      expect(opened.inchargeId).toBeNull();
    });

    it('site staff do not get customer contact details', async () => {
      const id = await newProject();
      const house = await project(id, 'incharge');
      expect(house.booking.customer).toEqual({ name: 'Kiran', mobile: '' });
    });

    it('sales have no access; incharges only to their own houses', async () => {
      const id = await newProject();
      await as('sales').get('/projects').expect(403);
      expect((await as('incharge').get('/projects')).body.items).toHaveLength(1);
      expect((await as('other').get('/projects')).body.items).toEqual([]);

      const stage = (await project(id)).stages[0].id;
      const update = { status: 'inProgress', progress: 10 };
      await as('other').patch(`/projects/${id}/stages/${stage}`, update).expect(403);
      await as('other').post(`/projects/${id}/workers`, { name: 'X', trade: 'mason', dailyWagePaise: 100 }).expect(403);
      await as('incharge').patch(`/projects/${id}/stages/${stage}`, update).expect(200);
    });

    it('only Admins and managers assign, and only to active incharges', async () => {
      const id = await newProject();
      await as('incharge').patch(`/projects/${id}/incharge`, { inchargeId: ids.other }).expect(403);
      const wrong = await as('manager').patch(`/projects/${id}/incharge`, { inchargeId: ids.sales }).expect(409);
      expect(wrong.body.code).toBe('NOT_AN_INCHARGE');
      const cleared = await as('manager').patch(`/projects/${id}/incharge`, { inchargeId: null }).expect(200);
      expect(cleared.body.inchargeId).toBeNull();
      expect((await as('incharge').get('/projects')).body.items).toEqual([]);
    });

    it('applies the stage rules', async () => {
      const id = await newProject();
      const stage = (await project(id)).stages[2].id;
      const set = async (status: string, progress: number) =>
        (await as('incharge').patch(`/projects/${id}/stages/${stage}`, { status, progress }).expect(200)).body.stages[2].progress;
      expect(await set('completed', 40)).toBe(100);
      expect(await set('notStarted', 40)).toBe(0);
      expect(await set('inProgress', 0)).toBe(1);
      expect(await set('inProgress', 100)).toBe(99);
    });

    it('work updates start the stage and earn wages; wages cannot be overpaid', async () => {
      const id = await newProject();
      const added = (await as('incharge').post(`/projects/${id}/workers`, { name: 'Raju', trade: 'mason', dailyWagePaise: 90_000 }).expect(201)).body;
      const worker = added.workers[0].id;
      const stage = added.stages[3].id;

      const work = { date: '2026-10-20', stageId: stage, description: 'Shuttering', workerIds: [worker] };
      const updated = (await as('incharge').post(`/projects/${id}/daily-work`, work).expect(201)).body;
      expect(updated.stages[3]).toMatchObject({ status: 'inProgress', progress: 5 });
      expect(updated.dailyWork[0]).toMatchObject({ updatedBy: 'incharge name', workerIds: [worker] });
      await as('incharge').post(`/projects/${id}/daily-work`, { ...work, date: '2026-10-21' }).expect(201);

      const payment = { kind: 'worker', targetId: worker, amountPaise: 180_001, date: '2026-10-22', method: 'cash' };
      const over = await as('incharge').post(`/projects/${id}/expense-payments`, payment).expect(409);
      expect(over.body).toEqual({ code: 'MORE_THAN_DUE', message: 'More than the ₹1,800 due.' });
      await as('incharge').post(`/projects/${id}/expense-payments`, { ...payment, amountPaise: 180_000 }).expect(201);
      await as('incharge').post(`/projects/${id}/expense-payments`, { ...payment, amountPaise: 1 }).expect(409);
    });

    it('rejects workers from another house, and empty attendance', async () => {
      const first = await newProject();
      const site = await newSite({ name: 'Second' });
      const secondBooking = (await as('sales').post('/bookings', withHouse(site.id, '1')).expect(201)).body;
      await as('admin').post(`/bookings/${secondBooking.id}/approve`).expect(200);
      const foreign = (await as('admin').post(`/projects/${secondBooking.id}/workers`, { name: 'Far', trade: 'helper', dailyWagePaise: 100 }).expect(201)).body.workers[0].id;

      const stage = (await project(first)).stages[0].id;
      const work = { date: '2026-10-20', stageId: stage, description: 'x', workerIds: [foreign] };
      expect((await as('admin').post(`/projects/${first}/daily-work`, work).expect(409)).body.code).toBe('UNKNOWN_WORKER');
      await as('admin').post(`/projects/${first}/daily-work`, { ...work, workerIds: [] }).expect(400);

      const pay = { kind: 'worker', targetId: foreign, amountPaise: 1, date: '2026-10-22', method: 'cash' };
      await as('admin').post(`/projects/${first}/expense-payments`, pay).expect(404);
    });

    it('calculates material amounts itself, to the paisa', async () => {
      const id = await newProject();
      const material = { date: '2026-10-01', name: 'Paint', quantity: 3.3, unit: 'litres', ratePaise: 41_235, amountPaise: 1 };
      await as('admin').post(`/projects/${id}/materials`, material).expect(400); // No sending the amount.
      const { amountPaise: _ignored, ...good } = material;
      const { body } = await as('incharge').post(`/projects/${id}/materials`, good).expect(201);
      const saved = await app.get<Connection>(getConnectionToken()).collection('materials').findOne({ name: 'Paint' });
      expect(saved?.amountPaise).toBe(136_076);
      expect(body.materials[0]).toMatchObject({ name: 'Paint', quantity: 3.3, ratePaise: 41_235 });
    });

    it('a material cannot be edited below what is paid', async () => {
      const id = await newProject();
      const good = { date: '2026-10-01', name: 'Steel', quantity: 10, unit: 'kg', ratePaise: 1000 };
      const material = (await as('admin').post(`/projects/${id}/materials`, good).expect(201)).body.materials[0].id;
      await as('admin').post(`/projects/${id}/expense-payments`, { kind: 'material', targetId: material, amountPaise: 6000, date: '2026-10-02', method: 'upi' }).expect(201);

      const below = await as('admin').patch(`/projects/${id}/materials/${material}`, { ...good, quantity: 5 }).expect(409);
      expect(below.body).toEqual({ code: 'BELOW_PAID', message: '₹60 is already paid on this material.' });
      await as('admin').patch(`/projects/${id}/materials/${material}`, { ...good, quantity: 6 }).expect(200);
    });

    it('saves a bill with its items and file, together', async () => {
      const id = await newProject();
      const file = (await http.post('/api/v1/files').set(auth.incharge).attach('file', PDF, 'bill.pdf').expect(201)).body;
      const { body } = await as('incharge')
        .post(`/projects/${id}/material-bills`, {
          fileId: file.id,
          supplier: 'Visaka',
          billNumber: 'E-1',
          date: '2026-10-24',
          items: [
            { name: 'Switch', quantity: 72, unit: 'nos', ratePaise: 2350 },
            { name: 'Socket', quantity: 32, unit: 'nos', ratePaise: 9111 },
          ],
        })
        .expect(201);
      expect(body.bills[0]).toMatchObject({ supplier: 'Visaka', billNumber: 'E-1', file: { name: 'bill.pdf', contentType: 'application/pdf' } });
      expect(body.materials).toHaveLength(2);
      expect(body.materials[0]).toMatchObject({ billId: body.bills[0].id, supplier: 'Visaka', date: '2026-10-24' });

      const bad = { fileId: file.id, date: '2026-10-24', items: [] };
      await as('incharge').post(`/projects/${id}/material-bills`, bad).expect(400);
      await as('incharge').post(`/projects/${id}/material-bills`, { ...bad, fileId: '64b000000000000000000000', items: [{ name: 'X', quantity: 1, unit: 'nos', ratePaise: 1 }] }).expect(404);
    });
    const upload = async (bytes: Buffer, name = 'bill.pdf') =>
      (await http.post('/api/v1/files').set(auth.incharge).attach('file', bytes, name).expect(201)).body;
    const bill = (id: string, body: object) => as('incharge').post(`/projects/${id}/material-bills`, body);

    it('adds a material received again to its quantity, at the latest rate, keeping its history', async () => {
      const id = await newProject();
      await as('incharge').post(`/projects/${id}/materials`, { date: '2026-10-01', name: 'Cement', quantity: 10, unit: 'bags', ratePaise: 40_000 }).expect(201);
      const file = await upload(PDF);
      const items = [
        { name: '  cement ', quantity: 5, unit: 'bags', ratePaise: 42_000 },
        { name: 'Cement', quantity: 2, unit: 'kg', ratePaise: 100 }, // Another unit stays apart.
        { name: 'Sand', quantity: 2, unit: 'loads', ratePaise: 300_000 },
      ];
      const { body } = await bill(id, { fileId: file.id, supplier: 'Sri Ram', billNumber: 'C-9', date: '2026-10-05', items }).expect(201);

      expect(body.materials).toHaveLength(3);
      const cement = body.materials.find((m: { name: string; unit: string }) => m.name === 'Cement' && m.unit === 'bags');
      expect(cement).toMatchObject({ quantity: 15, ratePaise: 42_000, date: '2026-10-05', supplier: 'Sri Ram', billId: body.bills[0].id });
      expect(cement.history.map((h: { quantity: number; ratePaise: number; billNumber: string; billId: string | null }) => [h.quantity, h.ratePaise, h.billNumber, h.billId])).toEqual([
        [10, 40_000, '', null],
        [5, 42_000, 'C-9', body.bills[0].id],
      ]);
      expect(typeof cement.history[1].addedAt).toBe('string');
      const saved = await app.get<Connection>(getConnectionToken()).collection('materials').findOne({ _id: new Types.ObjectId(cement.id) });
      expect(saved?.amountPaise).toBe(630_000);
    });

    it('stops a bill scanned before, unless asked to save it again', async () => {
      const id = await newProject();
      const items = [{ name: 'Steel', quantity: 100, unit: 'kg', ratePaise: 6_500 }];
      const first = await upload(PDF);
      await bill(id, { fileId: first.id, supplier: 'Vizag Steels', billNumber: 'S-1', date: '2026-10-05', items }).expect(201);

      // The same file uploaded again.
      const again = await upload(PDF, 'copy.pdf');
      expect(again.sha256).toBe(first.sha256);
      const refused = await bill(id, { fileId: again.id, date: '2026-10-06', items }).expect(409);
      expect(refused.body.code).toBe('DUPLICATE_BILL');
      expect(refused.body.message).toMatch(/^This bill was already scanned on \d{1,2} \w{3} \d{4}\.$/);

      // Another photo of it: same bill number and supplier.
      const photo = await upload(Buffer.concat([PDF, Buffer.from(' % another copy')]));
      const sameNumber = { fileId: photo.id, supplier: ' vizag steels', billNumber: 's-1', date: '2026-10-06', items };
      expect((await bill(id, sameNumber).expect(409)).body.code).toBe('DUPLICATE_BILL');
      const { body } = await bill(id, { ...sameNumber, allowDuplicate: true }).expect(201);
      expect(body.bills).toHaveLength(2);
      expect(body.materials).toHaveLength(1);
      expect(body.materials[0]).toMatchObject({ quantity: 200 });
      expect(body.materials[0].history).toHaveLength(2);

      // Another house may have the same bill.
      const site = await newSite({ name: 'Other' });
      const other = (await as('sales').post('/bookings', withHouse(site.id, '1')).expect(201)).body;
      await as('admin').post(`/bookings/${other.id}/approve`).expect(200);
      await as('admin').post(`/projects/${other.id}/material-bills`, { fileId: first.id, date: '2026-10-07', items }).expect(201);
    });
  });

  describe('files', () => {
    it('stores and returns the same bytes, for signed-in staff only', async () => {
      await http.post('/api/v1/files').attach('file', PNG, 'map.png').expect(401);
      const { body } = await http.post('/api/v1/files').set(auth.admin).attach('file', PNG, 'map.png').expect(201);
      expect(body).toMatchObject({ name: 'map.png', contentType: 'image/png', size: PNG.length });

      await http.get(`/api/v1/files/${body.id}/content`).expect(401);
      const download = await http
        .get(`/api/v1/files/${body.id}/content`)
        .set(auth.sales)
        .buffer(true)
        .parse((res, done) => {
          const chunks: Buffer[] = [];
          res.on('data', (chunk: Buffer) => chunks.push(chunk));
          res.on('end', () => done(null, Buffer.concat(chunks)));
        })
        .expect(200);
      expect((download.body as Buffer).equals(PNG)).toBe(true);
      expect(download.headers['content-type']).toContain('image/png');
      expect(download.headers['content-disposition']).toContain('attachment');
    });

    const download = (id: string) =>
      http
        .get(`/api/v1/files/${id}/content`)
        .set(auth.admin)
        .buffer(true)
        .parse((res, done) => {
          const chunks: Buffer[] = [];
          res.on('data', (chunk: Buffer) => chunks.push(chunk));
          res.on('end', () => done(null, Buffer.concat(chunks)));
        })
        .expect(200);

    it('keeps the bytes in the database, not on the server disk', async () => {
      // Larger than one GridFS chunk, and than a 16 MB document would allow once in base64.
      const big = Buffer.concat([PDF, Buffer.alloc(17 * 1024 * 1024, 7)]);
      const { body } = await http.post('/api/v1/files').set(auth.admin).attach('file', big, 'big.pdf').expect(201);
      expect(((await download(body.id)).body as Buffer).equals(big)).toBe(true);

      const db = app.get<Connection>(getConnectionToken()).db!;
      const stored = await db.collection('files').findOne({ name: 'big.pdf' });
      expect(String(stored?.storageKey)).toMatch(/^db:[0-9a-f]{24}$/);
      expect(await db.collection('fileBytes.files').countDocuments({ length: big.length })).toBe(1);
      expect(await readdir(process.env.UPLOAD_DIR!)).toEqual([]);
    });

    it('Admins choose where new uploads go, and can move old files there', async () => {
      const settings = async () => (await as('admin').get('/settings/file-storage').expect(200)).body;
      const db = app.get<Connection>(getConnectionToken()).db!;
      const keyOf = async (id: string) =>
        String((await db.collection('files').findOne({ _id: new Types.ObjectId(id) }))?.storageKey);

      await as('sales').get('/settings/file-storage').expect(403);
      await as('manager').put('/settings/file-storage', { storage: 'folder' }).expect(403);
      expect((await settings()).storage).toBe('database');
      await as('admin').put('/settings/file-storage', { storage: 'cloud' }).expect(400);

      try {
        // Folder: the bytes go to the server's upload folder.
        expect((await as('admin').put('/settings/file-storage', { storage: 'folder' }).expect(200)).body.storage).toBe('folder');
        const inFolder = (await http.post('/api/v1/files').set(auth.admin).attach('file', PNG, 'a.png').expect(201)).body.id;
        const folderKey = await keyOf(inFolder);
        expect(folderKey).not.toMatch(/^db:/);
        expect(await readdir(process.env.UPLOAD_DIR!)).toContain(folderKey);
        expect(((await download(inFolder)).body as Buffer).equals(PNG)).toBe(true);

        // Back to the database: new files go there, the old one stays until moved.
        await as('admin').put('/settings/file-storage', { storage: 'database' }).expect(200);
        const inDatabase = (await http.post('/api/v1/files').set(auth.admin).attach('file', PDF, 'b.pdf').expect(201)).body.id;
        expect(await keyOf(inDatabase)).toMatch(/^db:/);
        const before = await settings();
        expect(before.folder).toEqual({ files: 1, bytes: PNG.length });
        expect(before.database.files).toBeGreaterThanOrEqual(1);

        const moved = (await as('admin').post('/settings/file-storage/move').expect(200)).body;
        expect(moved).toMatchObject({ moved: 1, failed: 0, storage: 'database', folder: { files: 0, bytes: 0 } });
        expect(await keyOf(inFolder)).toMatch(/^db:/);
        expect(await readdir(process.env.UPLOAD_DIR!)).not.toContain(folderKey);
        expect(((await download(inFolder)).body as Buffer).equals(PNG)).toBe(true);
      } finally {
        await as('admin').put('/settings/file-storage', { storage: 'database' }).expect(200);
      }
    });

    it('everyone sees the theme, font and text size an Admin picks, even before signing in', async () => {
      const before = (await http.get('/api/v1/settings/theme').expect(200)).body;
      expect(before).toMatchObject({ theme: 'sage', font: 'josefin', textSize: 'normal' });
      expect(before.themes).toEqual(['sage', 'ocean', 'indigo', 'terracotta', 'graphite', 'plum']);
      expect(before.fonts).toEqual(['josefin', 'poppins', 'serif', 'system']);
      await http.put('/api/v1/settings/theme').send({ theme: 'ocean' }).expect(401);
      await as('manager').put('/settings/theme', { theme: 'ocean' }).expect(403);
      await as('admin').put('/settings/theme', { theme: 'neon' }).expect(400);
      try {
        expect((await as('admin').put('/settings/theme', { theme: 'ocean' }).expect(200)).body.theme).toBe('ocean');
        expect((await http.get('/api/v1/settings/theme').expect(200)).body.theme).toBe('ocean');
        expect((await as('admin').get('/settings/file-storage').expect(200)).body.storage).toBe('database');

        // Font and text size change on their own, leaving the theme as it is.
        await as('admin').put('/settings/theme', { font: 'comic' }).expect(400);
        await as('admin').put('/settings/theme', { textSize: 'huge' }).expect(400);
        const text = (await as('admin').put('/settings/theme', { font: 'poppins', textSize: 'large' }).expect(200)).body;
        expect(text).toMatchObject({ theme: 'ocean', font: 'poppins', textSize: 'large' });
        expect((await http.get('/api/v1/settings/theme').expect(200)).body).toMatchObject({ font: 'poppins', textSize: 'large' });
      } finally {
        await as('admin').put('/settings/theme', { theme: 'sage', font: 'josefin', textSize: 'normal' }).expect(200);
      }
    });

    it('still opens files saved on disk before files moved into the database', async () => {
      await writeFile(join(process.env.UPLOAD_DIR!, 'old-key'), PNG);
      const db = app.get<Connection>(getConnectionToken()).db!;
      const { insertedId } = await db.collection('files').insertOne({
        storageKey: 'old-key', name: 'old.png', contentType: 'image/png', size: PNG.length, uploadedBy: new Types.ObjectId(), sha256: '',
      });
      expect(((await download(insertedId.toString())).body as Buffer).equals(PNG)).toBe(true);
    });

    it('goes by the content, not the name, and ignores folder tricks', async () => {
      const fake = Buffer.from('<script>alert(1)</script>');
      const refused = await http.post('/api/v1/files').set(auth.admin).attach('file', fake, 'bill.pdf').expect(400);
      expect(refused.body.code).toBe('UNSUPPORTED_FILE');
      await http.post('/api/v1/files').set(auth.admin).expect(400);

      const { body } = await http.post('/api/v1/files').set(auth.admin).attach('file', PDF, '..\\..\\evil.pdf').expect(201);
      expect(body.name).toBe('evil.pdf');
    });

    it('refuses files over 20 MB', async () => {
      const big = Buffer.concat([PDF, Buffer.alloc(20 * 1024 * 1024)]);
      const { body } = await http.post('/api/v1/files').set(auth.admin).attach('file', big, 'big.pdf').expect(413);
      expect(body.code).toBe('FILE_TOO_LARGE');
    });

    it('a site keeps its map and brochure, and can drop them', async () => {
      const map = (await http.post('/api/v1/files').set(auth.admin).attach('file', PNG, 'map.png')).body;
      const site = await newSite({ siteMapFileId: map.id });
      expect(site.siteMap).toMatchObject({ id: map.id, name: 'map.png' });
      expect(site.brochure).toBeNull();
      const { body } = await as('admin').patch(`/sites/${site.id}`, { ...siteBody, siteMapFileId: null }).expect(200);
      expect(body.siteMap).toBeNull();
    });
  });

  describe('leads', () => {
    const lead = { name: 'Suresh Babu', mobile: '98480 11111', source: 'walkIn', area: 'Gajuwaka', budgetPaise: 2_500_000_00, nextFollowUp: '2026-10-20' };

    it('Sales add leads and see only their own; Admins see all; site staff none', async () => {
      const site = await newSite();
      const { body } = await as('sales').post('/leads', { ...lead, siteId: site.id, interest: 'withConstruction' }).expect(201);
      expect(body).toMatchObject({ name: 'Suresh Babu', status: 'newLead', siteName: site.name, interest: 'withConstruction', ownerName: 'sales name', followUps: [] });
      await as('sales2').post('/leads', { ...lead, name: 'Other', mobile: '9000000002' }).expect(201);

      expect((await as('sales').get('/leads').expect(200)).body.items.map((l: { name: string }) => l.name)).toEqual(['Suresh Babu']);
      expect((await as('admin').get('/leads').expect(200)).body.items).toHaveLength(2);
      for (const who of ['manager', 'incharge']) await as(who).get('/leads').expect(403);
      expect((await as('sales2').patch(`/leads/${body.id}`, lead).expect(403)).body.code).toBe('FORBIDDEN');
    });

    it('checks details, and one lead per mobile number', async () => {
      expect((await as('sales').post('/leads', { ...lead, mobile: '123' }).expect(400)).body.code).toBe('VALIDATION_FAILED');
      await as('sales').post('/leads', { ...lead, source: 'tv' }).expect(400);
      await as('sales').post('/leads', { ...lead, email: 'not-an-email' }).expect(400);
      await as('sales').post('/leads', { ...lead, email: '' }).expect(201);
      const again = await as('sales2').post('/leads', { ...lead, name: 'Again', mobile: '+91 98480-11111' }).expect(409);
      expect(again.body).toEqual({ code: 'DUPLICATE_LEAD', message: 'Suresh Babu already has this mobile number, looked after by sales name.' });
    });

    it('editing keeps the follow-ups', async () => {
      const created = (await as('sales').post('/leads', lead).expect(201)).body;
      await as('sales').post(`/leads/${created.id}/follow-ups`, { date: '2026-10-10', mode: 'call', note: 'Asked for brochure', status: 'contacted', nextDate: '2026-10-15' }).expect(201);
      const { body } = await as('admin').patch(`/leads/${created.id}`, { ...lead, name: 'Suresh B', siteId: null, budgetPaise: null }).expect(200);
      expect(body).toMatchObject({ name: 'Suresh B', budgetPaise: null, status: 'contacted' });
      expect(body.followUps).toHaveLength(1);
    });

    it('converts a lead into a customer once, with the details added', async () => {
      const id = (await as('sales').post('/leads', { ...lead, email: 'suresh@example.com' }).expect(201)).body.id;
      const url = `/leads/${id}/convert`;
      const details = { name: 'Suresh Babu', mobile: '98480 11111', alternateMobile: '9000099999', address: '12-4, Gajuwaka, Vizag', occupation: 'Teacher' };

      await as('sales').post(url, { ...details, address: ' ' }).expect(400);
      await as('sales').post(url, { ...details, alternateMobile: '12' }).expect(400);
      await as('sales2').post(url, details).expect(403);

      const { body } = await as('sales').post(url, details).expect(200);
      expect(body.lead).toMatchObject({ status: 'won', nextFollowUp: null, customerId: body.customer.id });
      expect(typeof body.lead.convertedAt).toBe('string');
      expect(body.customer).toMatchObject({ ...details, leadId: id, source: 'walkIn', ownerName: 'sales name', email: '' });

      expect((await as('sales').post(url, details).expect(409)).body.code).toBe('ALREADY_CONVERTED');
      const customers = (await as('sales2').get('/customers').expect(200)).body.items;
      expect(customers.map((c: { name: string }) => c.name)).toEqual(['Suresh Babu']);
      await as('incharge').get('/customers').expect(403);

      // Another lead cannot become a second customer with the same number.
      const other = (await as('sales2').post('/leads', { ...lead, name: 'Other', mobile: '9000000003' }).expect(201)).body.id;
      const twice = await as('sales2').post(`/leads/${other}/convert`, { ...details, mobile: '+91 98480-11111' }).expect(409);
      expect(twice.body).toEqual({ code: 'DUPLICATE_CUSTOMER', message: 'Suresh Babu is already a customer with this mobile number.' });
    });

    it('follow-ups move the status and the next date', async () => {
      const id = (await as('sales').post('/leads', lead).expect(201)).body.id;
      const url = `/leads/${id}/follow-ups`;
      const first = { date: '2026-10-10', mode: 'call', note: 'Interested in east facing', status: 'interested', nextDate: '2026-10-12' };
      const { body } = await as('sales').post(url, first).expect(201);
      expect(body).toMatchObject({ status: 'interested', nextFollowUp: '2026-10-12' });
      expect(body.followUps[0]).toMatchObject({ ...first, by: 'sales name' });

      expect((await as('sales').post(url, { ...first, nextDate: '2026-10-09' }).expect(409)).body.code).toBe('NEXT_BEFORE_DATE');
      expect((await as('sales').post(url, { ...first, date: '2099-01-01', nextDate: null }).expect(409)).body.code).toBe('FUTURE_DATE');
      await as('sales').post(url, { ...first, note: ' ' }).expect(400);
      await as('sales').post(url, { ...first, mode: 'fax' }).expect(400);

      // Won: nothing more to follow up, whatever date was sent.
      const won = (await as('sales').post(url, { date: '2026-10-12', mode: 'siteVisit', note: 'Booked plot 12', status: 'won', nextDate: '2026-10-20' }).expect(201)).body;
      expect(won).toMatchObject({ status: 'won', nextFollowUp: null });
      expect(won.followUps.map((f: { status: string }) => f.status)).toEqual(['interested', 'won']);
    });
  });

  describe('bill reading', () => {
    const reader = async () => (await import('../src/bills/bill-reader.service.js')).BillReaderService;
    const reply = (json: object, stop_reason = 'end_turn') => ({
      beta: { messages: { create: async (params: Record<string, unknown>) => {
        sent.push(params);
        return { stop_reason, content: [{ type: 'text', text: JSON.stringify(json) }] };
      } } },
    });
    let sent: Record<string, unknown>[] = [];

    it('is off without an API key, and only for construction staff', async () => {
      const service = app.get(await reader());
      service.clientOverride = undefined;
      const saved = process.env.ANTHROPIC_API_KEY;
      delete process.env.ANTHROPIC_API_KEY;
      try {
        const file = (await http.post('/api/v1/files').set(auth.incharge).attach('file', PDF, 'bill.pdf').expect(201)).body;
        const off = await as('incharge').post('/bills/read', { fileId: file.id }).expect(503);
        expect(off.body.code).toBe('AI_READING_OFF');
        await as('sales').post('/bills/read', { fileId: file.id }).expect(403);
        await as('incharge').post('/bills/read', { fileId: 'nope' }).expect(400);
      } finally {
        if (saved !== undefined) process.env.ANTHROPIC_API_KEY = saved;
      }
    });

    it('sends the bill to Claude and returns its items to review', async () => {
      const service = app.get(await reader());
      sent = [];
      service.clientOverride = reply({
        supplier: 'Anbalaya Cotton Mills',
        billNumber: '353',
        date: '2026-09-03',
        total: 0,
        notes: 'Order form; no rates.',
        items: [
          { name: 'Karna Set - Full Sleeve - Size 36', quantity: 20, unit: 'nos', rate: 0, unclear: false },
          { name: 'Cement OPC 53', quantity: 200, unit: 'bags', rate: 380.5, unclear: false },
          { name: 'Sand', quantity: 2, unit: 'trucks', rate: 6500, unclear: true },
          { name: ' ', quantity: 1, unit: 'nos', rate: 1, unclear: false },
        ],
      }) as never;
      try {
        const file = (await http.post('/api/v1/files').set(auth.incharge).attach('file', PDF, 'scan.pdf').expect(201)).body;
        const { body } = await as('incharge').post('/bills/read', { fileId: file.id }).expect(200);
        expect(body).toEqual({
          supplier: 'Anbalaya Cotton Mills',
          billNumber: '353',
          date: '2026-09-03',
          totalPaise: null,
          notes: 'Order form; no rates.',
          lines: [
            { name: 'Karna Set - Full Sleeve - Size 36', quantity: 20, unit: 'nos', ratePaise: 0, needsCheck: true },
            { name: 'Cement OPC 53', quantity: 200, unit: 'bags', ratePaise: 38_050, needsCheck: false },
            { name: 'Sand', quantity: 2, unit: 'nos', ratePaise: 650_000, needsCheck: true },
          ],
        });

        // The PDF went as a document, with the model and strict JSON format.
        const params = sent[0] as { model: string; messages: { content: { type: string; source: { media_type: string } }[] }[]; output_config: { format: { type: string } } };
        expect(params.model).toBe('claude-opus-5-5');
        expect(params.messages[0].content[0]).toMatchObject({ type: 'document', source: { media_type: 'application/pdf' } });
        expect(params.output_config.format.type).toBe('json_schema');

        // A photo goes as an image.
        const photo = (await http.post('/api/v1/files').set(auth.incharge).attach('file', PNG, 'bill.png').expect(201)).body;
        await as('incharge').post('/bills/read', { fileId: photo.id }).expect(200);
        expect((sent[1] as typeof params).messages[0].content[0]).toMatchObject({ type: 'image', source: { media_type: 'image/png' } });

        service.clientOverride = reply({}, 'refusal') as never;
        expect((await as('incharge').post('/bills/read', { fileId: file.id }).expect(422)).body.code).toBe('BILL_NOT_READ');
        service.clientOverride = reply({}, 'max_tokens') as never;
        expect((await as('incharge').post('/bills/read', { fileId: file.id }).expect(422)).body.code).toBe('BILL_TOO_LONG');
      } finally {
        service.clientOverride = undefined;
      }
    });
  });
});
