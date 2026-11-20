import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/** The signed-in user, loaded by JwtAuthGuard. */
export const CurrentUser = createParamDecorator(
  (_: unknown, context: ExecutionContext) => context.switchToHttp().getRequest().user,
);
