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

final _now = DateTime.now();

/// `?rest` draws the break between two blocks instead of one running.
final bool _resting = Uri.base.queryParameters.containsKey('rest');

List<TimelineEvent> _cards = [
  if (!_resting)
    _card(
      'focus',
      'Fazendo Focus',
      TimelineSection.agora,
      _now.subtract(const Duration(minutes: 1)),
      45,
    ),
  _card(
    'mercado',
    'Comprar leite e ovos',
    TimelineSection.hoje,
    _now.add(const Duration(minutes: 25)),
    30,
  ),
  _card(
    'standup',
    'Standup',
    TimelineSection.hoje,
    _now.add(const Duration(hours: 2)),
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

/// A repository that answers from memory, well enough to press the buttons.
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
  Future<SyncOutcome> awaitSync() async => const SyncOutcome(ok: true);

  @override
  Future<Thread> startThread(String id) async =>
      Thread.fromJson({'slug': id, 'title': id, 'messages': const <dynamic>[]});

  @override
  Future<List<TimelineEvent>> pauseEvent(String id) async => _cards = [
    for (final card in _cards)
      card.id == id ? card.copyWith(pausedAt: DateTime.now()) : card,
  ];

  @override
  Future<List<TimelineEvent>> resumeEvent(String id) async => _cards = [
    for (final card in _cards)
      card.id == id ? card.copyWith(clearPause: true) : card,
  ];

  @override
  Future<List<TimelineEvent>> extendEvent(String id, int minutes) async =>
      _cards;

  @override
  Future<List<TimelineEvent>> finishEvent(String id) async =>
      _cards = _cards.where((card) => card.id != id).toList();

  @override
  Future<List<TimelineEvent>> deleteEvent(String id) async =>
      _cards = _cards.where((card) => card.id != id).toList();

  @override
  Future<List<TimelineEvent>> editEvent(
    String id, {
    String? title,
    int? workMinutes,
    DateTime? startTime,
  }) async => _cards;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not previewed');
}

/// A chat that answers every message with the same line.
class _FakeChatRepository implements ChatRepository {
  final _messages = <Map<String, dynamic>>[];

  @override
  Future<Thread> sendMessage(String slug, String message) async {
    _messages
      ..add({'id': '${_messages.length}', 'role': 'user', 'text': message})
      ..add({
        'id': '${_messages.length + 1}',
        'role': 'agent',
        'text': 'Entendi. Vamos por partes.',
      });

    return Thread.fromJson({
      'slug': slug,
      'title': 'Fazendo Focus',
      'messages': _messages,
    });
  }

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
      builder: (context, child) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<TimelineRepository>(
            create: (_) => _FakeTimelineRepository(),
          ),
          RepositoryProvider<ChatRepository>(
            create: (_) => _FakeChatRepository(),
          ),
        ],
        child: BlocProvider<TimelineBloc>(
          create: (context) =>
              TimelineBloc(repository: context.read<TimelineRepository>())
                ..add(const TimelineRequested()),
          child: child,
        ),
      ),
      home: const _PreviewHome(),
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
                    Expanded(
                      child: TimelineList(
                        onCardTap: (card) => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => EventPage(id: card.id),
                          ),
                        ),
                      ),
                    ),
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
