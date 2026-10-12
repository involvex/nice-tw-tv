import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/profile/data/twitch_gql_client.dart';

class SignInRequiredException implements Exception {
  const SignInRequiredException();
}

class FollowState {
  const FollowState({required this.isFollowing, required this.isLoading});

  final bool isFollowing;
  final bool isLoading;
}

class FollowController extends AsyncNotifier<FollowState> {
  FollowController(this.broadcasterId);

  final String broadcasterId;

  @override
  Future<FollowState> build() async {
    final auth = ref.watch(authControllerProvider).value;
    final userId = auth?.userId;
    if (auth?.isLoggedIn != true || userId == null) {
      return const FollowState(isFollowing: false, isLoading: false);
    }
    final helix = ref.read(helixRepositoryProvider);
    try {
      final isFollowing = await helix.isFollowingChannel(
        userId: userId,
        broadcasterId: broadcasterId,
      );
      return FollowState(isFollowing: isFollowing, isLoading: false);
    } on Object {
      return const FollowState(isFollowing: false, isLoading: false);
    }
  }

  Future<void> toggle() async {
    if (broadcasterId.isEmpty) {
      throw StateError('broadcasterId is empty — cannot follow/unfollow');
    }
    final authRepo = ref.read(authRepositoryProvider);
    // Require an actual stored user token — never let an app-token
    // fallback reach the GQL endpoint (it rejects it, which previously
    // triggered a logout that deleted the good stored token).
    final userToken = await authRepo.resolveUserToken();
    // The controller can briefly be AsyncLoading right after login while
    // completeLogin validates the token — fall back to the repository
    // session so a valid login isn't misreported as signed-out.
    final controllerAuth = ref.read(authControllerProvider).value;
    final repoSession = authRepo.session;
    final isLoggedIn =
        (controllerAuth?.isLoggedIn ?? false) || repoSession.isLoggedIn;
    final userId = controllerAuth?.userId ?? repoSession.userId;
    if (userToken == null || !isLoggedIn || userId == null) {
      throw const SignInRequiredException();
    }
    final current = state.value;
    if (current == null || current.isLoading) return;

    state = AsyncData(
      FollowState(isFollowing: current.isFollowing, isLoading: true),
    );
    try {
      final gql = ref.read(twitchGqlClientProvider);
      if (current.isFollowing) {
        await gql.unfollowUser(targetId: broadcasterId);
      } else {
        await gql.followUser(targetId: broadcasterId);
      }
      state = AsyncData(
        FollowState(isFollowing: !current.isFollowing, isLoading: false),
      );
      ref.invalidate(followingFeedControllerProvider);
    } on DioException catch (e) {
      state = AsyncData(
        FollowState(isFollowing: current.isFollowing, isLoading: false),
      );
      // An HTTP 401 alone does NOT prove the stored token is dead (it can
      // come from a stale in-memory token or a request-level issue).
      // Re-validate the stored token first and only wipe the session when
      // it is provably invalid — otherwise a follow failure must surface
      // as a follow error, never as a forced logout.
      if (e.response?.statusCode == 401) {
        final stored = await ref
            .read(authRepositoryProvider)
            .resolveUserToken();
        final alive =
            stored != null &&
            await ref.read(authRepositoryProvider).isTokenValid(stored);
        if (!alive) {
          await ref.read(authControllerProvider.notifier).logout();
          throw const SignInRequiredException();
        }
      }
      rethrow;
    } on Object {
      state = AsyncData(
        FollowState(isFollowing: current.isFollowing, isLoading: false),
      );
      rethrow;
    }
  }

  /// Returns `true` when a GraphQL response body carries an auth-related
  /// error message. Used for diagnostics only — [toggle] deliberately only
  /// auto-logs-out on HTTP 401 so a valid session is never wiped by a
  /// non-auth GraphQL failure (unknown target, scope, etc.).
  static bool isGraphQlAuthError(DioException e) {
    final data = e.response?.data;
    if (data is! Map<String, dynamic>) return false;
    final errors = data['errors'] as List<dynamic>?;
    if (errors == null || errors.isEmpty) return false;

    for (final error in errors) {
      if (error is! Map<String, dynamic>) continue;
      final message = (error['message'] as String? ?? '').toLowerCase();
      if (message.contains('unauthorized') ||
          message.contains('invalid oauth') ||
          message.contains('invalid access token') ||
          message.contains('not authorized') ||
          message.contains('invalid token')) {
        return true;
      }
    }
    return false;
  }
}

final followControllerProvider = AsyncNotifierProvider.autoDispose
    .family<FollowController, FollowState, String>(FollowController.new);
