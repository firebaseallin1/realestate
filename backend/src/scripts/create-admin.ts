import { NestFactory } from '@nestjs/core';
import { createInterface } from 'node:readline';
import { AppModule } from '../app.module.js';
import { UserRole } from '../users/user.schema.js';
import { UsersService } from '../users/users.service.js';

/**
 * Creates the first Admin, as there is no public sign-up. Safe to run again:
 * it stops if the username is taken. The password comes from a prompt, or from
 * ADMIN_PASSWORD for automated setups, and is never printed.
 */
const lines = createInterface({ input: process.stdin })[Symbol.asyncIterator]();

// Reads line by line, so input piped in all at once is not lost between questions.
async function ask(question: string): Promise<string> {
  process.stdout.write(question);
  const { value } = await lines.next();
  return String(value ?? '').trim();
}

const name = await ask('Admin full name: ');
const username = await ask('Username: ');
const password = process.env.ADMIN_PASSWORD ?? (await ask('Password (at least 8 characters): '));

if (!name || !/^\S+$/.test(username) || password.length < 8) {
  console.error('A name, a username without spaces and a password of at least 8 characters are required.');
  process.exit(1);
}

const app = await NestFactory.createApplicationContext(AppModule, { logger: ['error'] });
let exitCode = 0;
try {
  const user = await app.get(UsersService).create({ name, username, password, role: UserRole.admin });
  console.log(`\nAdmin "${user.username}" created. You can now sign in.`);
} catch (error) {
  console.error(`\n${(error as Error).message}`);
  exitCode = 1;
} finally {
  await app.close();
}
process.exit(exitCode);
