/**
 * A guard's answer, as the app sends it back.
 *
 * The same object the guard's button carried, posted verbatim. The app does
 * not read it, build it, or decide what it means: it draws the button the
 * server sent and returns what was tapped.
 */
export class TimingDto {
  action?: {
    type?: string;
    slug?: string;
    bucket?: string;
    index?: number;
    durationMinutes?: number;
    startTime?: string;
    decision?: string;
  };
}
