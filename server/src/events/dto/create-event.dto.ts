/** What the creation sheet posts when the user writes something down. */
export class CreateEventDto {
  title?: string;
  durationMinutes?: number;
  /** Whether the hour is the point of it. */
  fixed?: boolean;
  /** ISO 8601. Only a fixed block names one. */
  startTime?: string;
}
