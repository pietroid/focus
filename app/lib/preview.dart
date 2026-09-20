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

ThreadSummary _thread(String slug, String title, ThreadBucket bucket) {
  return ThreadSummary(
    slug: slug,
    title: title,
    preview: '',
    messageCount: 2,
    solved: false,
    bucket: bucket,
    createdAt: DateTime(2026, 8, 27, 9),
    updatedAt: DateTime(2026, 8, 27, 9),
  );
}

final _threads = <ThreadSummary>[
  _thread('focus', 'Fazendo Focus', ThreadBucket.agora),
  _thread('mercado', 'Comprar leite e ovos', ThreadBucket.emBreve),
  _thread('standup', 'Standup de quinta', ThreadBucket.emBreve),
  _thread('dentista', 'Marcar dentista', ThreadBucket.depois),
];

/// A repository that answers from memory and forgets every write.
class _FakeChatRepository implements ChatRepository {
  @override
  Future<List<ThreadSummary>> fetchThreads() async => _threads;

  @override
  Future<TimelineOutcome> savePlacements(
    Map<ThreadBucket, List<String>> buckets,
  ) async => TimelineOutcome(cards: _threads);

  @override
  Future<TimelineOutcome> applyTiming(Map<String, dynamic> action) async =>
      TimelineOutcome(cards: _threads);

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
      home: BlocProvider<ThreadsBloc>(
        create: (_) =>
            ThreadsBloc(chatRepository: _FakeChatRepository())
              ..add(const ThreadsRequested()),
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
                    Expanded(child: ThreadsSection(onThreadTap: (_) {})),
                  ],
                ),
                Positioned(
                  right: AppSpacing.s6,
                  bottom: AppSpacing.s6,
                  child: AppOrb(
                    onTap: () => AppPromptSheet.show(context),
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
