import 'package:flutter/material.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';

/// Mixin for pages that should refresh data when becoming visible (tab selected).
///
/// Usage:
/// ```dart
/// class _MyPageState extends State<MyPage> with AutoRefreshMixin {
///   @override
///   int get tabIndex => 5; // Your tab index
///
///   @override
///   void onBecameVisible() {
///     // Refresh your data here
///     _loadData();
///   }
/// }
/// ```
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  int? _lastKnownMainIndex;
  MainLayoutState? _mainLayoutState;

  /// Override this to specify which tab index this page belongs to.
  int get tabIndex;

  /// Called when this tab becomes visible (navigated to from another tab).
  /// Override this to refresh your page's data.
  void onBecameVisible();

  void _onTabChanged() {
    final currentMainIndex = _mainLayoutState?.currentIndex;
    if (currentMainIndex == null) return;

    // Check if we just switched TO this tab FROM a different tab
    if (_lastKnownMainIndex != null &&
        _lastKnownMainIndex != currentMainIndex &&
        currentMainIndex == tabIndex) {
      // We just became visible - trigger refresh
      onBecameVisible();
    }

    _lastKnownMainIndex = currentMainIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Get reference to MainLayout and listen to tab changes
    final newMainLayoutState = MainLayout.of(context);
    if (newMainLayoutState != _mainLayoutState) {
      // Remove old listener if any
      _mainLayoutState?.tabIndexNotifier.removeListener(_onTabChanged);

      // Add new listener
      _mainLayoutState = newMainLayoutState;
      _mainLayoutState?.tabIndexNotifier.addListener(_onTabChanged);

      // Initialize last known index
      _lastKnownMainIndex = _mainLayoutState?.currentIndex;
    }
  }

  @override
  void dispose() {
    _mainLayoutState?.tabIndexNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  /// Call this in build() - kept for backward compatibility but no longer needed.
  /// The mixin now listens to tab changes automatically.
  void checkForRefresh() {
    // No-op - listening is now automatic via ValueNotifier
  }
}

/// A widget that wraps a page and triggers a callback when it becomes visible.
/// Alternative to the mixin approach.
class TabVisibilityWrapper extends StatefulWidget {
  final Widget child;
  final int tabIndex;
  final VoidCallback onBecameVisible;

  const TabVisibilityWrapper({
    super.key,
    required this.child,
    required this.tabIndex,
    required this.onBecameVisible,
  });

  @override
  State<TabVisibilityWrapper> createState() => _TabVisibilityWrapperState();
}

class _TabVisibilityWrapperState extends State<TabVisibilityWrapper> {
  int? _lastKnownIndex;
  MainLayoutState? _mainLayoutState;

  void _onTabChanged() {
    final currentIndex = _mainLayoutState?.currentIndex;
    if (currentIndex == null) return;

    // If we're coming from a different tab to this tab
    if (_lastKnownIndex != null &&
        _lastKnownIndex != widget.tabIndex &&
        currentIndex == widget.tabIndex) {
      widget.onBecameVisible();
    }
    _lastKnownIndex = currentIndex;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final newMainLayoutState = MainLayout.of(context);
    if (newMainLayoutState != _mainLayoutState) {
      _mainLayoutState?.tabIndexNotifier.removeListener(_onTabChanged);
      _mainLayoutState = newMainLayoutState;
      _mainLayoutState?.tabIndexNotifier.addListener(_onTabChanged);
      _lastKnownIndex = _mainLayoutState?.currentIndex;
    }
  }

  @override
  void dispose() {
    _mainLayoutState?.tabIndexNotifier.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
