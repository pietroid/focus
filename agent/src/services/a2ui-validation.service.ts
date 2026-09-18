import {
  A2UI_CATALOG,
  BUTTON_VARIANTS,
  COMPONENT_NAMES,
  CROSS_AXIS_ALIGNMENTS,
  ICON_COLORS,
  IMAGE_FITS,
  MAIN_AXIS_ALIGNMENTS,
  TEXT_VARIANTS,
} from '../a2ui/catalog.js';
import { A2uiAction, A2uiComponent, ComponentName } from '../a2ui/types.js';
import { ALLOWED_TOOLS } from '../a2ui/catalog.js';

/** The fallback reply shown when validation or generation fails. */
export const FALLBACK_A2UI: A2uiComponent = {
  component: 'Text',
  text: "I'm unable to reply right now. Please try again in a moment.",
};

/** Result of validating an A2UI tree. */
export interface ValidationResult {
  valid: boolean;
  component: A2uiComponent;
  errors: string[];
}

/**
 * Validates A2UI component trees.
 *
 * Unknown components are rejected, unknown props are stripped, and required
 * fields (like Text.text) are enforced. On failure the caller receives a
 * fallback tree so the UI never crashes.
 */
export class A2uiValidationService {
  validate(reply: unknown): ValidationResult {
    const errors: string[] = [];

    if (reply === null || typeof reply !== 'object') {
      errors.push('Reply is not an object');
      return { valid: false, component: FALLBACK_A2UI, errors };
    }

    const obj = reply as Record<string, unknown>;
    if (!('a2ui' in obj)) {
      errors.push('Reply is missing top-level "a2ui" field');
      return { valid: false, component: FALLBACK_A2UI, errors };
    }

    const root = this._validateComponent(obj.a2ui, errors);
    return {
      valid: errors.length === 0,
      component: errors.length === 0 ? root : FALLBACK_A2UI,
      errors,
    };
  }

  private _validateComponent(value: unknown, errors: string[]): A2uiComponent {
    if (value === null || typeof value !== 'object') {
      errors.push('Component is not an object');
      return FALLBACK_A2UI;
    }

    const component = value as A2uiComponent;
    const name = component.component;

    if (!COMPONENT_NAMES.includes(name as ComponentName)) {
      errors.push(`Unknown component "${String(name)}"`);
      return FALLBACK_A2UI;
    }

    const schema = A2UI_CATALOG[name as ComponentName];
    const cleaned: A2uiComponent = { component: name as ComponentName };

    for (const prop of schema.props) {
      if (prop in component) {
        cleaned[prop as keyof A2uiComponent] = component[prop] as never;
      }
    }

    if (schema.children && Array.isArray(component.children)) {
      cleaned.children = (component.children as A2uiComponent[]).map((child) =>
        this._validateComponent(child, errors),
      );
    }

    this._validateComponentSpecific(name as ComponentName, cleaned, errors);

    if (component.action !== undefined) {
      cleaned.action = this._validateAction(component.action, errors);
    }

    return cleaned;
  }

  private _validateComponentSpecific(
    name: ComponentName,
    component: A2uiComponent,
    errors: string[],
  ): void {
    switch (name) {
      case 'Text': {
        const text = component.text;
        if (typeof text !== 'string' || text.trim() === '') {
          errors.push('Text component must have a non-empty "text" string');
        }
        if (
          component.variant !== undefined &&
          !TEXT_VARIANTS.includes(component.variant)
        ) {
          errors.push(`Invalid text variant "${component.variant}"`);
        }
        break;
      }
      case 'Icon':
      case 'AppIconButton': {
        if (typeof component.icon !== 'string' || component.icon === '') {
          errors.push(`${name} component must have a non-empty "icon" string`);
        }
        if (component.color !== undefined && !ICON_COLORS.includes(component.color)) {
          errors.push(`Invalid icon color "${component.color}"`);
        }
        break;
      }
      case 'Image': {
        if (typeof component.src !== 'string' || component.src === '') {
          errors.push('Image component must have a non-empty "src" URL');
        }
        if (component.fit !== undefined && !IMAGE_FITS.includes(component.fit)) {
          errors.push(`Invalid image fit "${component.fit}"`);
        }
        break;
      }
      case 'AppButton': {
        if (typeof component.text !== 'string' || component.text === '') {
          errors.push('AppButton component must have a non-empty "text" string');
        }
        if (
          component.variant !== undefined &&
          !BUTTON_VARIANTS.includes(component.variant)
        ) {
          errors.push(`Invalid button variant "${component.variant}"`);
        }
        break;
      }
      case 'Column':
      case 'Row': {
        if (
          component.mainAxisAlignment !== undefined &&
          !MAIN_AXIS_ALIGNMENTS.includes(component.mainAxisAlignment)
        ) {
          errors.push(`Invalid mainAxisAlignment "${component.mainAxisAlignment}"`);
        }
        if (
          component.crossAxisAlignment !== undefined &&
          !CROSS_AXIS_ALIGNMENTS.includes(component.crossAxisAlignment)
        ) {
          errors.push(`Invalid crossAxisAlignment "${component.crossAxisAlignment}"`);
        }
        break;
      }
      default:
        break;
    }
  }

  private _validateAction(value: unknown, errors: string[]): A2uiAction | undefined {
    if (value === null || typeof value !== 'object') {
      errors.push('Action is not an object');
      return undefined;
    }

    const action = value as Record<string, unknown>;
    const type = action.type;

    if (typeof type !== 'string') {
      errors.push('Action is missing "type"');
      return undefined;
    }

    switch (type) {
      case 'tool': {
        const tool = action.tool;
        if (typeof tool !== 'string') {
          errors.push('Tool action is missing "tool" name');
          return undefined;
        }
        if (!ALLOWED_TOOLS.includes(tool)) {
          errors.push(`Tool "${tool}" is not in the allowed list`);
          return undefined;
        }
        return {
          type: 'tool',
          tool,
          arguments:
            action.arguments !== undefined && typeof action.arguments === 'object'
              ? (action.arguments as Record<string, unknown>)
              : undefined,
          requiresConfirmation: action.requiresConfirmation === true,
        };
      }
      case 'reply': {
        if (typeof action.text !== 'string' || action.text === '') {
          errors.push('Reply action is missing "text"');
          return undefined;
        }
        return { type: 'reply', text: action.text };
      }
      case 'dismiss':
        return { type: 'dismiss' };
      case 'openUrl': {
        if (typeof action.url !== 'string' || action.url === '') {
          errors.push('openUrl action is missing "url"');
          return undefined;
        }
        return { type: 'openUrl', url: action.url };
      }
      default:
        errors.push(`Unknown action type "${type}"`);
        return undefined;
    }
  }

  /** Extracts tool names referenced by a validated A2UI tree. */
  collectToolNames(component: A2uiComponent): string[] {
    const names: string[] = [];
    this._walk(component, (node) => {
      if (node.action?.type === 'tool') {
        names.push(node.action.tool);
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
        this._walk(child, visitor);
      }
    }
  }
}
