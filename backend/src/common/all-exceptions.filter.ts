import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import type { Response } from 'express';
import { AppError } from './app-error.js';

const codeForStatus: Record<number, string> = {
  400: 'VALIDATION_FAILED',
  401: 'UNAUTHORIZED',
  403: 'FORBIDDEN',
  404: 'NOT_FOUND',
  409: 'CONFLICT',
  413: 'FILE_TOO_LARGE',
  429: 'TOO_MANY_REQUESTS',
};

/** Gives every error the same shape: { code, message }. */
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<Response>();
    const { status, code, message } = this.describe(exception);
    response.status(status).json({ code, message });
  }

  private describe(exception: unknown): { status: number; code: string; message: string } {
    if (exception instanceof AppError) {
      return { status: exception.getStatus(), code: exception.code, message: exception.message };
    }

    if (exception instanceof HttpException) {
      const status = exception.getStatus();
      const body = exception.getResponse();
      // Validation failures list their problems; the first is enough to act on.
      const raw = typeof body === 'object' ? (body as { message?: string | string[] }).message : body;
      const message = (Array.isArray(raw) ? raw[0] : raw) ?? exception.message;
      if (status === 429) {
        return { status, code: codeForStatus[429], message: 'Too many attempts. Please wait a minute and try again.' };
      }
      return { status, code: codeForStatus[status] ?? 'REQUEST_FAILED', message };
    }

    // A malformed ID in the address simply matches nothing.
    if ((exception as { name?: string })?.name === 'CastError') {
      return { status: HttpStatus.NOT_FOUND, code: codeForStatus[404], message: 'This record no longer exists.' };
    }

    // Unexpected: log it in full, and tell the caller nothing about internals.
    this.logger.error(exception instanceof Error ? exception.stack : String(exception));
    return {
      status: HttpStatus.INTERNAL_SERVER_ERROR,
      code: 'INTERNAL_ERROR',
      message: 'Something went wrong. Please try again.',
    };
  }
}
