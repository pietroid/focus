import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';

/// {@template free_tile}
/// A stretch of the day with nothing programmed.
///
/// A gap is not an empty screen, and it is not a missing card either: it is
/// room, drawn as its own quiet card in a faint green so it reads as time to
/// breathe. It says when it starts, like every card, and nothing about when
/// it ends, because the card after it already does.
///
/// The one happening now is also the break, and adds a line saying so. The
/// line is picked from where the stretch starts, so it stays the same for the
/// whole gap instead of changing every time the list is read.
///
/// It is also somewhere a card can be dropped, and lights up while one is
/// aimed at it.
/// {@endtemplate}
class FreeTile extends StatelessWidget {
  /// {@macro free_tile}
  const FreeTile({
    required this.slot,
    this.now = false,
    this.targeted = false,
    super.key,
  });

  /// The stretch.
  final FreeSlot slot;

  /// Whether it is the stretch being lived through, which is the break.
  final bool now;

  /// Whether a card in the air would land here.
  final bool targeted;

  /// Twenty ways of saying the same thing.
  static const messages = <String>[
    'Respire fundo. Três vezes, devagar.',
    'Levante, alongue as costas e olhe pela janela.',
    'Beba um copo d’água antes de continuar.',
    'Feche os olhos por um minuto. Só isso.',
    'Deixe a cabeça vazia. O próximo passo espera.',
    'Solte os ombros. Eles estavam tensos, não estavam?',
    'Olhe para algo longe. Seus olhos agradecem.',
    'Nada para resolver agora. Aproveite.',
    'Caminhe um pouco, nem que seja até a cozinha.',
    'Um minuto de silêncio. Sem tela.',
    'Repare no que você está ouvindo agora.',
    'Você terminou algo. Reconheça isso.',
    'Inspire em quatro, segure em quatro, solte em quatro.',
    'Desligue a mente. Ela volta melhor.',
    'Mexa as mãos, gire os pulsos, relaxe o rosto.',
    'Pausa de verdade: sem celular.',
    'Sinta os pés no chão por alguns segundos.',
    'Descansar também é parte do trabalho.',
    'Deixe o último assunto ir embora.',
    'Medite por um instante. Só respire e observe.',
  ];

  /// The line for the break that is [slot].
  static String messageFor(FreeSlot slot) {
    final seed = slot.end.millisecondsSinceEpoch ~/ 60000;
    return messages[seed % messages.length];
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: targeted ? AppColors.fillStrong : AppColors.freeFill,
        borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s4,
        vertical: AppSpacing.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nada programado',
                  style: AppTypography.body.copyWith(color: AppColors.freeInk),
                ),
              ),
              const SizedBox(width: AppSpacing.s3),
              Text(
                _hhmm(slot.start),
                style: AppTypography.label.copyWith(color: AppColors.ink3),
              ),
            ],
          ),
          if (now) ...[
            const SizedBox(height: AppSpacing.s1),
            Text(
              messageFor(slot),
              style: AppTypography.label.copyWith(color: AppColors.ink2),
            ),
          ],
        ],
      ),
    );
  }

  static String _hhmm(DateTime at) {
    return '${at.hour.toString().padLeft(2, '0')}:'
        '${at.minute.toString().padLeft(2, '0')}';
  }
}
