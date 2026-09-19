/**
 * Where the home screen's lists ended up after a drag.
 *
 * The app sends the full placement of every list a drag touched, not the one
 * thread that moved. A drop changes the index of everything below it in two
 * lists at once, so the result is the only thing that can be sent without the
 * server having to guess what the screen now looks like.
 */
export class PlacementsDto {
  placements?: {
    slug?: string;
    bucket?: string;
    /** The thread's zero-based place inside its bucket. */
    index?: number;
  }[];
}
