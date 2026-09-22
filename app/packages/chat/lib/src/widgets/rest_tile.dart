import 'package:app_ui/app_ui.dart';
import 'package:chat/src/models/models.dart';

/// {@template rest_tile}
/// What "Agora" holds between one thing and the next.
///
/// A gap is not an empty screen. It is the break, and the card says so in one
/// line, drawn like any other card on the day. It does not say what is next:
/// the next card is right below it, and repeating it here would only be one
/// more thing to think about during the minutes meant for not thinking.
///
/// The line is picked from the next block, so it stays the same for the whole
/// gap instead of changing every time the list is read.
/// {@endtemplate}
class RestTile extends StatelessWidget {
  /// {@macro rest_tile}
  const RestTile({required this.next, super.key});

  /// What comes after the break. Only used to pick the line.
  final TimelineEvent next;

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

  /// The line for the break before [next].
  static String messageFor(TimelineEvent next) {
    final seed = next.id.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
    return messages[seed % messages.length];
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.fill,
      borderRadius: BorderRadius.circular(AppSpacing.chipRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s4,
          vertical: AppSpacing.s3,
        ),
        child: Text(
          messageFor(next),
          style: AppTypography.body.copyWith(color: AppColors.ink2),
        ),
      ),
    );
  }
}
