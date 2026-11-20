import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { MongoMemoryReplSet } from 'mongodb-memory-server';
import request from 'supertest';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { getConnectionToken } from '@nestjs/mongoose';
import type { Connection } from 'mongoose';
import { validateEnv } from '../src/config/env.js';

const JWT_SECRET = 'test-secret-that-is-at-least-32-characters-long';
const PASSWORD = 'correct-horse';

describe('Auth and users', () => {
  let mongo: MongoMemoryReplSet;
  let app: INestApplication;
  let http: ReturnType<typeof request>;
  let tokens: Record<string, string>;
  let ids: Record<string, string>;

  async function startApp() {
    const { AppModule } = await import('../src/app.module.js');
    const { configureApp } = await import('../src/app.setup.js');
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    const nest = moduleRef.createNestApplication();
    configureApp(nest);
    await nest.init();
    return nest;
  }

  const bearer = (username: string) => ({ Authorization: `Bearer ${tokens[username]}` });

  const login = (username: string, password = PASSWORD) =>
    http.post('/api/v1/auth/login').send({ username, password });

  beforeAll(async () => {
    mongo = await MongoMemoryReplSet.create({ replSet: { count: 1 } });
    process.env.MONGODB_URI = mongo.getUri('kaira_test');
    process.env.JWT_SECRET = JWT_SECRET;
    process.env.NODE_ENV = 'test';
    process.env.LOGIN_RATE_LIMIT = '100000';
    app = await startApp();
    http = request(app.getHttpServer());
  }, 180_000);

  afterAll(async () => {
    await app?.close();
    await mongo?.stop();
  });

  beforeEach(async () => {
    const connection = app.get<Connection>(getConnectionToken());
    await connection.collection('users').deleteMany({});
    await connection.collection('refreshTokens').deleteMany({});

    const { UsersService } = await import('../src/users/users.service.js');
    const users = app.get(UsersService);
    tokens = {};
    ids = {};
    for (const [username, role] of [
      ['admin', 'admin'],
      ['sales', 'salesExecutive'],
      ['manager', 'siteManager'],
      ['incharge', 'siteIncharge'],
    ] as const) {
      const user = await users.create({ name: username, username, password: PASSWORD, role: role as never });
      ids[username] = user.id as string;
      tokens[username] = (await login(username).expect(200)).body.accessToken;
    }
  });

  describe('health and settings', () => {
    it('reports the database and that transactions work', async () => {
      const { body } = await http.get('/api/v1/health').expect(200);
      expect(body).toEqual({ status: 'ok', database: 'connected', transactions: true });
    });

    it('refuses bad settings, without printing the secret', () => {
      const good = { MONGODB_URI: 'mongodb://h/kaira_dev', JWT_SECRET };
      expect(validateEnv(good).MONGODB_URI).toBe(good.MONGODB_URI);
      expect(() => validateEnv({ JWT_SECRET })).toThrow('MONGODB_URI is missing');
      // No database name would silently write to "test".
      expect(() => validateEnv({ ...good, MONGODB_URI: 'mongodb+srv://u:p@h/?x=1' })).toThrow('must name the database');
      expect(() => validateEnv({ ...good, JWT_SECRET: 'short-secret' })).toThrow('JWT_SECRET');
      expect(() => validateEnv({ ...good, NODE_ENV: 'production' })).toThrow('CORS_ORIGINS');
      try {
        validateEnv({ MONGODB_URI: 'mongodb+srv://u:hunter2@h', JWT_SECRET: 'hunter3' });
      } catch (error) {
        expect((error as Error).message).not.toMatch(/hunter/);
      }
    });
  });

  describe('login', () => {
    it('returns tokens and the user, never the password hash', async () => {
      const { body } = await login('ADMIN ').expect(200);
      expect(body.accessToken).toBeTruthy();
      expect(body.refreshToken).toBeTruthy();
      expect(body.user).toEqual({ id: ids.admin, name: 'admin', username: 'admin', role: 'admin', phone: '' });
    });

    it('gives the same answer for a wrong password and an unknown user', async () => {
      const wrong = await login('admin', 'wrong-password').expect(401);
      const unknown = await login('nobody').expect(401);
      expect(wrong.body).toEqual({ code: 'INVALID_CREDENTIALS', message: 'Incorrect username or password.' });
      expect(unknown.body).toEqual(wrong.body);
    });

    it('stores a hash, not the password', async () => {
      const connection = app.get<Connection>(getConnectionToken());
      const stored = await connection.collection('users').findOne({ username: 'admin' });
      expect(stored?.passwordHash).toMatch(/^\$argon2/);
      expect(JSON.stringify(stored)).not.toContain(PASSWORD);
    });

    it('checks the shape of the request', async () => {
      const { body } = await http.post('/api/v1/auth/login').send({ username: 'admin' }).expect(400);
      expect(body.code).toBe('VALIDATION_FAILED');
      // An injection attempt is refused, not used as a query.
      await http.post('/api/v1/auth/login').send({ username: { $ne: null }, password: 'x' }).expect(400);
    });

    it('slows down repeated attempts', async () => {
      process.env.LOGIN_RATE_LIMIT = '3';
      try {
        const limited = await startApp();
        const client = request(limited.getHttpServer());
        for (let i = 0; i < 3; i++) {
          await client.post('/api/v1/auth/login').send({ username: 'admin', password: 'wrong-pass' }).expect(401);
        }
        const { body } = await client
          .post('/api/v1/auth/login')
          .send({ username: 'admin', password: 'wrong-pass' })
          .expect(429);
        expect(body.code).toBe('TOO_MANY_REQUESTS');
        await limited.close();
      } finally {
        process.env.LOGIN_RATE_LIMIT = '100000';
      }
    });
  });

  describe('access tokens', () => {
    it('requires one on protected routes', async () => {
      await http.get('/api/v1/auth/me').expect(401);
      await http.get('/api/v1/users').expect(401);
    });

    it('rejects forged and wrong-secret tokens', async () => {
      const { JwtService } = await import('@nestjs/jwt');
      const forged = new JwtService({ secret: 'a-completely-different-secret-value-here' }).sign({ sub: ids.admin });
      await http.get('/api/v1/auth/me').set('Authorization', `Bearer ${forged}`).expect(401);
      await http.get('/api/v1/auth/me').set('Authorization', 'Bearer not-a-token').expect(401);
      const unsigned = `${Buffer.from('{"alg":"none"}').toString('base64url')}.${Buffer.from(
        JSON.stringify({ sub: ids.admin }),
      ).toString('base64url')}.`;
      await http.get('/api/v1/auth/me').set('Authorization', `Bearer ${unsigned}`).expect(401);
    });

    it('identifies the user', async () => {
      const { body } = await http.get('/api/v1/auth/me').set(bearer('sales')).expect(200);
      expect(body.username).toBe('sales');
    });
  });

  describe('refresh tokens', () => {
    it('swaps for a new pair, once only', async () => {
      const { refreshToken } = (await login('sales')).body;
      const first = await http.post('/api/v1/auth/refresh').send({ refreshToken }).expect(200);
      expect(first.body.refreshToken).not.toBe(refreshToken);
      await http.get('/api/v1/auth/me').set('Authorization', `Bearer ${first.body.accessToken}`).expect(200);
    });

    it('ends the whole sign-in when a used token is replayed', async () => {
      const { refreshToken } = (await login('sales')).body;
      const next = (await http.post('/api/v1/auth/refresh').send({ refreshToken }).expect(200)).body;
      await http.post('/api/v1/auth/refresh').send({ refreshToken }).expect(401);
      await http.post('/api/v1/auth/refresh').send({ refreshToken: next.refreshToken }).expect(401);
    });

    it('allows only one of two simultaneous uses', async () => {
      const { refreshToken } = (await login('sales')).body;
      const results = await Promise.all([
        http.post('/api/v1/auth/refresh').send({ refreshToken }),
        http.post('/api/v1/auth/refresh').send({ refreshToken }),
      ]);
      expect(results.map((r) => r.status).sort()).toEqual([200, 401]);
    });

    it('stops working after logout and rejects made-up tokens', async () => {
      const { refreshToken } = (await login('sales')).body;
      await http.post('/api/v1/auth/logout').send({ refreshToken }).expect(204);
      await http.post('/api/v1/auth/refresh').send({ refreshToken }).expect(401);
      await http.post('/api/v1/auth/refresh').send({ refreshToken: 'made-up' }).expect(401);
    });

    it('is stored only as a hash', async () => {
      const { refreshToken } = (await login('sales')).body;
      const connection = app.get<Connection>(getConnectionToken());
      const all = await connection.collection('refreshTokens').find().toArray();
      expect(JSON.stringify(all)).not.toContain(refreshToken);
    });
  });

  describe('users', () => {
    const newUser = { name: 'Anil Kumar', username: 'Anil', password: 'secret12', role: 'siteIncharge', phone: '98480' };

    it('only Admins add, change and remove', async () => {
      for (const who of ['sales', 'manager', 'incharge']) {
        const denied = await http.post('/api/v1/users').set(bearer(who)).send(newUser).expect(403);
        expect(denied.body.code).toBe('FORBIDDEN');
        await http.patch(`/api/v1/users/${ids.sales}`).set(bearer(who)).send({ name: 'X' }).expect(403);
        await http.delete(`/api/v1/users/${ids.incharge}`).set(bearer(who)).expect(403);
      }
    });

    it('sales and incharges cannot list users; managers see only incharges', async () => {
      await http.get('/api/v1/users').set(bearer('sales')).expect(403);
      await http.get('/api/v1/users').set(bearer('incharge')).expect(403);

      const asManager = await http.get('/api/v1/users?role=admin').set(bearer('manager')).expect(200);
      expect(asManager.body.items.map((u: { username: string }) => u.username)).toEqual(['incharge']);

      const asAdmin = await http.get('/api/v1/users').set(bearer('admin')).expect(200);
      expect(asAdmin.body.total).toBe(4);
      expect(JSON.stringify(asAdmin.body)).not.toMatch(/password/i);

      const filtered = await http.get('/api/v1/users?role=salesExecutive').set(bearer('admin')).expect(200);
      expect(filtered.body.items.map((u: { username: string }) => u.username)).toEqual(['sales']);
    });

    it('adds a user who can sign in, with usernames ignoring case', async () => {
      const { body } = await http.post('/api/v1/users').set(bearer('admin')).send(newUser).expect(201);
      expect(body.username).toBe('anil');
      expect(JSON.stringify(body)).not.toMatch(/password|secret12/i);
      await login('ANIL', 'secret12').expect(200);

      const taken = await http.post('/api/v1/users').set(bearer('admin')).send(newUser).expect(409);
      expect(taken.body).toEqual({ code: 'USERNAME_TAKEN', message: 'Anil is already taken.' });
    });

    it('validates new users and ignores extra fields', async () => {
      const post = (body: object) => http.post('/api/v1/users').set(bearer('admin')).send(body);
      expect((await post({ ...newUser, password: 'short' }).expect(400)).body.message).toBe(
        'Password must be at least 8 characters.',
      );
      expect((await post({ ...newUser, username: 'has space' }).expect(400)).body.message).toBe(
        'Usernames cannot contain spaces.',
      );
      expect((await post({ ...newUser, role: 'superuser' }).expect(400)).body.message).toBe('Please select a role.');
      await post({ ...newUser, passwordHash: 'x' }).expect(400);
    });

    it('removing someone ends their access at once and keeps their record', async () => {
      const refreshToken = (await login('sales')).body.refreshToken;
      await http.delete(`/api/v1/users/${ids.sales}`).set(bearer('admin')).expect(204);

      await http.get('/api/v1/auth/me').set(bearer('sales')).expect(401);
      await new Promise((resolve) => setTimeout(resolve, 100));
      await http.post('/api/v1/auth/refresh').send({ refreshToken }).expect(401);
      await login('sales').expect(401);

      const list = await http.get('/api/v1/users').set(bearer('admin')).expect(200);
      expect(list.body.items.map((u: { username: string }) => u.username)).not.toContain('sales');

      const connection = app.get<Connection>(getConnectionToken());
      expect(await connection.collection('users').findOne({ username: 'sales' })).toMatchObject({ active: false });

      // The name stays reserved, so history cannot be confused with someone new.
      const again = await http.post('/api/v1/users').set(bearer('admin')).send({ ...newUser, username: 'sales' });
      expect(again.status).toBe(409);
    });

    it('protects your own account, Admins and the last Admin', async () => {
      const self = await http.delete(`/api/v1/users/${ids.admin}`).set(bearer('admin')).expect(409);
      expect(self.body.code).toBe('CANNOT_REMOVE_SELF');

      // You can edit your own details, but not your own role.
      const ownRole = await http.patch(`/api/v1/users/${ids.admin}`).set(bearer('admin')).send({ role: 'siteManager' }).expect(409);
      expect(ownRole.body.code).toBe('CANNOT_CHANGE_OWN_ROLE');
      await http.patch(`/api/v1/users/${ids.admin}`).set(bearer('admin')).send({ name: 'Head Admin', role: 'admin' }).expect(200);

      // Another Admin cannot be removed, only changed to another role.
      const second = (await http.post('/api/v1/users').set(bearer('admin')).send({ ...newUser, username: 'second', role: 'admin' }).expect(201)).body;
      const removeAdmin = await http.delete(`/api/v1/users/${second.id}`).set(bearer('admin')).expect(409);
      expect(removeAdmin.body.code).toBe('CANNOT_REMOVE_ADMIN');
      await http.patch(`/api/v1/users/${second.id}`).set(bearer('admin')).send({ role: 'siteManager' }).expect(200);
      await http.delete(`/api/v1/users/${second.id}`).set(bearer('admin')).expect(204);

      // The last Admin can never be demoted (checked directly: they cannot change their own role).
      const { UsersService } = await import('../src/users/users.service.js');
      const demote = app.get(UsersService).update(ids.admin, { role: 'siteManager' as never });
      await expect(demote).rejects.toMatchObject({ code: 'LAST_ADMIN' });
    });

    it('a role change applies at once, and a new password signs them out', async () => {
      await http.get('/api/v1/users').set(bearer('sales')).expect(403);
      await http.patch(`/api/v1/users/${ids.sales}`).set(bearer('admin')).send({ role: 'admin' }).expect(200);
      await http.get('/api/v1/users').set(bearer('sales')).expect(200);

      const { refreshToken } = (await login('incharge')).body;
      await http.patch(`/api/v1/users/${ids.incharge}`).set(bearer('admin')).send({ password: 'new-password' }).expect(200);
      await new Promise((resolve) => setTimeout(resolve, 100));
      await http.post('/api/v1/auth/refresh').send({ refreshToken }).expect(401);
      await login('incharge').expect(401);
      await login('incharge', 'new-password').expect(200);
    });

    it('answers cleanly for bad or unknown IDs', async () => {
      const bad = await http.patch('/api/v1/users/not-an-id').set(bearer('admin')).send({ name: 'X' }).expect(404);
      expect(bad.body.code).toBe('USER_NOT_FOUND');
      await http.delete('/api/v1/users/64b000000000000000000000').set(bearer('admin')).expect(404);
    });
  });

  describe('web access', () => {
    it('allows localhost in development and sets security headers', async () => {
      const res = await http.get('/api/v1/health').set('Origin', 'http://localhost:54321').expect(200);
      expect(res.headers['access-control-allow-origin']).toBe('http://localhost:54321');
      expect(res.headers['x-content-type-options']).toBe('nosniff');
    });

    it('does not allow other sites', async () => {
      const res = await http.get('/api/v1/health').set('Origin', 'https://evil.example').expect(200);
      expect(res.headers['access-control-allow-origin']).toBeUndefined();
    });
  });
});
