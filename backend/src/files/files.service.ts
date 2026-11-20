import { createHash } from 'node:crypto';
import { HttpStatus, Injectable, Logger } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Types } from 'mongoose';
import type { Model } from 'mongoose';
import { AppError } from '../common/app-error.js';
import { StoredFile } from './file.schema.js';
import type { StoredFileDocument } from './file.schema.js';
import type { FileStorage } from '../settings/app-settings.schema.js';
import { StorageService } from './storage.service.js';

/** Works out the type from the bytes themselves: a name or header can lie. */
function detectType(bytes: Buffer): string | null {
  const ascii = (start: number, end: number) => bytes.subarray(start, end).toString('latin1');
  if (ascii(0, 5) === '%PDF-') return 'application/pdf';
  if (bytes.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (bytes.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]))) return 'image/jpeg';
  if (ascii(0, 4) === 'RIFF' && ascii(8, 12) === 'WEBP') return 'image/webp';
  if (ascii(0, 4) === 'GIF8') return 'image/gif';
  return null;
}

@Injectable()
export class FilesService {
  private readonly logger = new Logger(FilesService.name);

  constructor(
    @InjectModel(StoredFile.name) private readonly files: Model<StoredFile>,
    private readonly storage: StorageService,
  ) {}

  async upload(name: string, bytes: Buffer, uploadedBy: string): Promise<StoredFileDocument> {
    const contentType = detectType(bytes);
    if (!contentType) {
      throw new AppError('UNSUPPORTED_FILE', 'Please upload a PDF, JPG, PNG, WebP or GIF file.', HttpStatus.BAD_REQUEST);
    }
    // Kept only for display: strip any folder parts sent as part of the name.
    const safeName = name.split(/[\\/]/).pop()?.slice(0, 200) || 'file';
    return this.files.create({
      storageKey: await this.storage.save(bytes),
      name: safeName,
      contentType,
      size: bytes.length,
      uploadedBy: new Types.ObjectId(uploadedBy),
      sha256: createHash('sha256').update(bytes).digest('hex'),
    });
  }

  async read(id: string): Promise<{ file: StoredFileDocument; bytes: Buffer }> {
    const file = await this.findOrThrow(id);
    return { file, bytes: await this.storage.read(file.storageKey) };
  }

  async findOrThrow(id: string): Promise<StoredFileDocument> {
    const file = await this.files.findById(id);
    if (!file) throw new AppError('FILE_NOT_FOUND', 'This file no longer exists.', HttpStatus.NOT_FOUND);
    return file;
  }

  async findMany(ids: Types.ObjectId[]): Promise<Map<string, StoredFileDocument>> {
    if (ids.length === 0) return new Map();
    const files = await this.files.find({ _id: { $in: ids } });
    return new Map(files.map((file) => [file.id as string, file]));
  }

  /** How many files, and how many bytes, each storage holds. */
  async storageSummary() {
    const summary = { database: { files: 0, bytes: 0 }, folder: { files: 0, bytes: 0 } };
    for (const file of await this.files.find({}, { storageKey: 1, size: 1 })) {
      const place = summary[StorageService.storageOf(file.storageKey)];
      place.files += 1;
      place.bytes += file.size;
    }
    return summary;
  }

  /**
   * Moves every file kept elsewhere into [target], one at a time: copy,
   * point the record at the copy, then delete the old bytes. A file that
   * cannot be read is left where it is and counted as failed.
   */
  async moveAll(target: FileStorage) {
    let moved = 0;
    let failed = 0;
    for (const file of await this.files.find()) {
      const from = file.storageKey;
      if (StorageService.storageOf(from) === target) continue;
      try {
        file.storageKey = await this.storage.saveTo(target, await this.storage.read(from));
        await file.save();
        moved += 1;
      } catch (error) {
        this.logger.warn(`Could not move file ${file.id as string}: ${String(error)}`);
        failed += 1;
        continue;
      }
      // The record already points at the copy; a leftover old copy is harmless.
      await this.storage.remove(from).catch(() => undefined);
    }
    return { moved, failed };
  }
}
