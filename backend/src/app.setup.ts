import { INestApplication, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import helmet from 'helmet';
import { AllExceptionsFilter } from './common/all-exceptions.filter.js';
import type { Env } from './config/env.js';

/** Any port on this machine: `flutter run -d chrome` picks a new one each run. */
const localhostOrigin = /^http:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/;

/** Shared by the running server and the tests, so both behave the same. */
export function configureApp(app: INestApplication): void {
  const config = app.get<ConfigService<Env, true>>(ConfigService);
  const isProduction = config.get('NODE_ENV', { infer: true }) === 'production';
  const allowedOrigins = config.get('CORS_ORIGINS', { infer: true });

  app.use(helmet());
  app.enableCors({
    origin: (origin: string | undefined, callback: (error: Error | null, allow?: boolean) => void) => {
      // Mobile apps send no origin. Tokens travel in headers, not cookies.
      const allowed =
        !origin || allowedOrigins.includes(origin) || (!isProduction && localhostOrigin.test(origin));
      callback(null, allowed);
    },
  });
  app.setGlobalPrefix('api/v1');
  app.useGlobalFilters(new AllExceptionsFilter());
  app.useGlobalPipes(
    new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
  );
  app.enableShutdownHooks();
}
