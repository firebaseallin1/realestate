import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { Public } from '../auth/public.decorator.js';
import { HealthService } from './health.service.js';

@Controller('health')
export class HealthController {
  constructor(private readonly health: HealthService) {}

  @Public()
  @Get()
  async get() {
    const { connected, supportsTransactions } = await this.health.check();
    if (!connected) throw new ServiceUnavailableException('The database is not connected.');
    return { status: 'ok', database: 'connected', transactions: supportsTransactions };
  }
}
