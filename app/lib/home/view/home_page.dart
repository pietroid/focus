import 'dart:async';

import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:focus/app/app.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// {@template home_page}
/// The home screen: the clock up top, the user's threads in the middle, and
/// the composer at the bottom.
///
/// Before there is a single thread the middle band is empty and the layout
/// collapses back to the clock and the prompt, which is the screen the app
/// starts life as.
/// {@endtemplate}
class HomePage extends StatelessWidget {
  /// {@macro home_page}
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppSpacing.maxContentWidth,
            ),
            child: const Column(
              children: [
                _Header(),
                Expanded(child: _Threads()),
                _Composer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s4,
        AppSpacing.s6,
        AppSpacing.s8,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const _Clock(),
          Align(
            alignment: Alignment.topRight,
            child: PopupMenuButton<void>(
              icon: const AppIcon(iconData: AppIcons.settings),
              itemBuilder: (context) => [
                PopupMenuItem<void>(
                  onTap: () =>
                      context.read<AppBloc>().add(const AppLogoutRequested()),
                  child: const Row(
                    children: [
                      AppIcon(iconData: AppIcons.logout, size: AppSpacing.s5),
                      SizedBox(width: AppSpacing.s3),
                      Text('Sair'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The wall clock, ticking on the minute boundary rather than every second, so
/// the screen is still for a minute at a time.
class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  static final _format = DateFormat.Hm();

  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _scheduleTick();
  }

  void _scheduleTick() {
    final next = DateTime(
      _now.year,
      _now.month,
      _now.day,
      _now.hour,
    ).add(Duration(minutes: _now.minute + 1));

    _timer = Timer(next.difference(_now), () {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _scheduleTick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _format.format(_now),
      style: AppTypography.clock,
      textAlign: TextAlign.center,
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

class _Composer extends StatelessWidget {
  const _Composer();

  @override
  Widget build(BuildContext context) {
    final firstName = context.select<AppBloc, String?>(
      (bloc) => bloc.state.firstName,
    );
    final caption = firstName == null
        ? 'Em que posso te ajudar?'
        : 'Em que posso te ajudar, $firstName?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s6,
        AppSpacing.s4,
        AppSpacing.s6,
        AppSpacing.s4,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            caption,
            style: AppTypography.label,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s4),
          ChatComposer(
            onSubmitted: (text) async {
              await context.push<void>('/chat', extra: text);
              if (context.mounted) {
                context.read<ThreadsBloc>().add(const ThreadsRequested());
              }
            },
          ),
        ],
      ),
    );
  }
}
