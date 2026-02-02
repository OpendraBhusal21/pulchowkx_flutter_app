import 'package:flutter/material.dart';
import 'package:pulchowkx_app/pages/main_layout.dart';

/// Mixin for pages that should refresh data when becoming visible (tab selected).
///
/// Usage:
/// ```dart
/// class _MyPageState extends State<MyPage> with AutoRefreshMixin {
///   @override
///   void onBecameVisible() {
///     // Refresh your data here
///     _loadData();
///   }
/// }
/// ```
mixin AutoRefreshMixin<T extends StatefulWidget> on State<T> {
  int? _lastVisibleIndex;

  /// Override this to specify which tab index this page belongs to.
  /// Defaults to trying to detect from MainLayout.
  int get tabIndex;

  /// Called when this tab becomes visible (navigated to from another tab).
  /// Override this to refresh your page's data.
  void onBecameVisible();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkVisibility();
  }

  void _checkVisibility() {
    final mainLayout = MainLayout.of(context);
    if (mainLayout != null) {
      final currentIndex = mainLayout.currentIndex;

      // If this is the first time OR if we're coming from a different tab
      if (_lastVisibleIndex != null &&
          _lastVisibleIndex != tabIndex &&
          currentIndex == tabIndex) {
        // We just became visible from a different tab
        onBecameVisible();
      }
      _lastVisibleIndex = currentIndex;
    }
  }

  /// Call this in build() to enable auto-refresh on tab change
  void checkForRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkVisibility();
    });
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkVisibility();
  }

  void _checkVisibility() {
    final mainLayout = MainLayout.of(context);
    if (mainLayout != null) {
      final currentIndex = mainLayout.currentIndex;

      // If we're coming from a different tab to this tab
      if (_lastKnownIndex != null &&
          _lastKnownIndex != widget.tabIndex &&
          currentIndex == widget.tabIndex) {
        widget.onBecameVisible();
      }
      _lastKnownIndex = currentIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check visibility on each build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkVisibility();
    });
    return widget.child;
  }
}
