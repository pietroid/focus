/**
 * Where a drag left a card.
 *
 * One number: its place in the day's single list, counting from the top. The
 * server turns that into hours for everything the drop disturbed.
 */
export class MoveDto {
  index?: number;
}
