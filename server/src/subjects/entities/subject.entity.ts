import { Source } from './source.entity';

export class Subject {
  id: string;
  name: string;
  createdAt: Date;
  userId: string;
  sources: Source[];
  lastOpenedSource: string | null;
}
