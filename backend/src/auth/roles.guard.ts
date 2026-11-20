import { CanActivate, ExecutionContext, HttpStatus, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AppError } from '../common/app-error.js';
import type { UserRole } from '../users/user.schema.js';
import { ROLES } from './roles.decorator.js';

/** Checks @Roles() on the server: hiding a menu in the app is not security. */
@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private readonly reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const roles = this.reflector.getAllAndOverride<UserRole[]>(ROLES, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!roles) return true;

    const { user } = context.switchToHttp().getRequest();
    if (user && roles.includes(user.role)) return true;
    throw new AppError('FORBIDDEN', 'You do not have access to this.', HttpStatus.FORBIDDEN);
  }
}
