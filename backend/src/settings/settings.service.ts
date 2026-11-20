import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import type { Model } from 'mongoose';
import { AppSettings } from './app-settings.schema.js';
import type { Appearance, FileStorage } from './app-settings.schema.js';

/**
 * SettingsService reads and changes the app-wide settings. They are kept in
 * memory after the first read, as every upload asks where to store files.
 */
@Injectable()
export class SettingsService {
  private cached?: { fileStorage: FileStorage } & Appearance;

  constructor(@InjectModel(AppSettings.name) private readonly settings: Model<AppSettings>) {}

  private async load() {
    if (!this.cached) {
      const doc = await this.settings.findOne({ key: 'app' });
      this.cached = {
        fileStorage: doc?.fileStorage ?? 'database',
        theme: doc?.theme ?? 'sage',
        font: doc?.font ?? 'josefin',
        textSize: doc?.textSize ?? 'normal',
      };
    }
    return this.cached;
  }

  /** Database unless an Admin chose the folder. */
  async fileStorage(): Promise<FileStorage> {
    return (await this.load()).fileStorage;
  }

  async setFileStorage(fileStorage: FileStorage): Promise<void> {
    await this.settings.updateOne({ key: 'app' }, { $set: { fileStorage } }, { upsert: true });
    (await this.load()).fileStorage = fileStorage;
  }

  /** Colour theme, font and text size: Sage, Josefin Sans, normal unless an Admin changed them. */
  async appearance(): Promise<Appearance> {
    const { theme, font, textSize } = await this.load();
    return { theme, font, textSize };
  }

  /** Changes only the parts given. */
  async setAppearance(changes: Partial<Appearance>): Promise<void> {
    const set = Object.fromEntries(Object.entries(changes).filter(([, value]) => value !== undefined));
    if (Object.keys(set).length === 0) return;
    await this.settings.updateOne({ key: 'app' }, { $set: set }, { upsert: true });
    Object.assign(await this.load(), set);
  }

  /** Forgets the cached value, e.g. after tests clear the database. */
  forget(): void {
    this.cached = undefined;
  }
}
