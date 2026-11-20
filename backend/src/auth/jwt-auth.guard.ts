import { CanActivate, ExecutionContext, HttpStatus, Injectable } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { AppError } from '../common/app-error.js';
import { UsersService } from '../users/users.service.js';
import { IS_PUBLIC } from './public.decorator.js';

const notSignedIn = () => new AppError('UNAUTHORIZED', 'Please sign in again.', HttpStatus.UNAUTHORIZED);

/**
 * Requires a valid access token on every route not marked @Public(). The
 * user is read fresh each time, so removing someone or changing their role
 * takes effect at once rather than when the token expires.
 */
@Injectable()
export class JwtAuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly jwt: JwtService,
    private readonly users: UsersService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const targets = [context.getHandler(), context.getClass()];
    if (this.reflector.getAllAndOverride<boolean>(IS_PUBLIC, targets)) return true;

    const request = context.switchToHttp().getRequest();
    const [scheme, token] = String(request.headers.authorization ?? '').split(' ');
    if (scheme !== 'Bearer' || !token) throw notSignedIn();

    let userId: string;
    try {
      userId = (await this.jwt.verifyAsync<{ sub: string }>(token)).sub;
    } catch {
      throw notSignedIn();
    }

    const user = await this.users.findActiveById(userId);
    if (!user) throw notSignedIn();
    request.user = user;
    return true;
  }
}
