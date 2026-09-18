import { Injectable } from '@nestjs/common';

/** A2UI component node. */
export interface A2uiComponent {
  component: string;
  children?: A2uiComponent[];
  [key: string]: unknown;
}

/** Allowed component names in the backend catalog. */
export const ALLOWED_COMPONENTS = [
  'Column',
  'Row',
  'Spacer',
  'Text',
  'Icon',
  'Image',
  'AppButton',
  'AppIconButton',
];

/** Allowed tool names referenced by A2UI actions. */
export const ALLOWED_TOOLS = [
  'web_search',
  'calendar_check_availability',
  'calendar_create_event',
  'api_call',
];

/** Action shape carried by interactive components. */
export interface A2uiAction {
  type: 'tool' | 'reply' | 'dismiss' | 'openUrl';
  tool?: string;
  arguments?: Record<string, unknown>;
  requiresConfirmation?: boolean;
  /** Internal ID used by the backend to resume a pending tool call. */
  _toolCallId?: string;
  text?: string;
  url?: string;
}

/** Fallback tree used when validation fails. */
export const FALLBACK_A2UI: A2uiComponent = {
  component: 'Text',
  text: "I'm unable to render this reply right now. Please try again.",
};

/**
 * Validates A2UI trees returned by the agent before they are stored.
 */
@Injectable()
export class A2uiValidationService {
  validate(reply: unknown): { valid: boolean; component: A2uiComponent } {
    if (reply === null || typeof reply !== 'object') {
      return { valid: false, component: FALLBACK_A2UI };
    }

    const obj = reply as Record<string, unknown>;
    if (!('a2ui' in obj)) {
      return { valid: false, component: FALLBACK_A2UI };
    }

    const root = this._validateComponent(obj.a2ui);
    return { valid: root !== FALLBACK_A2UI, component: root };
  }

  private _validateComponent(value: unknown): A2uiComponent {
    if (value === null || typeof value !== 'object') return FALLBACK_A2UI;

    const component = value as A2uiComponent;
    const name = component.component;

    if (typeof name !== 'string' || !ALLOWED_COMPONENTS.includes(name)) {
      return FALLBACK_A2UI;
    }

    const cleaned: A2uiComponent = { ...component, component: name };

    if (Array.isArray(component.children)) {
      cleaned.children = component.children
        .map((child) => this._validateComponent(child))
        .filter((child): child is A2uiComponent => child !== undefined);
    }

    if (component.action !== undefined) {
      const validatedAction = this._validateAction(component.action);
      if (validatedAction === undefined) {
        console.warn('[a2ui-validation] stripped invalid action from component', {
          component: name,
          action: component.action,
        });
      }
      cleaned.action = validatedAction;
    }

    return cleaned;
  }

  private _validateAction(value: unknown): A2uiAction | undefined {
    if (value === null || typeof value !== 'object') {
      console.warn('[a2ui-validation] rejecting non-object action', { value });
      return undefined;
    }

    const action = value as Record<string, unknown>;
    const type = action.type;

    if (typeof type !== 'string') {
      console.warn('[a2ui-validation] rejecting action without string type', { action });
      return undefined;
    }

    switch (type) {
      case 'tool': {
        const tool = action.tool;
        if (typeof tool !== 'string' || !ALLOWED_TOOLS.includes(tool)) {
          console.warn('[a2ui-validation] rejecting tool action with unknown/disallowed tool', { tool });
          return undefined;
        }
        const cleaned: A2uiAction = {
          type: 'tool',
          tool,
          arguments:
            action.arguments !== undefined && typeof action.arguments === 'object'
              ? (action.arguments as Record<string, unknown>)
              : undefined,
          requiresConfirmation: action.requiresConfirmation === true,
        };
        if (typeof action._toolCallId === 'string') {
          cleaned._toolCallId = action._toolCallId;
        }
        return cleaned;
      }
      case 'reply': {
        if (typeof action.text !== 'string') {
          console.warn('[a2ui-validation] rejecting reply action without text');
          return undefined;
        }
        return { type: 'reply', text: action.text };
      }
      case 'dismiss':
        return { type: 'dismiss' };
      case 'openUrl': {
        if (typeof action.url !== 'string') {
          console.warn('[a2ui-validation] rejecting openUrl action without url');
          return undefined;
        }
        return { type: 'openUrl', url: action.url };
      }
      default:
        console.warn('[a2ui-validation] rejecting unknown action type', { type });
        return undefined;
    }
  }

  /** Extracts every tool name referenced by actions in the tree. */
  collectToolNames(component: A2uiComponent): string[] {
    const names: string[] = [];
    this._walk(component, (node) => {
      const action = node.action as A2uiAction | undefined;
      if (action?.type === 'tool' && typeof action.tool === 'string') {
        names.push(action.tool);
      }
    });
    return names;
  }

  private _walk(
    component: A2uiComponent,
    visitor: (node: A2uiComponent) => void,
  ): void {
    visitor(component);
    if (Array.isArray(component.children)) {
      for (const child of component.children) {
        this._walk(child as A2uiComponent, visitor);
      }
    }
  }
}
