import { HttpStatus, Injectable, OnModuleInit } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectModel } from '@nestjs/mongoose';
import argon2 from 'argon2';
import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { Types } from 'mongoose';
import type { Model } from 'mongoose';
import { AppError } from '../common/app-error.js';
import { toPublicUser } from '../users/user.schema.js';
import type { UserDocument } from '../users/user.schema.js';
import { SESSIONS_ENDED, UsersService } from '../users/users.service.js';
import { RefreshToken } from './refresh-token.schema.js';

const REFRESH_DAYS = 30;

const hashToken = (token: string) => createHash('sha256').update(token).digest('hex');

@Injectable()
export class AuthService implements OnModuleInit {
  /** Checked when the username is unknown, so response time gives nothing away. */
  private decoyHash: Promise<string>;

  constructor(
    private readonly users: UsersService,
    private readonly jwt: JwtService,
    @InjectModel(RefreshToken.name) private readonly tokens: Model<RefreshToken>,
  ) {}

  onModuleInit(): void {
    this.decoyHash = argon2.hash(randomBytes(32).toString('hex'));
    this.users.on(SESSIONS_ENDED, (userId: string) => void this.revokeAll(userId));
  }

  async login(username: string, password: string) {
    const user = await this.users.findForLogin(username);
    const matches = await argon2.verify(user?.passwordHash ?? (await this.decoyHash), password);
    if (!user || !matches) {
      // The same answer for both, so usernames cannot be discovered.
      throw new AppError('INVALID_CREDENTIALS', 'Incorrect username or password.', HttpStatus.UNAUTHORIZED);
    }
    return this.issue(user, randomUUID());
  }

  /** Swaps a refresh token for a new pair. Each token works only once. */
  async refresh(token: string) {
    const tokenHash = hashToken(token);
    const now = new Date();
    const used = await this.tokens.findOneAndUpdate(
      { tokenHash, revokedAt: null, expiresAt: { $gt: now } },
      { revokedAt: now },
    );

    if (!used) {
      // An already-used token coming back means it may have been stolen.
      const replayed = await this.tokens.findOne({ tokenHash, revokedAt: { $ne: null } });
      if (replayed) {
        await this.tokens.updateMany({ familyId: replayed.familyId, revokedAt: null }, { revokedAt: now });
      }
      throw this.sessionEnded();
    }

    const user = await this.users.findActiveById(used.userId.toString());
    if (!user) throw this.sessionEnded();
    return this.issue(user, used.familyId);
  }

  async logout(token: string): Promise<void> {
    await this.tokens.updateOne({ tokenHash: hashToken(token), revokedAt: null }, { revokedAt: new Date() });
  }

  private async revokeAll(userId: string): Promise<void> {
    await this.tokens.updateMany(
      { userId: new Types.ObjectId(userId), revokedAt: null },
      { revokedAt: new Date() },
    );
  }

  private async issue(user: UserDocument, familyId: string) {
    const refreshToken = randomBytes(48).toString('base64url');
    await this.tokens.create({
      userId: user._id,
      familyId,
      tokenHash: hashToken(refreshToken),
      expiresAt: new Date(Date.now() + REFRESH_DAYS * 24 * 60 * 60 * 1000),
    });
    return {
      accessToken: await this.jwt.signAsync({ sub: user.id }),
      refreshToken,
      user: toPublicUser(user),
    };
  }

  private sessionEnded() {
    return new AppError('SESSION_ENDED', 'Please sign in again.', HttpStatus.UNAUTHORIZED);
  }
}
