import 'package:api_client/api_client.dart';
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

  /// Writes where the home screen's lists ended up after a drag.
  ///
  /// [buckets] is the whole placement, not the one thread that moved: a drop
  /// shifts everything below it in two lists at once, and sending the result
  /// is the only version of this that cannot disagree with what is on screen.
  Future<List<ThreadSummary>> savePlacements(
    Map<ThreadBucket, List<String>> buckets,
  ) async {
    final placements = <Map<String, dynamic>>[
      for (final entry in buckets.entries)
        for (var index = 0; index < entry.value.length; index++)
          {
            'slug': entry.value[index],
            'bucket': entry.key.wire,
            'index': index,
          },
    ];

    final response = await apiClient.post<List<dynamic>>(
      '/threads/placements',
      data: {'placements': placements},
    );

    return (response.data ?? <dynamic>[])
        .map((t) => ThreadSummary.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Marks a thread solved, or puts a solved one back on the timeline.
  ///
  /// Returns the whole list, because solving a thread changes which threads
  /// the timeline has in it and not only the one that was dragged.
  Future<List<ThreadSummary>> setSolved(
    String slug, {
    required bool solved,
  }) async {
    final response = await apiClient.post<List<dynamic>>(
      '/threads/$slug/solved',
      data: {'solved': solved},
    );

    return (response.data ?? <dynamic>[])
        .map((t) => ThreadSummary.fromJson(t as Map<String, dynamic>))
        .toList();
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
