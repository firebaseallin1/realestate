import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { getModelToken } from '@nestjs/mongoose';
import type { Model } from 'mongoose';
import { AppModule } from '../app.module.js';
import { BookingsService } from '../bookings/bookings.service.js';
import type { Env } from '../config/env.js';
import { ProjectsService } from '../projects/projects.service.js';
import { Site } from '../sites/site.schema.js';
import { SitesService } from '../sites/sites.service.js';
import { User, UserRole } from '../users/user.schema.js';
import type { UserDocument } from '../users/user.schema.js';
import { UsersService } from '../users/users.service.js';

/**
 * Fills a development database with sample accounts and business data, going
 * through the same services as the app. It refuses to run in production, never
 * changes an account that already exists, and adds the business data only if
 * the database has no sites yet.
 */
const PASSWORD = 'kaira123';
const accounts = [
  { name: 'Admin', username: 'admin', role: UserRole.admin, phone: '98480 11111' },
  { name: 'Priya Sharma', username: 'sales', role: UserRole.salesExecutive, phone: '98480 22222' },
  { name: 'Ravi Kumar', username: 'manager', role: UserRole.siteManager, phone: '98480 33333' },
  { name: 'Suresh Reddy', username: 'incharge', role: UserRole.siteIncharge, phone: '98480 44444' },
];

const site = (name: string, location: string, type: string, status: string, totalUnits: number, soldUnits = 0, bookedUnits = 0) => ({
  name,
  location,
  type,
  status,
  totalUnits,
  soldUnits,
  bookedUnits,
  totalArea: 0,
  salesArea: 0,
  roadArea: 0,
  gardenArea: 0,
  otherArea: 0,
});

const app = await NestFactory.createApplicationContext(AppModule, { logger: ['error'] });

// Read here, as this is what the server itself would use, including .env.
if (app.get<ConfigService<Env, true>>(ConfigService).get('NODE_ENV', { infer: true }) === 'production') {
  console.error('The sample data must not be added in production.');
  await app.close();
  process.exit(1);
}

const users = app.get(UsersService);
const userModel = app.get<Model<User>>(getModelToken(User.name));

for (const account of accounts) {
  if (await userModel.exists({ username: account.username })) {
    console.log(`${account.username}: already there, left as it is`);
  } else {
    await users.create({ ...account, password: PASSWORD });
    console.log(`${account.username}: added`);
  }
}
console.log(`Sample password: ${PASSWORD}`);

