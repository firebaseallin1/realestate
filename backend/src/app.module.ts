import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { MongooseModule } from '@nestjs/mongoose';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module.js';
import { JwtAuthGuard } from './auth/jwt-auth.guard.js';
import { RolesGuard } from './auth/roles.guard.js';
import { BillsModule } from './bills/bills.module.js';
import { BookingsModule } from './bookings/bookings.module.js';
import { CustomersModule } from './customers/customers.module.js';
import { validateEnv } from './config/env.js';
import type { Env } from './config/env.js';
import { FilesModule } from './files/files.module.js';
import { HealthModule } from './health/health.module.js';
import { LeadsModule } from './leads/leads.module.js';
import { ProjectsModule } from './projects/projects.module.js';
import { SitesModule } from './sites/sites.module.js';
import { UsersModule } from './users/users.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true, validate: validateEnv }),
    MongooseModule.forRootAsync({
      inject: [ConfigService],
      useFactory: (config: ConfigService<Env, true>) => ({
        uri: config.get('MONGODB_URI', { infer: true }),
        serverSelectionTimeoutMS: 10_000,
      }),
    }),
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 600 }]),
    HealthModule,
    UsersModule,
    AuthModule,
    FilesModule,
    SitesModule,
    ProjectsModule,
    BookingsModule,
    LeadsModule,
    CustomersModule,
    BillsModule,
  ],
  providers: [
    // Every route needs a signed-in user unless it is marked @Public().
    { provide: APP_GUARD, useClass: ThrottlerGuard },
    { provide: APP_GUARD, useClass: JwtAuthGuard },
    { provide: APP_GUARD, useClass: RolesGuard },
  ],
})
export class AppModule {}
