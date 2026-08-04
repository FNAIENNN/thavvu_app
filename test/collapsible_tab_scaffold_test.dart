// test/collapsible_tab_scaffold_test.dart
//
// Verifies the shared module scaffold renders:
//  - the back button (leading) clearly with the primary blue color
//  - the compact tab bar with all tabs
//  - the scaffold still allows the app bar (pinned) after a scroll

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:thavvu_app/theme/app_theme.dart';
import 'package:thavvu_app/widgets/collapsible_tab_scaffold.dart';

void main() {
  testWidgets('back button renders visibly with primary color',
      (tester) async {
    final controller = TabController(length: 2, vsync: tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CollapsibleTabScaffold(
          title: 'Test Module',
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {},
          ),
          controller: controller,
          tabs: const [
            Tab(text: 'One'),
            Tab(text: 'Two'),
          ],
          body: TabBarView(
            controller: controller,
            children: const [
              SingleChildScrollView(child: Text('Content A')),
              SingleChildScrollView(child: Text('Content B')),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Back button is present and visible.
    final backFinder = find.byIcon(Icons.arrow_back);
    expect(backFinder, findsOneWidget);

    // The shared widget tints the leading icon with the primary blue via
    // an IconTheme merge — verify the theme data in the tree.
    final iconThemes = tester
        .widgetList<IconTheme>(find.byType(IconTheme))
        .where((t) => t.data.color == AppTheme.primary)
        .length;
    expect(iconThemes, greaterThanOrEqualTo(1));

    // Compact tab labels render.
    expect(find.text('One'), findsOneWidget);
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Test Module'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('app bar stays pinned after scrolling content',
      (tester) async {
    final controller = TabController(length: 1, vsync: tester);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CollapsibleTabScaffold(
          title: 'Pinned Module',
          controller: controller,
          tabs: const [Tab(text: 'List')],
          body: TabBarView(
            controller: controller,
            children: [
              ListView.builder(
                itemCount: 50,
                itemBuilder: (_, i) => ListTile(title: Text('Item $i')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Scroll the content.
    await tester.drag(find.byType(ListView), const Offset(0, -800));
    await tester.pumpAndSettle();

    // The pinned app bar stays visible after scrolling (no overflow).
    expect(find.text('Pinned Module'), findsOneWidget);

    controller.dispose();
  });
}
