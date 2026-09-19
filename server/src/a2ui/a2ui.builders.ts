import { A2uiComponent } from './a2ui.types';

/**
 * The trees the server writes itself.
 *
 * Only what the model cannot be asked for: the turn where it never answered.
 * Everything else is the model's own reply, validated and drawn. There is no
 * approval step, so there is no dialog here either — a tool runs, and the
 * sentence about it is written with the result already in hand.
 */

/** Says the assistant is unreachable, without blaming the user. */
export function unavailableUi(): A2uiComponent {
  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'cloud',
        color: 'warning',
        title: 'Não consegui me conectar agora',
        subtitle: 'Nada foi perdido. Tente de novo em instantes.',
      },
      {
        component: 'AppButton',
        text: 'Tentar de novo',
        variant: 'secondary',
        icon: 'arrowRight',
        action: { type: 'reply', text: 'Tenta de novo' },
      },
    ],
  };
}

/**
 * Says the model answered with nothing usable.
 *
 * Distinct from [unavailableUi]: the agent was reached and the tools may well
 * have run, so this offers to pick the turn back up rather than implying the
 * whole thing was lost.
 */
export function emptyReplyUi(): A2uiComponent {
  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'question',
        color: 'warning',
        title: 'Me perdi na resposta',
        subtitle: 'Pode repetir? Se algo já foi feito, eu confiro para você.',
      },
      {
        component: 'AppButton',
        text: 'Tentar de novo',
        variant: 'secondary',
        icon: 'arrowRight',
        action: { type: 'reply', text: 'Tenta de novo' },
      },
    ],
  };
}

/** A plain sentence, for the cases that need nothing more. */
export function textUi(text: string): A2uiComponent {
  return { component: 'Text', text, variant: 'body' };
}