const siteModel = app.get<Model<Site>>(getModelToken(Site.name));
if ((await siteModel.estimatedDocumentCount()) > 0) {
  console.log('Sites already exist, so no sample business data was added.');
} else {
  const find = async (username: string) => (await userModel.findOne({ username })) as UserDocument;
  const sales = await find('sales');
  const incharge = await find('incharge');
  const manager = await find('manager');

  const sites = app.get(SitesService);
  const bookings = app.get(BookingsService);
  const projects = app.get(ProjectsService);

  const meadows = await sites.createSite(site('Kaira Green Meadows', 'Hyderabad', 'plots', 'active', 240, 168, 22));
  await sites.createSite(site('Kaira Skyline Towers', 'Hyderabad', 'apartments', 'active', 320, 141, 36));
  await sites.createSite(site('Kaira Lake View Villas', 'Hyderabad', 'villas', 'upcoming', 64, 0, 18));
  await sites.createSite(site('Kaira Orchid Enclave', 'Bengaluru', 'apartments', 'active', 280, 196, 30));
  await sites.createSite(site('Kaira Tech Park Plaza', 'Bengaluru', 'commercial', 'upcoming', 90, 0, 12));
  await sites.createSite(site('Kaira Coastal Residency', 'Chennai', 'apartments', 'completed', 180, 180));
  const riverFront = await sites.createSite(site('Kaira River Front Plots', 'Vijayawada', 'plots', 'active', 150, 64, 21));

  const plotOnly = await bookings.create(
    {
      siteId: meadows.id,
      plotNumber: '12',
      plotSize: '30 × 40 ft',
      facing: 'east',
      customer: { name: 'Ramesh Naidu', mobile: '9849012345', email: 'ramesh@example.com' },
      type: 'withoutConstruction',
      plans: [{ part: 'plot', valuePaise: 180_000_000, mode: 'fullPayment' }],
    },
    sales,
  );
  await bookings.approve(plotOnly.id);
  await bookings.addPayment(plotOnly.id, { part: 'plot', amountPaise: 50_000_000, date: '2026-09-02', method: 'cash', reference: 'Token advance' }, sales);

  const pending = await bookings.create(
    {
      siteId: riverFront.id,
      plotNumber: '5',
      plotSize: '40 × 60 ft',
      facing: 'north',
      customer: { name: 'Lakshmi Prasanna', mobile: '9000011122', address: 'Benz Circle, Vijayawada' },
      type: 'withConstruction',
      plans: [
        { part: 'plot', valuePaise: 150_000_000, mode: 'loan', loan: { bankName: 'SBI', amountPaise: 100_000_000, reference: 'SBI-HL-55120', status: 'sanctioned' } },
        { part: 'construction', valuePaise: 350_000_000, mode: 'loan', loan: { bankName: 'HDFC Bank', amountPaise: 280_000_000, status: 'applied' } },
      ],
      // Paid at booking; later payments wait for approval.
      initialPayments: [{ part: 'plot', amountPaise: 50_000_000, date: '2026-10-14', method: 'bankTransfer', reference: 'NEFT 8812' }],
    },
    sales,
  );

  const house = await bookings.create(
    {
      siteId: meadows.id,
      plotNumber: '27',
      plotSize: '40 × 50 ft',
      facing: 'west',
      customer: { name: 'Kiran Varma', mobile: '9876543210' },
      type: 'withConstruction',
      plans: [
        { part: 'plot', valuePaise: 200_000_000, mode: 'fullPayment' },
        { part: 'construction', valuePaise: 400_000_000, mode: 'fullPayment' },
      ],
    },
    sales,
  );
  await bookings.approve(house.id);
  await bookings.addPayment(house.id, { part: 'plot', amountPaise: 200_000_000, date: '2026-08-20', method: 'cheque', reference: 'CHQ 004512' }, sales);
  await bookings.addPayment(house.id, { part: 'construction', amountPaise: 100_000_000, date: '2026-09-25', method: 'upi' }, sales);

  // The house under construction, assigned to the sample Site Incharge.
  let project = await projects.assignIncharge(house.id, incharge.id as string, manager);
  const stage = (index: number) => project.stages[index].id;
  await projects.updateStage(house.id, stage(0), { status: 'completed', progress: 100 }, manager);
  await projects.updateStage(house.id, stage(1), { status: 'completed', progress: 100 }, manager);
  await projects.updateStage(house.id, stage(2), { status: 'inProgress', progress: 60, note: 'Ground floor walls done, first floor started' }, manager);

  for (const worker of [
    { name: 'Raju', trade: 'mason', dailyWagePaise: 90_000, phone: '9000012345' },
    { name: 'Venkatesh', trade: 'mason', dailyWagePaise: 90_000 },
    { name: 'Lakshmi', trade: 'helper', dailyWagePaise: 60_000 },
    { name: 'Srinu', trade: 'barBender', dailyWagePaise: 80_000 },
  ]) {
    project = await projects.addWorker(house.id, worker, incharge);
  }
  const [raju, venkatesh, lakshmi, srinu] = project.workers.map((worker) => worker.id);

  await projects.addDailyWork(house.id, { date: '2026-10-20', stageId: stage(2), description: 'Brickwork on ground floor east side', workerIds: [raju, venkatesh, lakshmi] }, incharge);
  await projects.addDailyWork(house.id, { date: '2026-10-21', stageId: stage(2), description: 'Ground floor walls completed, lintel steel tied', workerIds: [raju, venkatesh, lakshmi, srinu] }, incharge);
  await projects.addDailyWork(house.id, { date: '2026-10-22', stageId: stage(2), description: 'First floor brickwork started', workerIds: [raju, lakshmi] }, incharge);

  for (const material of [
    { date: '2026-09-28', name: 'Cement (OPC 53)', quantity: 200, unit: 'bags', ratePaise: 38_000, supplier: 'Sri Sai Traders' },
    { date: '2026-09-30', name: 'TMT Steel', quantity: 2500, unit: 'kg', ratePaise: 6_200, supplier: 'Vizag Steels Dealer' },
    { date: '2026-10-15', name: 'Red Bricks', quantity: 20000, unit: 'nos', ratePaise: 800, supplier: 'Lakshmi Bricks' },
    { date: '2026-10-16', name: 'River Sand', quantity: 10, unit: 'loads', ratePaise: 650_000 },
  ]) {
    project = await projects.addMaterial(house.id, material, incharge);
  }
  const [cement, steel, bricks] = project.materials.map((material) => material.id);

  const pay = (kind: string, targetId: string, amountPaise: number, date: string, method: string, reference?: string) =>
    projects.addExpensePayment(house.id, { kind, targetId, amountPaise, date, method, reference }, incharge);
  await pay('material', cement, 7_600_000, '2026-09-28', 'bankTransfer', 'NEFT 1102');
  await pay('material', steel, 10_000_000, '2026-10-01', 'cheque', 'CHQ 778201');
  await pay('material', bricks, 16_000_000, '2026-10-15', 'upi');
  await pay('worker', raju, 180_000, '2026-10-21', 'cash');
  await pay('worker', lakshmi, 120_000, '2026-10-21', 'cash');

  console.log('Sample sites, bookings and construction added.');
}

await app.close();
process.exit(0);
