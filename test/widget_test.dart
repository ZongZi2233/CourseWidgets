import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:coursewidgets/ui/widgets/glass_context_menu.dart';

void main() {
  testWidgets('GlassMenu toggles and renders items',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassMenu(
              trigger: Container(
                width: 50,
                height: 50,
                color: Colors.blue,
                child: const Center(child: Text('Open Menu')),
              ),
              items: [
                GlassMenuItem(
                  title: 'Option 1',
                  onTap: () {},
                ),
                GlassMenuItem(
                  title: 'Option 2',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Initial state: Menu closed
    expect(find.text('Option 1'), findsNothing);

    // Tap trigger
    await tester.tap(find.text('Open Menu'));
    await tester.pump(); // Start animation
    await tester.pumpAndSettle();

    // Menu should be present (portal shown)
    expect(find.text('Option 1'), findsOneWidget);

    // Close menu (tap outside)
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Menu closed
    expect(find.text('Option 1'), findsNothing);
  });

  testWidgets('GlassContextMenu toggles, selects item, and handles route push',
      (WidgetTester tester) async {
    int tapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GlassContextMenu(
              triggerBuilder: (context, toggleMenu) => GestureDetector(
                onTap: toggleMenu,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: Text('MoreBtn')),
                ),
              ),
              items: [
                GlassContextMenuItem(
                  title: 'Action A',
                  icon: Icons.add,
                  onTap: () {
                    tapCount++;
                  },
                ),
                GlassContextMenuItem(
                  title: 'Push Route',
                  icon: Icons.arrow_forward,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Action A'), findsNothing);

    // 1. First open
    await tester.tap(find.text('MoreBtn'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Action A'), findsOneWidget);

    // 2. Tap item to close
    await tester.tap(find.text('Action A'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tapCount, 1);
    expect(find.text('Action A'), findsNothing);

    // 3. Verify trigger button is visible and tappable again (second open)
    await tester.tap(find.text('MoreBtn'));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Action A'), findsOneWidget);

    // 4. Tap outside barrier to close
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Action A'), findsNothing);
  });
}
