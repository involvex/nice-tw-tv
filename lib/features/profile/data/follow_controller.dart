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
    if (auth?.isLoggedIn != true || auth?.userId == null) {
      return const FollowState(isFollowing: false, isLoading: false);
    }
    final helix = ref.read(helixRepositoryProvider);
    try {
      final isFollowing = await helix.isFollowingChannel(
        userId: auth!.userId!,
        broadcasterId: broadcasterId,
      );
      return FollowState(isFollowing: isFollowing, isLoading: false);
    } on Object {
      return const FollowState(isFollowing: false, isLoading: false);
    }
  }

  Future<void> toggle() async {
    final auth = ref.read(authControllerProvider).value;
    if (auth == null ||
        !auth.isLoggedIn ||
        auth.userId == null ||
        auth.accessToken == null) {
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
        await gql.unfollowUser(
          accessToken: auth.accessToken!,
          targetId: broadcasterId,
        );
      } else {
        await gql.followUser(
          accessToken: auth.accessToken!,
          targetId: broadcasterId,
        );
      }
      state = AsyncData(
        FollowState(isFollowing: !current.isFollowing, isLoading: false),
      );
      ref.invalidate(followingFeedControllerProvider);
    } on Object {
      state = AsyncData(
        FollowState(isFollowing: current.isFollowing, isLoading: false),
      );
      rethrow;
    }
  }
}

final followControllerProvider = AsyncNotifierProvider.autoDispose
    .family<FollowController, FollowState, String>(FollowController.new);
