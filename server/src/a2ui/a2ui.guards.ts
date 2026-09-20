import {
  DURATION_CHOICES_MINUTES,
  formatDuration,
  formatRange,
  formatTime,
  Interval,
} from '../time/work-hours';
import { ThreadBucket } from '../threads/entities/thread.entity';
import { A2uiComponent, TimingAction } from './a2ui.types';

/**
 * The guards: the questions the server asks before a card lands.
 *
 * They are A2UI trees, drawn by the same renderer a reply is drawn by, and
 * built here rather than by a model. A guard is arithmetic over the calendar
 * and the working day, so there is nothing for a model to add and a great
 * deal for it to get wrong: a proposal that drifts by fifteen minutes because
 * a model was feeling creative would be a meeting in the wrong place.
 *
 * Every button carries the whole move plus one decision, so a guard holds no
 * state anywhere. Walking away from one leaves the thread exactly where it
 * was.
 */

/** The move a guard is asking about. */
export interface GuardMove {
  slug: string;
  bucket: ThreadBucket;
  index: number;
  durationMinutes?: number;
  startTime?: string;
}

/** A timing action for [move], carrying [decision]. */
function timing(
  move: GuardMove,
  decision?: TimingAction['decision'],
  overrides: Partial<GuardMove> = {},
): TimingAction {
  const merged = { ...move, ...overrides };

  return {
    type: 'timing',
    slug: merged.slug,
    bucket: merged.bucket,
    index: merged.index,
    durationMinutes: merged.durationMinutes,
    startTime: merged.startTime,
    decision,
  };
}

/** The button that closes a guard and changes nothing. */
function cancelButton(): A2uiComponent {
  return {
    component: 'AppButton',
    text: 'Cancelar',
    variant: 'tertiary',
    expand: true,
    action: { type: 'dismiss' },
  };
}

/**
 * Asks how long something takes.
 *
 * The first guard anything untimed meets on its way up the screen. Without a
 * duration there is nothing to propose a time for, and "Em breve" would mean
 * no more than it did in "Depois".
 */
export function durationGuard(move: GuardMove, title: string): A2uiComponent {
  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'hourglass',
        title: 'Quanto tempo isso leva?',
        subtitle: title,
      },
      {
        component: 'Text',
        text: 'Preciso de uma duração para achar um horário.',
        variant: 'caption',
        color: 'ink2',
      },
      ...DURATION_CHOICES_MINUTES.map((minutes) => ({
        component: 'AppButton' as const,
        text: formatDuration(minutes),
        variant: 'secondary' as const,
        expand: true,
        action: timing(move, undefined, { durationMinutes: minutes }),
      })),
      cancelButton(),
    ],
  };
}

/**
 * Proposes a time, and offers to keep the thread untimed instead.
 *
 * The second half of what the spec asks for: accepting puts it in the
 * calendar, declining still leaves it with a duration. A thread that came out
 * of this knowing how long it takes has learned something even if it never
 * got a slot.
 */
export function scheduleGuard(
  move: GuardMove,
  title: string,
  slot: Interval,
): A2uiComponent {
  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'calendarPlus',
        title: `Reservar ${formatRange(slot)}?`,
        subtitle: title,
      },
      {
        component: 'Text',
        text: `${formatDuration(move.durationMinutes ?? 0)} na sua agenda, começando ${formatTime(slot.start)}.`,
        variant: 'caption',
        color: 'ink2',
      },
      {
        component: 'AppButton',
        text: 'Colocar na agenda',
        variant: 'primary',
        icon: 'calendarCheck',
        expand: true,
        action: timing(move, 'schedule', {
          startTime: slot.start.toISOString(),
        }),
      },
      {
        component: 'AppButton',
        text: 'Deixar sem horário',
        variant: 'secondary',
        expand: true,
        action: timing(move, 'manual'),
      },
      cancelButton(),
    ],
  };
}

/**
 * Says what the proposed time runs into, and offers the two ways out.
 *
 * Postponing is the primary because it is the one the spec calls the default:
 * a day is a queue, and the ordinary meaning of putting something in the
 * middle of it is that everything after it moves down.
 */
export function conflictGuard(
  move: GuardMove,
  slot: Interval,
  conflicts: { title: string; interval: Interval }[],
): A2uiComponent {
  const first = conflicts[0];
  const rest = conflicts.length - 1;

  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'warning',
        color: 'warning',
        title: `${formatRange(slot)} está ocupado`,
        subtitle:
          rest > 0
            ? `${first.title} e mais ${rest} nesse intervalo`
            : `${first.title}, ${formatRange(first.interval)}`,
      },
      {
        component: 'Text',
        text: 'Posso empurrar o que vem depois para abrir espaço.',
        variant: 'caption',
        color: 'ink2',
      },
      {
        component: 'AppButton',
        text: 'Adiar os próximos',
        variant: 'primary',
        icon: 'arrowRight',
        expand: true,
        action: timing(move, 'postpone'),
      },
      {
        component: 'AppButton',
        text: 'Marcar por cima',
        variant: 'secondary',
        expand: true,
        action: timing(move, 'force'),
      },
      cancelButton(),
    ],
  };
}

/**
 * Asks before taking something off the calendar.
 *
 * Dragging a scheduled card down to "Depois" is the only way to unbook
 * something from this screen, and it is one flick of a finger away from a
 * reorder, so it is worth one question.
 */
export function unscheduleGuard(
  move: GuardMove,
  title: string,
  slot: Interval,
): A2uiComponent {
  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'calendarX',
        title: 'Tirar da agenda?',
        subtitle: `${title}, ${formatRange(slot)}`,
      },
      {
        component: 'Text',
        text: 'O compromisso sai do Google Agenda e o card fica em Depois.',
        variant: 'caption',
        color: 'ink2',
      },
      {
        component: 'AppButton',
        text: 'Tirar da agenda',
        variant: 'primary',
        icon: 'calendarX',
        expand: true,
        action: timing(move, 'unschedule'),
      },
      cancelButton(),
    ],
  };
}

/** Says a guard could not do what it offered, without pretending otherwise. */
export function guardFailedUi(reason: string): A2uiComponent {
  return {
    component: 'Column',
    gap: 'normal',
    children: [
      {
        component: 'ListItem',
        icon: 'xCircle',
        color: 'danger',
        title: 'Não consegui mexer na agenda',
        subtitle: reason,
      },
      cancelButton(),
    ],
  };
}
