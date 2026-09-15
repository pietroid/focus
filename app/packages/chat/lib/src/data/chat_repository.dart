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
}
