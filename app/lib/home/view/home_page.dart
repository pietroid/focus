import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/app.dart';
import 'package:go_router/go_router.dart';

/// {@template home_page}
/// The home screen: who you are and what time it is at the top, the three
/// lists below it, and one orb at the foot to start something new.
///
/// There is no field on this screen. Typing is a deliberate act that opens a
/// sheet, which keeps the home screen about what is already there rather than
/// about the next thing to add to it.
/// {@endtemplate}
class HomePage extends StatelessWidget {
  /// {@macro home_page}
  const HomePage({super.key});

  Future<void> _compose(BuildContext context) async {
    final text = await AppPromptSheet.show(context);
    if (text == null || !context.mounted) return;

    // A new thread lands at the end of "Em breve"; the server places it. The
    // list is refetched on the way back so the card is there when the chat
    // closes.
    await context.push<void>('/chat', extra: text);
    if (context.mounted) {
      context.read<ThreadsBloc>().add(const ThreadsRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: Stack(
              children: [
                const Column(
                  children: [
                    _Header(),
                    Expanded(child: _Threads()),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: AppSpacing.s6,
                  child: Center(
                    child: AppOrb(onTap: () => _compose(context)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The greeting, the date, and the clock.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final firstName = context.select<AppBloc, String?>(
      (bloc) => bloc.state.firstName,
    );
    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s5,
        AppSpacing.s6,
        AppSpacing.s4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The greeting is the account: it is the only thing on the
                // screen that names the person, so it is also the only thing
                // that opens their menu.
                _Profile(greeting: _greeting(now, firstName)),
                const SizedBox(height: AppSpacing.s1),
                Text(_PtDate.long(now), style: AppTypography.label),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s3),
          const AppDayClock(),
        ],
      ),
    );
  }

  /// "Bom dia Pietro!", or without the name when there is not one yet.
  static String _greeting(DateTime now, String? firstName) {
    final part = switch (now.hour) {
      >= 5 && < 12 => 'Bom dia',
      >= 12 && < 18 => 'Boa tarde',
      _ => 'Boa noite',
    };

    return firstName == null ? '$part!' : '$part $firstName!';
  }
}

/// Portuguese dates, written out.
///
/// Doing this through `intl` would mean loading its locale data at startup
/// and still telling it how Brazilian Portuguese writes a date. Three lists
/// of names is less machinery, and this is the only screen that needs them.
abstract final class _PtDate {
  static const _weekdays = <String>[
    'Segunda-feira',
    'Terça-feira',
    'Quarta-feira',
    'Quinta-feira',
    'Sexta-feira',
    'Sábado',
    'Domingo',
  ];

  static const _months = <String>[
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];

  /// "Quarta-feira, 27 de agosto".
  static String long(DateTime at) {
    final weekday = _weekdays[at.weekday - DateTime.monday];
    final month = _months[at.month - 1];

    return '$weekday, ${at.day} de $month';
  }
}

/// The greeting, and the account menu behind it.
class _Profile extends StatelessWidget {
  const _Profile({required this.greeting});

  final String greeting;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<void>(
      padding: EdgeInsets.zero,
      tooltip: '',
      offset: const Offset(0, AppSpacing.s8),
      constraints: const BoxConstraints(minWidth: AppSpacing.s12 * 3),
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: () => context.read<AppBloc>().add(const AppLogoutRequested()),
          child: const Row(
            children: [
              AppIcon(iconData: AppIcons.logout, size: AppSpacing.s5),
              SizedBox(width: AppSpacing.s3),
              Text('Sair'),
            ],
          ),
        ),
      ],
      child: Text(
        greeting,
        style: AppTypography.headline,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _Threads extends StatelessWidget {
  const _Threads();

  @override
  Widget build(BuildContext context) {
    return ThreadsSection(
      onThreadTap: (slug) async {
        await context.push<void>('/chat/$slug');
        // The thread's preview and position both change while it is open, so
        // the list is refetched on the way back rather than left stale.
        if (context.mounted) {
          context.read<ThreadsBloc>().add(const ThreadsRequested());
        }
      },
    );
  }
}
