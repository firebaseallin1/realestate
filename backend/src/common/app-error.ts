import { HttpException, HttpStatus } from '@nestjs/common';

/** A failure the app can act on: a stable [code] and a message for the user. */
export class AppError extends HttpException {
  constructor(
    readonly code: string,
    message: string,
    status: HttpStatus,
  ) {
    super(message, status);
  }
}
