import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';

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
      final followed = await helix.getFollowedChannels(
        userId: auth!.userId!,
        first: 100,
      );
      final isFollowing = followed.any((c) => c.id == broadcasterId);
      return FollowState(isFollowing: isFollowing, isLoading: false);
    } on Object {
      return const FollowState(isFollowing: false, isLoading: false);
    }
  }

  Future<void> toggle() async {
    final auth = ref.read(authControllerProvider).value;
    if (auth?.isLoggedIn != true || auth?.userId == null) return;
    final current = state.value;
    if (current == null || current.isLoading) return;

    state = AsyncData(
      FollowState(isFollowing: current.isFollowing, isLoading: true),
    );
    final helix = ref.read(helixRepositoryProvider);
    try {
      if (current.isFollowing) {
        await helix.unfollowChannel(
          userId: auth!.userId!,
          broadcasterId: broadcasterId,
        );
        state = const AsyncData(
          FollowState(isFollowing: false, isLoading: false),
        );
      } else {
        await helix.followChannel(
          userId: auth!.userId!,
          broadcasterId: broadcasterId,
        );
        state = const AsyncData(
          FollowState(isFollowing: true, isLoading: false),
        );
      }
    } on Object {
      state = AsyncData(
        FollowState(isFollowing: current.isFollowing, isLoading: false),
      );
    }
  }
}

final followControllerProvider = AsyncNotifierProvider.autoDispose
    .family<FollowController, FollowState, String>(FollowController.new);
