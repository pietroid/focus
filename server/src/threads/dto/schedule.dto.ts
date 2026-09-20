/**
 * What the creation sheet on Tempo sends.
 *
 * Everything the timeline needs to give something an hour, and nothing else.
 * A flexible block leaves [startTime] out and gets the first gap that fits; a
 * fixed one names the hour the user picked.
 */
export class ScheduleDto {
  message?: string;
  durationMinutes?: number;
  fixed?: boolean;
  startTime?: string;
}
