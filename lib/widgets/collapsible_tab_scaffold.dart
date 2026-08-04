// lib/widgets/collapsible_tab_scaffold.dart
//
// Shared module layout used across HOD and supervisor screens:
//  - Collapsible SliverAppBar: the title + compact tab bar hide when the
//    user scrolls the content up, giving clean full-screen content.
//  - Compact pill-style TabBar (minimal, scrollable, no bulky icons).
//
// Requirements for the collapse to work: each tab in [body]'s TabBarView
// must be scrollable (ListView / SingleChildScrollView / CustomScrollView).

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Compact pill-style tab bar used inside a SliverAppBar bottom.
/// Same look as [CollapsibleTabScaffold]'s built-in tabs, exposed as a
/// standalone helper for screens converted inline.
PreferredSizeWidget buildCompactTabBar(
  TabController controller,
  List<Widget> tabs,
) {
  return PreferredSize(
    // 46 (TabBar min height) + 4+4 (padding) + 10 (margins) + 2 slack
    preferredSize: const Size.fromHeight(66),
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 2, 12, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(9),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppTheme.textSecondary,
        labelStyle: const TextStyle(
            fontSize: 12.5, fontWeight: FontWeight.w700),
        tabs: tabs,
      ),
    ),
  );
}

/// Wraps the leading widget so the back button is clearly visible:
/// tinted with the primary blue and given a subtle circular badge.
Widget? _visibleLeading(Widget? leading) {
  if (leading == null) return null; // auto-implied back button (colored by foregroundColor)
  return Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Center(
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: IconTheme.merge(
          data: const IconThemeData(color: AppTheme.primary),
          child: leading,
        ),
      ),
    ),
  );
}

/// Common collapsible SliverAppBar config used across inline conversions.
SliverAppBar buildCollapsibleAppBar({
  required String title,
  Widget? titleWidget,
  Widget? leading,
  List<Widget>? actions,
  required TabController controller,
  required List<Widget> tabs,
}) {
  return SliverAppBar(
    leading: _visibleLeading(leading),
    title: titleWidget ??
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
    actions: actions,
    backgroundColor: AppTheme.surfaceCard,
    surfaceTintColor: Colors.transparent,
    foregroundColor: AppTheme.textPrimary,
    elevation: 0,
    scrolledUnderElevation: 0,
    pinned: true,
    floating: true,
    snap: true,
    bottom: buildCompactTabBar(controller, tabs),
  );
}

class CollapsibleTabScaffold extends StatelessWidget {
  final String title;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final TabController controller;
  final List<Widget> tabs;
  final Widget? header; // optional content below the app bar (e.g. summary card)
  final Widget body; // TabBarView or a plain scrollable

  const CollapsibleTabScaffold({
    super.key,
    required this.title,
    this.titleWidget,
    this.leading,
    this.actions,
    required this.controller,
    required this.tabs,
    this.header,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              leading: _visibleLeading(leading),
              title: titleWidget ??
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
              actions: actions,
              backgroundColor: AppTheme.surfaceCard,
              surfaceTintColor: Colors.transparent,
              foregroundColor: AppTheme.textPrimary,
              elevation: 0,
              scrolledUnderElevation: 0,
              pinned: true,
              floating: true,
              snap: true,
              bottom: buildCompactTabBar(controller, tabs),
            ),
            if (header != null) SliverToBoxAdapter(child: header!),
          ];
        },
        body: body,
      ),
    );
  }
}
