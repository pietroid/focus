import {
  BadRequestException,
  Body,
  Controller,
  FileTypeValidator,
  Get,
  Param,
  ParseFilePipe,
  Post,
  UploadedFile,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import * as adminAuth from 'firebase-admin/auth';
import { CurrentUser } from '../auth/current-user.decorator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { CreateSubjectDto } from './dto/create-subject.dto';
import { Source } from './entities/source.entity';
import { Subject } from './entities/subject.entity';
import { SubjectsService } from './subjects.service';

interface CreateOverlayDto {
  x: number;
  y: number;
  text: string;
  color: string;
}

type DecodedIdToken = adminAuth.DecodedIdToken;

@Controller('subjects')
export class SubjectsController {
  constructor(private readonly subjectsService: SubjectsService) {}

  @Post()
  @UseGuards(FirebaseAuthGuard)
  async create(
    @CurrentUser() user: DecodedIdToken,
    @Body() dto: CreateSubjectDto,
  ): Promise<Subject> {
    return this.subjectsService.create(user.uid, dto);
  }

  @Get()
  @UseGuards(FirebaseAuthGuard)
  async findAll(@CurrentUser() user: DecodedIdToken): Promise<Subject[]> {
    return this.subjectsService.findAllByUser(user.uid);
  }

  @Post(':id/uploads')
  @UseGuards(FirebaseAuthGuard)
  @UseInterceptors(FileInterceptor('file'))
  async upload(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') subjectId: string,
    @UploadedFile(
      new ParseFilePipe({
        validators: [new FileTypeValidator({ fileType: 'pdf' })],
      }),
    )
    file: Express.Multer.File,
  ): Promise<Source> {
    if (!file) {
      throw new BadRequestException('No file provided');
    }

    return this.subjectsService.uploadPdf(user.uid, subjectId, file);
  }

  @Post(':id/last-opened-source')
  @UseGuards(FirebaseAuthGuard)
  async updateLastOpenedSource(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') subjectId: string,
    @Body('sourceId') sourceId: string,
  ): Promise<Subject> {
    if (!sourceId) {
      throw new BadRequestException('sourceId is required');
    }

    return this.subjectsService.updateLastOpenedSource(
      user.uid,
      subjectId,
      sourceId,
    );
  }

  @Post(':id/sources/:sourceId/overlays')
  @UseGuards(FirebaseAuthGuard)
  async addOverlay(
    @CurrentUser() user: DecodedIdToken,
    @Param('id') subjectId: string,
    @Param('sourceId') sourceId: string,
    @Body() dto: CreateOverlayDto,
  ): Promise<Subject> {
    if (dto.x == null || dto.y == null || !dto.text || !dto.color) {
      throw new BadRequestException('x, y, text and color are required');
    }

    return this.subjectsService.addOverlay(user.uid, subjectId, sourceId, dto);
  }
}
