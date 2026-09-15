import { Overlay } from './overlay.entity';

export class Source {
  id: string;
  url: string;
  name: string;
  createdAt: Date;
  overlays: Overlay[];
}
