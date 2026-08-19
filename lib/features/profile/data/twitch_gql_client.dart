import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TwitchGqlClient {
  TwitchGqlClient({required this.dio});

  final Dio dio;

  static const webClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

  Future<void> followUser({
    required String accessToken,
    required String targetId,
  }) {
    return _mutate(
      accessToken: accessToken,
      operationName: 'FollowButton_FollowUser',
      query:
          'mutation FollowButton_FollowUser(\$input: FollowUserInput!) { '
          'followUser(input: \$input) { user { id } } }',
      variables: {
        'input': {'disableNotifications': false, 'targetID': targetId},
      },
    );
  }

  Future<void> unfollowUser({
    required String accessToken,
    required String targetId,
  }) {
    return _mutate(
      accessToken: accessToken,
      operationName: 'FollowButton_UnfollowUser',
      query:
          'mutation FollowButton_UnfollowUser(\$input: UnfollowUserInput!) { '
          'unfollowUser(input: \$input) { user { id } } }',
      variables: {
        'input': {'targetID': targetId},
      },
    );
  }

  Future<void> _mutate({
    required String accessToken,
    required String operationName,
    required String query,
    required Map<String, dynamic> variables,
  }) async {
    final response = await dio.post<Map<String, dynamic>>(
      '/gql',
      data: {
        'operationName': operationName,
        'query': query,
        'variables': variables,
      },
      options: Options(
        headers: {
          'Client-Id': webClientId,
          'Authorization': 'OAuth $accessToken',
        },
      ),
    );
    final errors = response.data?['errors'] as List<dynamic>?;
    if (errors != null && errors.isNotEmpty) {
      final messages = errors
          .map(
            (e) =>
                (e as Map<String, dynamic>)['message'] as String? ??
                'Unknown error',
          )
          .join('; ');
      throw DioException(
        requestOptions: response.requestOptions,
        response: response,
        type: DioExceptionType.badResponse,
        message: 'Twitch GraphQL error: $messages',
      );
    }
  }
}

final twitchGqlClientProvider = Provider<TwitchGqlClient>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'https://gql.twitch.tv',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );
  return TwitchGqlClient(dio: dio);
});
