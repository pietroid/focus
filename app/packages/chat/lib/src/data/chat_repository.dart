import 'package:api_client/api_client.dart';
import 'package:chat/src/data/chat_failure.dart';
import 'package:chat/src/models/models.dart';

/// {@template chat_repository}
/// Reads and writes threads on the backend.
/// {@endtemplate}
class ChatRepository {
  /// {@macro chat_repository}
  const ChatRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// Every thread the signed-in user owns, most recently updated first.
  Future<List<ThreadSummary>> fetchThreads() async {
    final response = await apiClient.get<List<dynamic>>('/threads');
    final data = response.data ?? <dynamic>[];

    return data
        .map((t) => ThreadSummary.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Everything the user has closed, most recently touched first.
  Future<List<ThreadItem>> fetchSolved() async {
    final response = await apiClient.get<List<dynamic>>('/threads/solved');

    return (response.data ?? <dynamic>[])
        .map((t) => ThreadItem.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Writes something down and puts it straight on the timeline.
  ///
  /// No agent runs. The sheet already asked everything that has to be known
  /// to give something an hour, so the answer is the timeline with the new
  /// card already in it.
  Future<List<ThreadSummary>> createScheduled({
    required String message,
    required int durationMinutes,
    required bool fixed,
    DateTime? startTime,
  }) async {
    try {
      final response = await apiClient.post<List<dynamic>>(
        '/threads/scheduled',
        data: {
          'message': message,
          'durationMinutes': durationMinutes,
          'fixed': fixed,
          if (startTime != null)
            'startTime': startTime.toUtc().toIso8601String(),
        },
      );

      return (response.data ?? <dynamic>[])
          .map((t) => ThreadSummary.fromJson(t as Map<String, dynamic>))
          .toList();
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// Moves a card to [index] in the day's single list.
  ///
  /// One number, because there is one list. Everything a drop does to the
  /// hours of everything around it is worked out on the server, so the answer
  /// is the whole timeline rather than a confirmation.
  ///
  /// It is not always the new timeline. A move that displaces something that
  /// is already running comes back with a guard instead, and nothing has
  /// changed on the server until that guard is answered.
  Future<TimelineOutcome> moveThread(String slug, int index) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/threads/$slug/move',
        data: {'index': index},
      );

      return TimelineOutcome.fromJson(response.data ?? <String, dynamic>{});
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// Answers a guard with the button the user tapped.
  ///
  /// The action object goes back exactly as it arrived, for the same reason
  /// [runAction] posts one verbatim: what a guard's answer means, and what it
  /// does to the rest of the day, is the server's to know. The app's whole
  /// part in it is drawing the buttons and saying which one was pressed.
  Future<TimelineOutcome> applyTiming(Map<String, dynamic> action) async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/threads/timing',
        data: {'action': action},
      );

      return TimelineOutcome.fromJson(response.data ?? <String, dynamic>{});
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// Waits for the calendar to catch up with what the app already shows.
  ///
  /// Called after a change, and never on the path the finger is on: the drag
  /// has already landed by the time this goes out. It comes back with nothing
  /// to say almost every time, and with a popup to draw when the booking did
  /// not make it across.
  Future<SyncOutcome> awaitSync() async {
    try {
      final response = await apiClient.get<Map<String, dynamic>>(
        '/threads/sync',
      );

      return SyncOutcome.fromJson(response.data ?? <String, dynamic>{});
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// Pushes whatever did not reach the calendar again.
  Future<SyncOutcome> retrySync() async {
    try {
      final response = await apiClient.post<Map<String, dynamic>>(
        '/threads/sync',
      );

      return SyncOutcome.fromJson(response.data ?? <String, dynamic>{});
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// Marks a thread solved, or puts a solved one back on the timeline.
  ///
  /// Returns the whole list, because solving a thread changes which threads
  /// the timeline has in it and not only the one that was dragged.
  Future<List<ThreadSummary>> setSolved(
    String slug, {
    required bool solved,
  }) async {
    try {
      final response = await apiClient.post<List<dynamic>>(
        '/threads/$slug/solved',
        data: {'solved': solved},
      );

      return (response.data ?? <dynamic>[])
          .map((t) => ThreadSummary.fromJson(t as Map<String, dynamic>))
          .toList();
    } on Object catch (error) {
      throw ChatFailure.from(error);
    }
  }

  /// One thread, with every message it holds.
  Future<Thread> fetchThread(String slug) async {
    final response = await apiClient.get<Map<String, dynamic>>(
      '/threads/$slug',
    );

    return Thread.fromJson(response.data ?? <String, dynamic>{});
  }

  /// Starts a thread from [message] and returns it with the agent's answer.
  Future<Thread> createThread(String message) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/threads',
      data: {'message': message},
    );

    return Thread.fromJson(response.data ?? <String, dynamic>{});
  }

  /// Appends [message] to a thread and returns it with the agent's answer.
  Future<Thread> sendMessage(String slug, String message) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/threads/$slug/messages',
      data: {'message': message},
    );

    return Thread.fromJson(response.data ?? <String, dynamic>{});
  }

  /// Runs an action a rendered component fired.
  ///
  /// The action object is posted exactly as it arrived. The app deliberately
  /// does not read it first: what an action means, which ones need a pending
  /// call, and which ones touch the thread itself are all the server's to know,
  /// and duplicating that judgement here is how the two drift apart.
  Future<Thread> runAction({
    required String slug,
    required Map<String, dynamic> action,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/threads/$slug/actions',
      data: {'action': action},
    );

    final body = response.data ?? <String, dynamic>{};
    final thread = body['thread'] as Map<String, dynamic>?;

    if (thread == null) {
      throw StateError('The action removed the thread');
    }

    return Thread.fromJson(thread);
  }
}
