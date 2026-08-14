# Back-to-top on Live tab re-tap

## Goal
When the user taps the Live tab in the bottom navigation bar while already on the Live tab and scrolled down, the screen should smoothly scroll back to the top.

## Current behavior
- Bottom nav `onDestinationSelected` calls `navigationShell.goBranch(index)`, which is a no-op when the user taps the currently active branch.
- `HomeScreen` uses a `CustomScrollView` with slivers for card mode, and a `PageView` for autoplay mode. There is no exposed scroll controller, so the shell cannot trigger a scroll-to-top.

## Plan

### 1. Add a shared `ScrollController` provider
In `lib/features/home/presentation/home_screen.dart`, add:
```dart
final homeScrollControllerProvider = Provider<ScrollController>((ref) {
  final controller = ScrollController();
  ref.onDispose(controller.dispose);
  return controller;
});
```

### 2. Attach the controller to the `CustomScrollView`
In `HomeScreen.build`, in the card-mode `Scaffold` branch, change:
```dart
child: RefreshIndicator(
  onRefresh: onRefresh,
  child: CustomScrollView(
```
to:
```dart
child: RefreshIndicator(
  onRefresh: onRefresh,
  child: CustomScrollView(
    controller: ref.watch(homeScrollControllerProvider),
```

### 3. Handle re-tap in `_MainShell`
In `lib/core/routing/app_router.dart`, replace the simple `navigationShell.goBranch` with logic that detects a re-tap on the Live tab root:

```dart
onDestinationSelected: (index) {
  if (index == navigationShell.currentIndex) {
    final location = GoRouter.of(context).location;
    if (index == 0 && location == '/') {
      final controller = ref.read(homeScrollControllerProvider);
      if (controller.hasClients) {
        controller.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
      return;
    }
  }
  navigationShell.goBranch(index);
},
```

### 4. Scope
- Only applies to the Live tab (index 0) when the user is at the root route `/`.
- Does not affect autoplay mode (which uses a full-screen `PageView`).
- Does not affect Following, VODs, or Settings tabs.

### 5. Validation
- Run `flutter analyze`.
- Run `flutter test`.
- Manual test: open app, scroll down on Live tab, tap Live tab again, verify smooth scroll to top.
