import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectConnection } from '@nestjs/mongoose';
import { randomUUID } from 'node:crypto';
import { mkdir, readFile, unlink, writeFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { mongo, Types } from 'mongoose';
import type { Connection } from 'mongoose';
import type { Env } from '../config/env.js';
import type { FileStorage } from '../settings/app-settings.schema.js';
import { SettingsService } from '../settings/settings.service.js';

/** Keys of files kept in the database start with this; folder keys are plain names. */
const IN_DATABASE = 'db:';

/**
 * Keeps file bytes where the Admin chose in Settings:
 * - database: MongoDB GridFS, raw binary chunks (no base64 growth, no 16 MB
 *   document limit). The server needs no disk, and database backups include
 *   the files.
 * - folder: the UPLOAD_DIR folder on the server, which must be a disk that
 *   survives restarts and deploys.
 *
 * A file is always read from where it was saved, whatever the setting is now.
 * Only this class knows where bytes live.
 */
@Injectable()
export class StorageService {
  private readonly folder: string;

  constructor(
    config: ConfigService<Env, true>,
    @InjectConnection() private readonly connection: Connection,
    private readonly settings: SettingsService,
  ) {
    this.folder = resolve(config.get('UPLOAD_DIR', { infer: true }));
  }

  /** Where the file with [key] is kept. */
  static storageOf(key: string): FileStorage {
    return key.startsWith(IN_DATABASE) ? 'database' : 'folder';
  }

  private bucket() {
    return new mongo.GridFSBucket(this.connection.db!, { bucketName: 'fileBytes' });
  }

  /** Stores the bytes where Settings say, under a new name never chosen by the uploader. */
  async save(bytes: Buffer): Promise<string> {
    return this.saveTo(await this.settings.fileStorage(), bytes);
  }

  async saveTo(storage: FileStorage, bytes: Buffer): Promise<string> {
    if (storage === 'folder') {
      await mkdir(this.folder, { recursive: true });
      const name = randomUUID();
      await writeFile(join(this.folder, name), bytes);
      return name;
    }
    const id = new Types.ObjectId();
    await new Promise<void>((done, fail) => {
      const upload = this.bucket().openUploadStreamWithId(id, id.toString());
      upload.once('finish', () => done()).once('error', fail);
      upload.end(bytes);
    });
    return `${IN_DATABASE}${id.toString()}`;
  }

  async read(key: string): Promise<Buffer> {
    if (StorageService.storageOf(key) === 'folder') return readFile(join(this.folder, key));
    const chunks: Buffer[] = [];
    for await (const chunk of this.bucket().openDownloadStream(this.databaseId(key))) {
      chunks.push(chunk as Buffer);
    }
    return Buffer.concat(chunks);
  }

  /** Deletes the bytes, e.g. the old copy after a file has moved. */
  async remove(key: string): Promise<void> {
    if (StorageService.storageOf(key) === 'folder') {
      await unlink(join(this.folder, key));
    } else {
      await this.bucket().delete(this.databaseId(key));
    }
  }

  private databaseId(key: string) {
    return new Types.ObjectId(key.slice(IN_DATABASE.length));
  }
}
