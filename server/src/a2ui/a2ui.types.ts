import { ThreadBucket } from '../threads/entities/thread.entity';

/**
 * A2UI: the component tree the server sends the app.
 *
 * The tree uses a flat discriminator (`{ component: "Text", text: "..." }`) so
 * it stays readable in a thread file and cheap for a model to produce.
 *
 * These types are owned by the server. The agent never sees them: it returns
 * text and tool results, and everything here is built, validated and repaired
 * on this side before it reaches the app.
 */

/** The components the app can draw. */
export type ComponentName =
  | 'Column'
  | 'Row'
  | 'Spacer'
  | 'Divider'
  | 'Text'
  | 'Icon'
  | 'Image'
  | 'Card'
  | 'Badge'
  | 'ListItem'
  | 'AppButton'
  | 'AppIconButton';

/**
 * A colour role, not a colour.
 *
 * The model picks by meaning and the app owns the hex, so the palette can
 * change without touching a prompt or a stored thread.
 */
export type ColorRole =
  | 'accent'
  | 'success'
  | 'info'
  | 'warning'
  | 'danger'
  | 'ink'
  | 'ink2'
  | 'ink3';

/** One node in the tree. */
export interface A2uiComponent {
  component: ComponentName;
  children?: A2uiComponent[];
  action?: A2uiAction;
  [key: string]: unknown;
}

/** Everything a component can ask the app to do. */
export type A2uiAction =
  | ReplyAction
  | ConfirmAction
  | DismissAction
  | OpenUrlAction
  | ThreadAction
  | TimingAction;

/** Send a message back into the thread, as if the user typed it. */
export interface ReplyAction {
  type: 'reply';
  text: string;
}

/**
 * The same as a reply, plus the user's permission to change something.
 *
 * This is the only way a write ever runs. The model proposes, describing the
 * change in full; the user taps; the turn that follows is allowed to execute,
 * once, without being asked again. The app needs to know nothing about it: it
 * posts the action like any other and the server does the rest.
 */
export interface ConfirmAction {
  type: 'confirm';
  /** Restates the whole action, because it becomes the user's next message. */
  text: string;
}

/** Close transient UI. Handled entirely in the app. */
export interface DismissAction {
  type: 'dismiss';
}

/** Open a link. Handled entirely in the app. */
export interface OpenUrlAction {
  type: 'openUrl';
  url: string;
}

/** Change the thread itself. The server does this without calling the agent. */
export interface ThreadAction {
  type: 'thread';
  op: ThreadOp;
  /** The new title, for `rename`. */
  title?: string;
}

/** What a [ThreadAction] can do. */
export type ThreadOp = 'solve' | 'reopen' | 'rename' | 'delete';

/**
 * Answers a guard: the move the user asked for, plus what they just decided
 * about it.
 *
 * The whole intent travels on every one of these, so a guard that asks two
 * questions is two round trips over the same object rather than a
 * conversation the server has to remember. There is no pending state on
 * either side, which means a guard abandoned halfway leaves nothing behind.
 *
 * A model never writes one of these: the type is not in [MODEL_ACTION_TYPES],
 * so the validator drops it out of a reply along with the button carrying it.
 * Guards are built by the server, from the calendar, with no model in the
 * loop at all.
 */
export interface TimingAction {
  type: 'timing';
  /** The thread being moved. */
  slug: string;
  /** The list it is being moved to. */
  bucket: ThreadBucket;
  /** Its place in that list, as the drop left it. */
  index: number;
  /** How long it takes, once a guard has asked. */
  durationMinutes?: number;
  /** The start being proposed, carried back so both sides agree on it. */
  startTime?: string;
  /** What the user decided. Absent means they have not been asked yet. */
  decision?: TimingDecision;
}

/**
 * What a guard's buttons say.
 *
 * - `schedule` books the proposed time on the calendar.
 * - `manual` keeps the move without a time, having learned the duration.
 * - `postpone` books it and pushes whatever it ran into later. The default.
 * - `force` books it on top of what is already there.
 * - `unschedule` takes it off the calendar and leaves it untimed.
 */
export type TimingDecision =
  'schedule' | 'manual' | 'postpone' | 'force' | 'unschedule';

/** Every decision, for validating one off the wire. */
export const TIMING_DECISIONS: TimingDecision[] = [
  'schedule',
  'manual',
  'postpone',
  'force',
  'unschedule',
];

/** What went wrong, or was quietly fixed, while validating a tree. */
export interface A2uiIssue {
  /** Dotted path to the node, e.g. `root.children[1]`. */
  path: string;
  /** `repair` was fixed in place; `reject` replaced the node. */
  severity: 'repair' | 'reject';
  message: string;
}

/** The outcome of validating a tree. */
export interface A2uiValidationResult {
  component: A2uiComponent;
  issues: A2uiIssue[];
  /** True when nothing had to be repaired or rejected. */
  clean: boolean;
}
