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
  | DismissAction
  | OpenUrlAction
  | ThreadAction;

/** Send a message back into the thread, as if the user typed it. */
export interface ReplyAction {
  type: 'reply';
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
