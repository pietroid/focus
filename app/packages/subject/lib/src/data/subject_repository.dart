import 'package:api_client/api_client.dart';
import 'package:dio/dio.dart';
import 'package:subject/subject.dart';

/// {@template subject_repository}
/// Repository that handles subject operations on the backend.
/// {@endtemplate}
class SubjectRepository {
  /// {@macro subject_repository}
  SubjectRepository({required this.apiClient});

  /// HTTP client used to communicate with the backend.
  final ApiClient apiClient;

  /// Fetches all subjects for the authenticated user.
  Future<List<Subject>> getSubjects() async {
    final response = await apiClient.get<List<dynamic>>('/subjects');
    final data = response.data;
    if (data == null) return [];

    return data
        .map((json) => Subject.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Creates a new subject with the given [name].
  Future<Subject> createSubject(String name) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/subjects',
      data: {'name': name},
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Failed to create subject: empty response');
    }

    return Subject.fromJson(data);
  }

  /// Uploads a PDF for the subject with [subjectId].
  /// Returns the created [Source].
  Future<Source> uploadSource({
    required String subjectId,
    required List<int> bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final response = await apiClient.post<Map<String, dynamic>>(
      '/subjects/$subjectId/uploads',
      data: formData,
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Failed to upload source: empty response');
    }

    return Source.fromJson(data);
  }

  /// Updates the last opened source for the subject with [subjectId].
  Future<Subject> updateLastOpenedSource({
    required String subjectId,
    required String sourceId,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/subjects/$subjectId/last-opened-source',
      data: {'sourceId': sourceId},
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Failed to update last opened source: empty response');
    }

    return Subject.fromJson(data);
  }

  /// Adds an overlay to the source with [sourceId] on the subject with
  /// [subjectId].
  Future<Subject> addOverlay({
    required String subjectId,
    required String sourceId,
    required double x,
    required double y,
    required String text,
    required String color,
  }) async {
    final response = await apiClient.post<Map<String, dynamic>>(
      '/subjects/$subjectId/sources/$sourceId/overlays',
      data: {
        'x': x,
        'y': y,
        'text': text,
        'color': color,
      },
    );

    final data = response.data;
    if (data == null) {
      throw Exception('Failed to add overlay: empty response');
    }

    return Subject.fromJson(data);
  }
}
