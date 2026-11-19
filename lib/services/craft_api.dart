import 'dart:io';

import 'package:dio/dio.dart';

import '../core/api_config.dart';
import '../core/url_utils.dart';

typedef Json = Map<String, dynamic>;

class CraftApi {
  CraftApi({String? token}) : _token = token {
    _dio = Dio(
      BaseOptions(
        baseUrl: '${ApiConfig.baseUrl}/api',
        connectTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          if (_token != null && _token!.isNotEmpty) {
            o.headers['Authorization'] = 'Bearer $_token';
          }
          h.next(o);
        },
      ),
    );
  }

  late final Dio _dio;
  String? _token;

  void setToken(String? t) {
    _token = t;
  }

  String friendlyError(Object error) {
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map && body['error'] != null) {
        return body['error'].toString();
      }
      if (error.response?.statusCode == 503) {
        return 'GitHub integration is not configured on the server yet. Add the GitHub OAuth keys to the backend env and restart the backend.';
      }
      return error.message ?? 'Request failed';
    }
    return error.toString();
  }

  String assetUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${ApiConfig.baseUrl}$path';
  }

  Future<Json> register({
    required String email,
    required String password,
    required String name,
    required String username,
    String bio = '',
    List<String> genres = const [],
    File? avatar,
  }) async {
    final form = FormData.fromMap({
      'email': email,
      'password': password,
      'name': name,
      'username': username,
      'bio': bio,
      'genres': genres.join(','),
      if (avatar != null)
        'avatar': await MultipartFile.fromFile(
          avatar.path,
          filename: avatar.path.split(Platform.pathSeparator).last,
        ),
    });
    final res = await _dio.post<Json>('/auth/register', data: form);
    return res.data!;
  }

  Future<Json> login({required String email, required String password}) async {
    final res = await _dio.post<Json>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return res.data!;
  }

  /// Verifies Google with the backend and returns only a short-lived pending
  /// registration hand-off; it does not create a Craft Hub account or session.
  Future<Json> startGoogleRegistration({required String idToken}) async {
    final res = await _dio.post<Json>(
      '/auth/google/register',
      data: {'idToken': idToken},
    );
    return res.data!;
  }

  Future<Json> completeGoogleRegistration({
    required String registrationToken,
    required String password,
    required String name,
    required String username,
    String bio = '',
    List<String> genres = const [],
  }) async {
    final res = await _dio.post<Json>(
      '/auth/google/complete-registration',
      data: {
        'registrationToken': registrationToken,
        'password': password,
        'name': name,
        'username': username,
        'bio': bio,
        'genres': genres,
      },
    );
    return res.data!;
  }

  Future<Json> loginWithGoogle({required String idToken}) async {
    final res = await _dio.post<Json>(
      '/auth/google/login',
      data: {'idToken': idToken},
    );
    return res.data!;
  }

  Future<Json> verifyRegister({
    required String email,
    required String code,
  }) async {
    final res = await _dio.post<Json>(
      '/auth/verify-register',
      data: {'email': email, 'code': code},
    );
    return res.data!;
  }

  Future<Json> resendRegisterOtp({required String email}) async {
    final res = await _dio.post<Json>(
      '/auth/resend-register',
      data: {'email': email},
    );
    return res.data!;
  }

  Future<Json> verifyLogin({
    required String preAuthToken,
    required String code,
  }) async {
    final res = await _dio.post<Json>(
      '/auth/verify-login',
      data: {'preAuthToken': preAuthToken, 'code': code},
    );
    return res.data!;
  }

  Future<Json> resendLoginOtp({required String preAuthToken}) async {
    final res = await _dio.post<Json>(
      '/auth/resend-login',
      data: {'preAuthToken': preAuthToken},
    );
    return res.data!;
  }

  Future<Json> me() async {
    final res = await _dio.get<Json>('/auth/me');
    return res.data!;
  }

  Future<Json> mySettings() async {
    final res = await _dio.get<Json>('/users/me/settings');
    return res.data!;
  }

  Future<Json> updateMySettings({
    String? themeMode,
    Map<String, dynamic>? notifications,
  }) async {
    final res = await _dio.patch<Json>(
      '/users/me/settings',
      data: {
        ...?themeMode == null ? null : {'themeMode': themeMode},
        ...?notifications == null ? null : {'notifications': notifications},
      },
    );
    return res.data!;
  }

  Future<Json> githubStatus() async {
    final res = await _dio.get<Json>('/github/status');
    return res.data!;
  }

  Future<Json> githubActivity() async {
    final res = await _dio.get<Json>('/github/activity');
    return res.data!;
  }

  Future<Json> githubActivityForUser(String userId) async {
    final res = await _dio.get<Json>('/github/activity/user/$userId');
    return res.data!;
  }

  Future<Json> githubConnectStart() async {
    final res = await _dio.post<Json>('/github/connect/start');
    return res.data!;
  }

  Future<Json> githubConnectPoll(String flowToken) async {
    final res = await _dio.get<Json>(
      '/github/connect/poll',
      queryParameters: {'state': flowToken},
    );
    return res.data!;
  }

  Future<Json> githubDisconnect() async {
    final res = await _dio.post<Json>('/github/disconnect');
    return res.data ?? <String, dynamic>{'ok': true};
  }

  Future<Json> updateMe({
    String? name,
    String? username,
    String? bio,
    List<String>? genres,
    File? avatar,
    bool removeAvatar = false,
  }) async {
    final form = FormData.fromMap({
      ...?name == null ? null : {'name': name},
      ...?username == null ? null : {'username': username},
      ...?bio == null ? null : {'bio': bio},
      ...?genres == null ? null : {'genres': genres.join(',')},
      if (removeAvatar) 'removeAvatar': 'true',
      if (avatar != null)
        'avatar': await MultipartFile.fromFile(
          avatar.path,
          filename: avatar.path.split(Platform.pathSeparator).last,
        ),
    });
    final res = await _dio.patch<Json>('/users/me', data: form);
    return res.data!;
  }

  Future<Json> profileByUsername(String username) async {
    final res = await _dio.get<Json>('/users/by-username/$username');
    return res.data!;
  }

  Future<Json> profileById(String id) async {
    final res = await _dio.get<Json>('/users/$id/public');
    return res.data!;
  }

  Future<void> follow(String userId) => _dio.post('/users/$userId/follow');
  Future<void> unfollow(String userId) => _dio.delete('/users/$userId/follow');

  Future<Json> followers(String userId) async {
    final res = await _dio.get<Json>('/users/$userId/followers');
    return res.data!;
  }

  Future<Json> userSuggestions() async {
    final res = await _dio.get<Json>('/users/suggestions');
    return res.data!;
  }

  Future<Json> following(String userId) async {
    final res = await _dio.get<Json>('/users/$userId/following');
    return res.data!;
  }

  Future<Json> myProjects() async {
    final res = await _dio.get<Json>('/projects/mine');
    return res.data!;
  }

  Future<Json> userProjects(String userId) async {
    final res = await _dio.get<Json>('/projects/user/$userId');
    return res.data!;
  }

  Future<Json> project(String id) async {
    final res = await _dio.get<Json>('/projects/$id');
    return res.data!;
  }

  Future<Json> explore({String? cursor}) async {
    final res = await _dio.get<Json>(
      '/projects/explore',
      queryParameters: {
        ...?cursor == null ? null : {'cursor': cursor},
      },
    );
    return res.data!;
  }

  Future<Json> createProject({
    required String title,
    String description = '',
    String githubUrl = '',
    String workspaceRepoName = '',
    List<String> genres = const [],
    List<String> techStack = const [],
    List<File> images = const [],
    File? source,
  }) async {
    final normalizedGithubUrl = normalizeGithubUrl(githubUrl);
    final form = FormData();
    form.fields.add(MapEntry('title', title));
    form.fields.add(MapEntry('description', description));
    form.fields.add(MapEntry('githubUrl', normalizedGithubUrl));
    form.fields.add(MapEntry('workspaceRepoName', workspaceRepoName.trim()));
    form.fields.add(MapEntry('genres', genres.join(',')));
    form.fields.add(MapEntry('techStack', techStack.join(',')));
    for (final img in images) {
      form.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(
            img.path,
            filename: img.path.split(Platform.pathSeparator).last,
          ),
        ),
      );
    }
    if (source != null) {
      form.files.add(
        MapEntry(
          'source',
          await MultipartFile.fromFile(
            source.path,
            filename: source.path.split(Platform.pathSeparator).last,
          ),
        ),
      );
    }
    final res = await _dio.post<Json>('/projects/', data: form);
    return res.data!;
  }

  Future<Json> updateProject(
    String id, {
    String? title,
    String? description,
    String? githubUrl,
    String? workspaceRepoName,
    List<String>? genres,
    List<String>? techStack,
    List<File> newImages = const [],
    File? source,
    List<int>? removeImageIndexes,
  }) async {
    final normalizedGithubUrl = githubUrl == null
        ? null
        : normalizeGithubUrl(githubUrl);
    final form = FormData();
    if (title != null) {
      form.fields.add(MapEntry('title', title));
    }
    if (description != null) {
      form.fields.add(MapEntry('description', description));
    }
    if (normalizedGithubUrl != null) {
      form.fields.add(MapEntry('githubUrl', normalizedGithubUrl));
    }
    if (workspaceRepoName != null) {
      form.fields.add(MapEntry('workspaceRepoName', workspaceRepoName));
    }
    if (genres != null) {
      form.fields.add(MapEntry('genres', genres.join(',')));
    }
    if (techStack != null) {
      form.fields.add(MapEntry('techStack', techStack.join(',')));
    }
    if (removeImageIndexes != null && removeImageIndexes.isNotEmpty) {
      form.fields.add(
        MapEntry('removeImageIndexes', removeImageIndexes.join(',')),
      );
    }
    for (final img in newImages) {
      form.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(
            img.path,
            filename: img.path.split(Platform.pathSeparator).last,
          ),
        ),
      );
    }
    if (source != null) {
      form.files.add(
        MapEntry(
          'source',
          await MultipartFile.fromFile(
            source.path,
            filename: source.path.split(Platform.pathSeparator).last,
          ),
        ),
      );
    }
    final res = await _dio.patch<Json>('/projects/$id', data: form);
    return res.data!;
  }

  Future<void> deleteProject(String id) => _dio.delete('/projects/$id');

  Future<Json> likeProject(String id) async {
    final res = await _dio.post<Json>('/projects/$id/like');
    return res.data ?? <String, dynamic>{'likedByMe': true};
  }

  Future<Json> unlikeProject(String id) async {
    final res = await _dio.delete<Json>('/projects/$id/like');
    return res.data ?? <String, dynamic>{'likedByMe': false};
  }

  Future<Json> projectComments(String id) async {
    final res = await _dio.get<Json>('/projects/$id/comments');
    return res.data!;
  }

  Future<Json> commentProject(String id, String text) async {
    final res = await _dio.post<Json>(
      '/projects/$id/comment',
      data: {'text': text},
    );
    return res.data!;
  }

  Future<Json> createProjectWorkspace(String id) async {
    final res = await _dio.post<Json>('/projects/$id/workspace/create');
    return res.data!;
  }

  Future<Json> setWorkspaceRepoName(String id, String repoName) async {
    final res = await _dio.patch<Json>(
      '/projects/$id/workspace/name',
      data: {'repoName': repoName},
    );
    return res.data!;
  }

  Future<Json> matchUsers() async {
    final res = await _dio.get<Json>('/collab/match');
    return res.data!;
  }

  Future<Json> aiStatus() async {
    final res = await _dio.get<Json>('/ai/status');
    return res.data!;
  }

  Future<Json> aiMatchScan(String domain) async {
    final res = await _dio.post<Json>(
      '/ai/match-scan',
      data: {'domain': domain},
    );
    return res.data!;
  }

  Future<Json> craftbroChat({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    final res = await _dio.post<Json>(
      '/ai/craftbro',
      data: {'message': message, 'history': history},
    );
    return res.data!;
  }

  Future<Json> sendCollabRequest({
    required String toUserId,
    required String type,
    String? projectId,
    String message = '',
  }) async {
    final res = await _dio.post<Json>(
      '/collab/requests',
      data: {
        'toUserId': toUserId,
        'type': type,
        'projectId': projectId,
        'message': message,
      },
    );
    return res.data!;
  }

  Future<Json> incomingCollab() async {
    final res = await _dio.get<Json>('/collab/requests/incoming');
    return res.data!;
  }

  Future<Json> outgoingCollab() async {
    final res = await _dio.get<Json>('/collab/requests/outgoing');
    return res.data!;
  }

  Future<Json> acceptCollab(String id) async {
    final res = await _dio.post<Json>('/collab/requests/$id/accept');
    return res.data ?? <String, dynamic>{'ok': true};
  }

  Future<void> rejectCollab(String id) =>
      _dio.post('/collab/requests/$id/reject');

  Future<Json> feedPosts() async {
    final res = await _dio.get<Json>('/posts/feed');
    return res.data!;
  }

  Future<Json> userPosts(String userId) async {
    final res = await _dio.get<Json>('/posts/user/$userId');
    return res.data!;
  }

  Future<Json> getPost(String id) async {
    final res = await _dio.get<Json>('/posts/$id');
    return res.data!;
  }

  Future<Json> createPost({
    String text = '',
    List<File> images = const [],
  }) async {
    final form = FormData();
    form.fields.add(MapEntry('text', text));
    for (final img in images) {
      form.files.add(
        MapEntry(
          'images',
          await MultipartFile.fromFile(
            img.path,
            filename: img.path.split(Platform.pathSeparator).last,
          ),
        ),
      );
    }
    final res = await _dio.post<Json>('/posts/', data: form);
    return res.data!;
  }

  Future<void> deletePost(String id) => _dio.delete('/posts/$id');

  Future<void> likePost(String id) => _dio.post('/posts/$id/like');
  Future<void> unlikePost(String id) => _dio.delete('/posts/$id/like');
  Future<void> sharePost(String id) => _dio.post('/posts/$id/share');

  Future<Json> postComments(String id) async {
    final res = await _dio.get<Json>('/posts/$id/comments');
    return res.data!;
  }

  Future<Json> commentPost(String id, String text) async {
    final res = await _dio.post<Json>(
      '/posts/$id/comment',
      data: {'text': text},
    );
    return res.data!;
  }

  Future<void> suggestPost(String id, String text) =>
      _dio.post('/posts/$id/suggest', data: {'text': text});

  Future<Json> search(String q, {String type = 'all'}) async {
    final res = await _dio.get<Json>(
      '/search',
      queryParameters: {'q': q, 'type': type},
    );
    return res.data!;
  }

  Future<Json> conversations() async {
    final res = await _dio.get<Json>('/conversations');
    return res.data!;
  }

  Future<Json> openDm(String userId) async {
    final res = await _dio.post<Json>(
      '/conversations/dm',
      data: {'userId': userId},
    );
    return res.data!;
  }

  Future<Json> createGroup({
    required String name,
    required List<String> userIds,
    String? projectId,
  }) async {
    final res = await _dio.post<Json>(
      '/conversations/group',
      data: {'name': name, 'userIds': userIds, 'projectId': projectId},
    );
    return res.data!;
  }

  Future<Json> messages(String conversationId) async {
    final res = await _dio.get<Json>('/conversations/$conversationId/messages');
    return res.data!;
  }

  Future<Json> sendMessage(
    String conversationId,
    String text, {
    String? replyToMessageId,
  }) async {
    final res = await _dio.post<Json>(
      '/conversations/$conversationId/messages',
      data: {
        'text': text,
        ...?replyToMessageId == null
            ? null
            : {'replyToMessageId': replyToMessageId},
      },
    );
    return res.data!;
  }

  Future<Json> reactToMessage(
    String conversationId,
    String messageId,
    String emoji,
  ) async {
    final res = await _dio.post<Json>(
      '/conversations/$conversationId/messages/$messageId/react',
      data: {'emoji': emoji},
    );
    return res.data!;
  }
}
