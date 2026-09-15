import { Injectable } from '@nestjs/common';
import { getStorage } from 'firebase-admin/storage';
import {
  DocumentSnapshot,
  FieldValue,
  getFirestore,
  Timestamp,
} from 'firebase-admin/firestore';
import { CreateSubjectDto } from './dto/create-subject.dto';
import { Overlay } from './entities/overlay.entity';
import { Source } from './entities/source.entity';
import { Subject } from './entities/subject.entity';

function overlayFromData(data: Record<string, unknown>): Overlay {
  return {
    id: data['id'] as string,
    x: data['x'] as number,
    y: data['y'] as number,
    text: data['text'] as string,
    color: data['color'] as string,
    createdAt: (data['createdAt'] as Timestamp).toDate(),
  };
}

function sourceFromData(data: Record<string, unknown>): Source {
  const rawOverlays = (data['overlays'] as Record<string, unknown>[]) ?? [];

  return {
    id: data['id'] as string,
    url: data['url'] as string,
    name: data['name'] as string,
    createdAt: (data['createdAt'] as Timestamp).toDate(),
    overlays: rawOverlays.map((overlay) => overlayFromData(overlay)),
  };
}

function snapshotToSubject(
  snapshot: DocumentSnapshot,
  userId: string,
): Subject {
  const data = snapshot.data() as Record<string, unknown>;
  const rawSources = (data['sources'] as Record<string, unknown>[]) ?? [];

  return {
    id: snapshot.id,
    name: data['name'] as string,
    userId,
    createdAt: (data['createdAt'] as Timestamp).toDate(),
    sources: rawSources.map((source) => sourceFromData(source)),
    lastOpenedSource: (data['lastOpenedSource'] as string) ?? null,
  };
}

@Injectable()
export class SubjectsService {
  private readonly _collection = getFirestore().collection('subjects');

  async create(userId: string, dto: CreateSubjectDto): Promise<Subject> {
    const subject: Omit<Subject, 'id'> = {
      name: dto.name,
      userId,
      createdAt: Timestamp.now().toDate(),
      sources: [],
      lastOpenedSource: null,
    };

    const ref = await this._collection.add(subject);
    const snapshot = await ref.get();

    return snapshotToSubject(snapshot, userId);
  }

  async findAllByUser(userId: string): Promise<Subject[]> {
    const snapshot = await this._collection
      .where('userId', '==', userId)
      .orderBy('createdAt', 'asc')
      .get();

    return snapshot.docs.map((doc) => snapshotToSubject(doc, userId));
  }

  async uploadPdf(
    userId: string,
    subjectId: string,
    file: Express.Multer.File,
  ): Promise<Source> {
    const bucketName = process.env.FIREBASE_STORAGE_BUCKET;
    const bucket = bucketName
      ? getStorage().bucket(bucketName)
      : getStorage().bucket();
    const filename = `uploads/${userId}/${subjectId}/${Date.now()}_${file.originalname}`;
    const bucketFile = bucket.file(filename);

    await bucketFile.save(file.buffer, {
      contentType: 'application/pdf',
      metadata: {
        contentDisposition: 'inline',
      },
    });

    const [url] = await bucketFile.getSignedUrl({
      action: 'read',
      expires: Date.now() + 10 * 365 * 24 * 60 * 60 * 1000, // 10 years
    });

    const source: Source = {
      id: crypto.randomUUID(),
      url,
      name: file.originalname,
      createdAt: new Date(),
      overlays: [],
    };

    const subjectRef = this._collection.doc(subjectId);
    await subjectRef.update({
      sources: FieldValue.arrayUnion(source),
      lastOpenedSource: source.id,
    });

    return source;
  }

  async updateLastOpenedSource(
    userId: string,
    subjectId: string,
    sourceId: string,
  ): Promise<Subject> {
    const subjectRef = this._collection.doc(subjectId);
    await subjectRef.update({
      lastOpenedSource: sourceId,
    });

    const snapshot = await subjectRef.get();
    return snapshotToSubject(snapshot, userId);
  }

  async addOverlay(
    userId: string,
    subjectId: string,
    sourceId: string,
    overlay: Omit<Overlay, 'id' | 'createdAt'>,
  ): Promise<Subject> {
    const subjectRef = this._collection.doc(subjectId);
    const subjectSnapshot = await subjectRef.get();
    const subject = snapshotToSubject(subjectSnapshot, userId);

    const sourceIndex = subject.sources.findIndex((s) => s.id === sourceId);
    if (sourceIndex === -1) {
      throw new Error('Source not found');
    }

    const newOverlay: Overlay = {
      id: crypto.randomUUID(),
      x: overlay.x,
      y: overlay.y,
      text: overlay.text,
      color: overlay.color,
      createdAt: new Date(),
    };

    const updatedSources = [...subject.sources];
    updatedSources[sourceIndex] = {
      ...updatedSources[sourceIndex],
      overlays: [...updatedSources[sourceIndex].overlays, newOverlay],
    };

    await subjectRef.update({
      sources: updatedSources,
    });

    const updatedSnapshot = await subjectRef.get();
    return snapshotToSubject(updatedSnapshot, userId);
  }
}
