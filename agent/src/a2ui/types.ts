/**
 * A2UI v0.9 component tree types.
 *
 * Every agent reply is a JSON object with a top-level `a2ui` field. The tree
 * uses a flat discriminator: `{ component: "Text", text: "..." }`.
 */

/** The set of components the agent is allowed to emit. */
export type ComponentName =
  | 'Column'
  | 'Row'
  | 'Spacer'
  | 'Text'
  | 'Icon'
  | 'Image'
  | 'AppButton'
  | 'AppIconButton';

/** One node in the A2UI tree. */
export interface A2uiComponent {
  component: ComponentName;
  children?: A2uiComponent[];
  // layout
  mainAxisAlignment?: string;
  crossAxisAlignment?: string;
  width?: number;
  height?: number;
  // content
  text?: string;
  variant?: string;
  icon?: string;
  size?: number;
  color?: string;
  src?: string;
  fit?: string;
  // AppButton
  expand?: boolean;
  // action
  action?: A2uiAction;
  // accessibility
  accessibilityLabel?: string;
  // allow unknown props to be stripped rather than crash
  [key: string]: unknown;
}

/** Actions emitted by interactive A2UI components. */
export type A2uiAction =
  | ToolAction
  | ReplyAction
  | DismissAction
  | OpenUrlAction;

/** Base fields every action carries. */
interface ActionBase {
  type: 'tool' | 'reply' | 'dismiss' | 'openUrl';
}

/** Call an agent tool. */
export interface ToolAction extends ActionBase {
  type: 'tool';
  tool: string;
  arguments?: Record<string, unknown>;
  requiresConfirmation?: boolean;
}

/** Send a pre-filled user message. */
export interface ReplyAction extends ActionBase {
  type: 'reply';
  text: string;
}

/** Close transient UI without sending anything. */
export interface DismissAction extends ActionBase {
  type: 'dismiss';
}

/** Open a URL. */
export interface OpenUrlAction extends ActionBase {
  type: 'openUrl';
  url: string;
}

/** The agent's reply payload. */
export interface A2uiReply {
  a2ui: A2uiComponent;
}

/** A2UI payload with optional pending tool call. */
export interface A2uiAgentResponse {
  a2ui: A2uiComponent;
  pendingToolCall?: ToolCall;
  solved?: boolean;
}

/** OpenRouter tool call representation. */
export interface ToolCall {
  id: string;
  type: 'function';
  function: {
    name: string;
    arguments: string; // JSON-encoded arguments
  };
}

/** OpenRouter tool definition. */
export interface ToolDefinition {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

/** OpenRouter chat message shape. */
export interface OpenRouterMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string;
  name?: string;
  tool_call_id?: string;
  tool_calls?: ToolCall[];
}

/** User context passed to tools. */
export interface UserContext {
  userId: string;
  slug: string;
}
