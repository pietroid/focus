import 'package:app_ui/app_ui.dart';
import 'package:chat/chat.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// A standalone entry point that draws the home screen against fixed data.
///
/// It exists so the screen can be looked at and dragged around without a
/// backend, a Firebase project, or a login. Nothing ships from here.
void main() {
  runApp(const _PreviewApp());
}

TimelineEvent _card(
  String id,
  String title,
  TimelineSection section,
  DateTime start,
  int minutes, {
  bool fixed = false,
}) {
  return TimelineEvent(
    id: id,
    title: title,
    section: section,
    startTime: start,
    endTime: start.add(Duration(minutes: minutes)),
    durationMinutes: minutes,
    fixed: fixed,
  );
}

final _today = DateTime.now();

DateTime _at(int hour, int minute, {int addDays = 0}) {
  return DateTime(
    _today.year,
    _today.month,
    _today.day + addDays,
    hour,
    minute,
  );
}

final _cards = <TimelineEvent>[
  _card('focus', 'Fazendo Focus', TimelineSection.agora, _at(9, 0), 60),
  _card(
    'mercado',
    'Comprar leite e ovos',
    TimelineSection.hoje,
    _at(14, 30),
    30,
  ),
  _card(
    'standup',
    'Standup',
    TimelineSection.hoje,
    _at(16, 0),
    15,
    fixed: true,
  ),
  _card(
    'dentista',
    'Marcar dentista',
    TimelineSection.amanha,
    _at(9, 0, addDays: 1),
    30,
  ),
];

/// A repository that answers from memory and forgets every write.
class _FakeTimelineRepository implements TimelineRepository {
  @override
  Future<List<TimelineEvent>> fetchEvents() async => _cards;

  @override
  Future<TimelineOutcome> moveEvent(String id, int index) async =>
      TimelineOutcome(cards: _cards);

  @override
  Future<TimelineOutcome> applyTiming(Map<String, dynamic> action) async =>
      TimelineOutcome(cards: _cards);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not previewed');
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: BlocProvider<TimelineBloc>(
        create: (_) =>
            TimelineBloc(repository: _FakeTimelineRepository())
              ..add(const TimelineRequested()),
        child: const _PreviewHome(),
      ),
    );
  }
}

class _PreviewHome extends StatelessWidget {
  const _PreviewHome();

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
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s6,
                        AppSpacing.s5,
                        AppSpacing.s6,
                        AppSpacing.s2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bom dia Pietro!',
                                  style: AppTypography.headline,
                                ),
                                const SizedBox(height: AppSpacing.s1),
                                Text(
                                  'Quarta-feira, 27 de agosto',
                                  style: AppTypography.label,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s4),
                          const AppDayClock(),
                        ],
                      ),
                    ),
                    Expanded(child: TimelineList(onCardTap: (_) {})),
                  ],
                ),
                Positioned(
                  right: AppSpacing.s6,
                  bottom: AppSpacing.s6,
                  child: AppOrb(
                    onTap: () => AppPromptSheet.show(
                      context,
                      previewFor: (duration) =>
                          TimelinePlan.nextFreeStart(_cards, duration),
                    ),
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
