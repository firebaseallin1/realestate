import { SetMetadata } from '@nestjs/common';
import type { UserRole } from '../users/user.schema.js';

export const ROLES = 'roles';

/** Limits a controller or route to these roles. A route's list wins over its controller's. */
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES, roles);
