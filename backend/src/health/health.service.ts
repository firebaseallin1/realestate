import { Injectable, Logger, OnApplicationBootstrap } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import type { Connection } from 'mongoose';

/**
 * Reports on the database. Bookings and payments need transactions, which
 * MongoDB only offers on a replica set or sharded cluster (Atlas always is).
 */
@Injectable()
export class HealthService implements OnApplicationBootstrap {
  private readonly logger = new Logger(HealthService.name);

  constructor(@InjectConnection() private readonly connection: Connection) {}

  async onApplicationBootstrap(): Promise<void> {
    // Rules such as "no double booking" rest on indexes, so requests must wait
    // for them. An index that cannot be built stops the server here, loudly.
    await Promise.all(Object.values(this.connection.models).map((model) => model.init()));

    const { supportsTransactions } = await this.check();
    if (supportsTransactions) {
      this.logger.log(`Connected to database "${this.connection.name}". Transactions are available.`);
    } else {
      this.logger.warn(
        `Connected to database "${this.connection.name}", but it does NOT support transactions. ` +
          'Bookings and payments need them: use MongoDB Atlas or a replica set before those modules go live.',
      );
    }
  }

  async check(): Promise<{ connected: boolean; supportsTransactions: boolean }> {
    const db = this.connection.db;
    if (this.connection.readyState !== 1 || !db) {
      return { connected: false, supportsTransactions: false };
    }
    const hello = await db.admin().command({ hello: 1 });
    return {
      connected: true,
      supportsTransactions: Boolean(hello.setName) || hello.msg === 'isdbgrid',
    };
  }
}
