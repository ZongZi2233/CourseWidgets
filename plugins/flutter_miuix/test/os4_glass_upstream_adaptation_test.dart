import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {bool dark = false, bool scaffold = false}) =>
    MiuixTheme(
      data: dark ? MiuixThemeData.dark() : MiuixThemeData.light(),
      child: MaterialApp(
        home: scaffold
            ? MiuixScaffold(content: (_) => child)
            : Scaffold(body: child),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(MiuixGlassRendering.load);

  test('OS4 材质预设、withUnderlayBlur 与 markAsUnread 图标名与上游对齐', () {
    expect(MiuixGlassMaterials.popupViewGlassLight.blurRadius, 60);
    expect(
      MiuixGlassMaterials.popupViewGlassLight.third?.color,
      const Color(0x99FFFFFF),
    );
    expect(
      MiuixGlassMaterials.popupViewGlassLight.third?.mode,
      MiuixGlassColorBlendMode.hardLight,
    );
    expect(
      MiuixGlassMaterials.popupViewGlassDark.second?.color,
      const Color(0x996C6C6C),
    );
    expect(
      MiuixGlassMaterials.popupViewGlassDark.second?.mode,
      MiuixGlassColorBlendMode.luminosity,
    );
    expect(
      MiuixGlassMaterials.popupViewGlassDark.third?.color,
      const Color(0x99060606),
    );
    expect(
      MiuixGlassMaterials.popupViewGlassDark.third?.mode,
      MiuixGlassColorBlendMode.softLight,
    );
    expect(
      MiuixGlassMaterials.dialogGlass(false),
      MiuixGlassMaterials.dialogGlassLight,
    );
    expect(
      MiuixGlassMaterials.dialogGlass(true),
      MiuixGlassMaterials.dialogGlassDark,
    );

    final nestedLight = MiuixGlassMaterials.puredThinGlassLight
        .withUnderlayBlur(MiuixGlassMaterials.actionBarMaskLight);
    expect(nestedLight.blurRadius, closeTo(math.sqrt(20 * 20 + 40 * 40), 1e-6));
    expect(
      MiuixGlassMaterials.puredThinGlassLight.withUnderlayBlur(null),
      MiuixGlassMaterials.puredThinGlassLight,
    );

    final unread = MiuixIcons.os4.markAsUnread;
    expect(MiuixIcons.os4.byName('markAsUnread'), same(unread));
    expect(MiuixIcons.os4.byName('markRasUnread'), same(unread));
    expect(MiuixIcons.os4.names.contains('markAsUnread'), isTrue);
  });

  test('下拉弹窗按 valueAnchor 就近边缘对齐', () {
    final leftFrame = miuixGlassPopupFrame(
      motion: MiuixGlassPopupMotion.dropdown,
      anchor: const Rect.fromLTWH(16, 100, 360, 48),
      valueAnchor: const Rect.fromLTWH(24, 108, 80, 32),
      end: const Size(200, 140),
      bounds: const Rect.fromLTWH(12, 24, 376, 600),
      progress: 1,
      positionProgress: 1,
    );
    expect(leftFrame.rect.left, closeTo(24, 0.01));

    final rightFrame = miuixGlassPopupFrame(
      motion: MiuixGlassPopupMotion.dropdown,
      anchor: const Rect.fromLTWH(16, 100, 360, 48),
      valueAnchor: const Rect.fromLTWH(280, 108, 80, 32),
      end: const Size(200, 140),
      bounds: const Rect.fromLTWH(12, 24, 376, 600),
      progress: 1,
      positionProgress: 1,
    );
    expect(rightFrame.rect.right, closeTo(360, 0.01));
  });

  testWidgets(
    'MiuixGlassDialog 与 MiuixGlassDialogButton 在 MiuixScaffold 内正常显示、关描边与关闭',
    (tester) async {
      final backdrop = MiuixLayerBackdrop();
      var show = false;
      var showStroke = true;
      var primaryTaps = 0;
      var disabledTaps = 0;
      var dismissFinished = 0;
      late StateSetter update;

      await tester.pumpWidget(
        _wrap(
          scaffold: true,
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Stack(
                children: [
                  MiuixLayerBackdropCapture(
                    backdrop: backdrop,
                    child: const ColoredBox(color: Color(0xFF335599)),
                  ),
                  MiuixGlassDialog(
                    show: show,
                    backdrop: backdrop,
                    title: 'Glass Dialog Title',
                    summary: 'Dialog summary text',
                    showStroke: showStroke,
                    onDismissRequest: () => setState(() => show = false),
                    onDismissFinished: () => dismissFinished++,
                    child: Row(
                      children: [
                        Expanded(
                          child: MiuixGlassDialogButton(
                            enabled: false,
                            role: MiuixGlassDialogButtonRole.destructive,
                            onPressed: () => disabledTaps++,
                            child: const Text('Delete'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: MiuixGlassDialogButton(
                            role: MiuixGlassDialogButtonRole.primary,
                            onPressed: () {
                              primaryTaps++;
                              setState(() => show = false);
                            },
                            child: const Text('Confirm'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      update(() => show = true);
      await tester.pumpAndSettle();
      expect(find.text('Glass Dialog Title'), findsOneWidget);
      expect(find.text('Dialog summary text'), findsOneWidget);
      final panel = tester.widget<MiuixGlassPanel>(
        find.byType(MiuixGlassPanel),
      );
      expect(panel.material, MiuixGlassMaterials.dialogGlassLight);
      expect(panel.stroke, MiuixGlassStrokes.smallLight);
      expect(panel.shadow, isNull);
      expect(panel.shading, isFalse);

      update(() => showStroke = false);
      await tester.pumpAndSettle();
      expect(
        tester.widget<MiuixGlassPanel>(find.byType(MiuixGlassPanel)).stroke,
        isNull,
      );

      await tester.tap(find.text('Delete'));
      expect(disabledTaps, 0);
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();
      expect(primaryTaps, 1);
      expect(dismissFinished, 1);
      expect(find.text('Glass Dialog Title'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      backdrop.dispose();
    },
  );

  testWidgets('MiuixGlassBottomSheet 渲染玻璃材质、支持关闭且不阻塞底层点击', (tester) async {
    final backdrop = MiuixLayerBackdrop();
    var show = false;
    var showStroke = true;
    var bgTaps = 0;
    late StateSetter update;

    await tester.pumpWidget(
      _wrap(
        scaffold: true,
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Stack(
              fit: StackFit.expand,
              children: [
                MiuixLayerBackdropCapture(
                  backdrop: backdrop,
                  child: Center(
                    child: MiuixButton(
                      onPressed: () {
                        bgTaps++;
                        setState(() => show = true);
                      },
                      child: const Text('Open Sheet'),
                    ),
                  ),
                ),
                MiuixGlassBottomSheet(
                  show: show,
                  backdrop: backdrop,
                  title: 'Glass Sheet',
                  showStroke: showStroke,
                  onDismissRequest: () => setState(() => show = false),
                  child: MiuixGlassDialogButton(
                    role: MiuixGlassDialogButtonRole.primary,
                    onPressed: () => setState(() => show = false),
                    child: const Text('Done'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Glass Sheet'), findsOneWidget);
    final panel = tester.widget<MiuixGlassPanel>(find.byType(MiuixGlassPanel));
    expect(panel.material, MiuixGlassMaterials.dialogGlassLight);
    expect(panel.stroke, MiuixGlassStrokes.middleLight);
    expect(panel.shadow, isNull);
    expect(panel.shading, isFalse);

    update(() => showStroke = false);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MiuixGlassPanel>(find.byType(MiuixGlassPanel)).stroke,
      isNull,
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Glass Sheet'), findsNothing);

    await tester.tap(find.text('Open Sheet'));
    await tester.pumpAndSettle();
    expect(bgTaps, 2);
    expect(find.text('Glass Sheet'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    backdrop.dispose();
  });

  testWidgets('MiuixGlassDropdownPreference 展开、选择、禁用与空列表行为正确', (tester) async {
    var selected = 1;
    var expandedEvents = <bool>[];
    var enabled = true;
    late StateSetter update;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Align(
              alignment: Alignment.topCenter,
              child: MiuixGlassDropdownPreference(
                title: 'Log level',
                items: const ['Verbose', 'Debug', 'Info'],
                selectedIndex: selected,
                enabled: enabled,
                onExpandedChange: expandedEvents.add,
                onSelectedIndexChange: (i) => setState(() => selected = i),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Debug'), findsOneWidget);

    await tester.tap(find.text('Log level'));
    await tester.pumpAndSettle();
    expect(expandedEvents, [true]);
    expect(find.text('Info'), findsOneWidget);

    await tester.tap(find.text('Info'));
    await tester.pumpAndSettle();
    expect(selected, 2);
    expect(expandedEvents, [true, false]);

    update(() => enabled = false);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log level'));
    await tester.pumpAndSettle();
    expect(expandedEvents, [true, false]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MiuixGlassIconDropdownMenu 支持一级与二级级联展开及选中收起', (tester) async {
    final anchor = MiuixGlassPopupAnchor();
    var show = false;
    var picked = '';

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: MiuixGlassIconButton(
                    anchor: anchor,
                    onPressed: () => setState(() => show = true),
                    child: const Icon(Icons.more_horiz),
                  ),
                ),
                MiuixGlassIconDropdownMenu(
                  show: show,
                  onDismissRequest: () => setState(() => show = false),
                  anchor: anchor,
                  anchorContent: const Icon(Icons.more_horiz),
                  entries: [
                    MiuixDropdownEntry(
                      items: [
                        MiuixDropdownItem(
                          text: 'Sort by',
                          summary: 'Updated',
                          children: [
                            MiuixDropdownItem(
                              text: 'Updated',
                              selected: true,
                              onClick: () => picked = 'Updated',
                            ),
                            MiuixDropdownItem(
                              text: 'Title',
                              onClick: () => picked = 'Title',
                            ),
                          ],
                        ),
                      ],
                    ),
                    MiuixDropdownEntry(
                      items: [
                        MiuixDropdownItem(
                          text: 'Settings',
                          onClick: () => picked = 'Settings',
                        ),
                      ],
                    ),
                  ],
                  collapseOnSelection: true,
                ),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(MiuixGlassIconButton));
    await tester.pumpAndSettle();
    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(MiuixHorizontalDivider), findsOneWidget);

    await tester.tap(find.text('Sort by'));
    await tester.pumpAndSettle();
    expect(find.text('Title'), findsOneWidget);

    await tester.tap(find.text('Title'));
    await tester.pumpAndSettle();
    expect(picked, 'Title');
    expect(show, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    anchor.dispose();
  });

  testWidgets('MiuixGlassTopAppBar 渐进模糊、描边开关与 inheritTopBarMaterial=false 按钮', (
    tester,
  ) async {
    final backdrop = MiuixLayerBackdrop();
    await tester.pumpWidget(
      _wrap(
        Stack(
          children: [
            Positioned.fill(
              child: MiuixLayerBackdropCapture(
                backdrop: backdrop,
                child: const ColoredBox(color: Color(0xFF224488)),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: MiuixGlassTopAppBar(
                title: 'Progressive',
                backdrop: backdrop,
                progressiveBlur: true,
                isContentScrolled: false,
                showStroke: false,
                actions: [
                  MiuixGlassIconButton(
                    key: const Key('inherited-btn'),
                    onPressed: () {},
                    child: const Icon(Icons.search),
                  ),
                  const SizedBox(width: 8),
                  MiuixGlassIconButton(
                    key: const Key('about-btn'),
                    inheritTopBarMaterial: false,
                    onPressed: () {},
                    child: const Icon(Icons.info_outline),
                  ),
                ],
                bottomContent: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: MiuixGlassSegmentedTabRow(
                    tabs: const ['One', 'Two'],
                    selectedIndex: 0,
                    onSelect: (_) {},
                    showStroke: false,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final inheritedPanel = tester.widget<MiuixGlassPanel>(
      find.descendant(
        of: find.byKey(const Key('inherited-btn')),
        matching: find.byType(MiuixGlassPanel),
      ),
    );
    final aboutPanel = tester.widget<MiuixGlassPanel>(
      find.descendant(
        of: find.byKey(const Key('about-btn')),
        matching: find.byType(MiuixGlassPanel),
      ),
    );
    expect(inheritedPanel.alpha, 0);
    expect(inheritedPanel.stroke, isNull);
    expect(inheritedPanel.underlayMaterial, isNull);
    expect(aboutPanel.alpha, 1);
    expect(aboutPanel.stroke, isNull);

    final segPanel = tester.widget<MiuixGlassPanel>(
      find.descendant(
        of: find.byType(MiuixGlassSegmentedTabRow),
        matching: find.byType(MiuixGlassPanel),
      ),
    );
    expect(segPanel.stroke, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    backdrop.dispose();
  });

  testWidgets('MiuixGlassNavigationBar trailingAction 独立响应且共享显隐过渡', (
    tester,
  ) async {
    var selected = 0;
    var searchTaps = 0;
    var visible = true;
    late StateSetter update;

    await tester.pumpWidget(
      _wrap(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MiuixGlassNavigationBar(
                  visible: visible,
                  selectedIndex: selected,
                  showStroke: false,
                  onSelect: (i) => setState(() => selected = i),
                  items: const [
                    MiuixGlassNavigationItem(
                      icon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    MiuixGlassNavigationItem(
                      icon: Icon(Icons.settings),
                      label: 'Set',
                    ),
                  ],
                  trailingAction: MiuixGlassIconButton(
                    key: const Key('nav-search'),
                    size: MiuixGlassNavigationBarDefaults.height,
                    showStroke: false,
                    onPressed: () => searchTaps++,
                    child: const Icon(Icons.search),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav-search')));
    await tester.pumpAndSettle();
    expect(searchTaps, 1);
    expect(selected, 0);

    await tester.tap(find.text('Set'));
    await tester.pumpAndSettle();
    expect(selected, 1);

    update(() => visible = false);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nav-search')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('MiuixGlassPopupItem 选中态与未选中态宽度一致不跳动', (tester) async {
    await tester.pumpWidget(
      _wrap(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IntrinsicWidth(
                key: const Key('unselected-item'),
                child: MiuixGlassPopupItem(
                  text: 'Item Label',
                  selected: false,
                  onPressed: () {},
                ),
              ),
              IntrinsicWidth(
                key: const Key('selected-item'),
                child: MiuixGlassPopupItem(
                  text: 'Item Label',
                  selected: true,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getSize(find.byKey(const Key('selected-item'))).width,
      closeTo(
        tester.getSize(find.byKey(const Key('unselected-item'))).width,
        0.01,
      ),
    );
  });
}
