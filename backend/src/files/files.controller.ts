import {
  BadRequestException,
  Controller,
  Get,
  Param,
  Post,
  StreamableFile,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { CurrentUser } from '../auth/current-user.decorator.js';
import type { UserDocument } from '../users/user.schema.js';
import { toFileJson } from './file.schema.js';
import { FilesService } from './files.service.js';

const MAX_SIZE = 20 * 1024 * 1024;

/** Files are for signed-in staff only: bills are private. */
@Controller('files')
export class FilesController {
  constructor(private readonly files: FilesService) {}

  @Post()
  @UseInterceptors(FileInterceptor('file', { limits: { fileSize: MAX_SIZE } }))
  async upload(
    @UploadedFile() file: { originalname: string; buffer: Buffer } | undefined,
    @CurrentUser() me: UserDocument,
  ) {
    if (!file) throw new BadRequestException('Please choose a file to upload.');
    return toFileJson(await this.files.upload(file.originalname, file.buffer, me.id as string));
  }

  @Get(':id/content')
  async content(@Param('id') id: string) {
    const { file, bytes } = await this.files.read(id);
    return new StreamableFile(bytes, {
      type: file.contentType,
      disposition: 'attachment',
      length: bytes.length,
    });
  }
}
