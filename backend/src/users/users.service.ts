import { HttpStatus, Injectable } from '@nestjs/common';
import { EventEmitter } from 'node:events';
import { InjectModel } from '@nestjs/mongoose';
import argon2 from 'argon2';
import { isValidObjectId } from 'mongoose';
import type { Model } from 'mongoose';
import { AppError } from '../common/app-error.js';
import { CreateUserDto, ListUsersDto, UpdateUserDto } from './dto/user.dto.js';
import { User, UserRole } from './user.schema.js';
import type { UserDocument } from './user.schema.js';

/** Raised when a user's sessions must end. Auth listens and revokes them. */
export const SESSIONS_ENDED = 'sessions-ended';

const isDuplicateKey = (error: unknown) => (error as { code?: number })?.code === 11000;

@Injectable()
export class UsersService extends EventEmitter {
  constructor(@InjectModel(User.name) private readonly users: Model<User>) {
    super();
  }

  async create(dto: CreateUserDto): Promise<UserDocument> {
    try {
      return await this.users.create({
        name: dto.name,
        username: dto.username,
        passwordHash: await argon2.hash(dto.password),
        role: dto.role,
        phone: dto.phone ?? '',
      });
    } catch (error) {
      if (isDuplicateKey(error)) {
        throw new AppError('USERNAME_TAKEN', `${dto.username} is already taken.`, HttpStatus.CONFLICT);
      }
      throw error;
    }
  }

  async list({ role, page, limit }: ListUsersDto) {
    const filter = { active: true, ...(role ? { role } : {}) };
    const [items, total] = await Promise.all([
      this.users
        .find(filter)
        .sort({ createdAt: 1 })
        .skip((page - 1) * limit)
        .limit(limit),
      this.users.countDocuments(filter),
    ]);
    return { items, total, page, limit };
  }

  /** [currentUserId] may change their own details but not their own role. */
  async update(id: string, dto: UpdateUserDto, currentUserId?: string): Promise<UserDocument> {
    const user = await this.findActiveOrThrow(id);
    if (id === currentUserId && dto.role !== undefined && dto.role !== user.role) {
      throw new AppError('CANNOT_CHANGE_OWN_ROLE', 'You cannot change your own role.', HttpStatus.CONFLICT);
    }
    if (dto.role && dto.role !== UserRole.admin && user.role === UserRole.admin) {
      await this.ensureAnotherAdmin(id);
    }

    if (dto.name !== undefined) user.name = dto.name;
    if (dto.phone !== undefined) user.phone = dto.phone;
    if (dto.role !== undefined) user.role = dto.role;
    if (dto.password !== undefined) user.passwordHash = await argon2.hash(dto.password);
    await user.save();

    // A new password signs them out everywhere.
    if (dto.password !== undefined) this.emit(SESSIONS_ENDED, id);
    return user;
  }

  /** Stops the user signing in, keeping their record for history. */
  async remove(id: string, currentUserId: string): Promise<void> {
    if (id === currentUserId) {
      throw new AppError('CANNOT_REMOVE_SELF', 'You cannot remove your own account.', HttpStatus.CONFLICT);
    }
    const user = await this.findActiveOrThrow(id);
    if (user.role === UserRole.admin) {
      throw new AppError(
        'CANNOT_REMOVE_ADMIN',
        'Admins cannot be removed. Change their role first if they no longer need Admin access.',
        HttpStatus.CONFLICT,
      );
    }
    user.active = false;
    await user.save();
    this.emit(SESSIONS_ENDED, id);
  }

  findActiveById(id: string) {
    return isValidObjectId(id) ? this.users.findOne({ _id: id, active: true }) : Promise.resolve(null);
  }

  /** The user with their password hash, for checking a sign-in. */
  findForLogin(username: string) {
    return this.users
      .findOne({ username: username.trim().toLowerCase(), active: true })
      .select('+passwordHash');
  }

  private async findActiveOrThrow(id: string): Promise<UserDocument> {
    const user = await this.findActiveById(id);
    if (!user) throw new AppError('USER_NOT_FOUND', 'This user no longer exists.', HttpStatus.NOT_FOUND);
    return user;
  }

  private async ensureAnotherAdmin(id: string): Promise<void> {
    const others = await this.users.countDocuments({ role: UserRole.admin, active: true, _id: { $ne: id } });
    if (others === 0) {
      throw new AppError('LAST_ADMIN', 'At least one Admin must remain.', HttpStatus.CONFLICT);
    }
  }
}
