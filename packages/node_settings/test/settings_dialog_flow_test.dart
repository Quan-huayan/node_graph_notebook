/// 设置动作对话框复现测试（M7.2 冻结排查：打开 → 语言切换 →
/// 字体切换 → 关闭 → 重开——验证无重建死循环）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_settings/node_settings.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_setflow');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  testWidgets('设置动作对话框：打开 → 语言切换 → 字体切换 → 关闭重开', (tester) async {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'toolbar-root',
        title: '工具栏',
        metadata: const <String, dynamic>{'kind': 'toolbar-root'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'toolbar-settings',
        title: '设置',
        metadata: const <String, dynamic>{
          'kind': 'toolbar',
          'icon': 'settings',
          'tooltip': '设置',
          'action': 'settings.open',
        },
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'root',
        title: '根目录',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'settings-root',
        title: '设置',
        metadata: const <String, dynamic>{'kind': 'settings-root'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'settings-theme',
        title: '主题',
        references: const <String, String>{'settings': 'settings-root'},
        metadata: const <String, dynamic>{'kind': 'settings-theme'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'settings-i18n',
        title: '语言',
        references: const <String, String>{'settings': 'settings-root'},
        metadata: const <String, dynamic>{'kind': 'settings-i18n'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'settings-appearance',
        title: '外观',
        references: const <String, String>{'settings': 'settings-root'},
        metadata: const <String, dynamic>{'kind': 'settings-appearance'},
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[SettingsPlugin(servicesProvider: resolveServices)],
      rootNodeId: 'root',
      rootKind: 'sidebar',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(host: host, rootNodeId: 'root'),
      ),
    );
    await tester.pump();

    // M7.3 修正：AppBar 标题 = 应用名（旧实现 = 根节点标题'根目录'，
    // 左上角非常奇怪；'根目录'仍作为侧边栏树根文件夹名存在）。
    expect(find.text('节点图谱笔记'), findsOneWidget);

    // 打开设置（经真实工具栏动作路径）。
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('主题'), findsOneWidget);

    // 字体切换（触发 ThemeController 通知 → MaterialApp 重建路径）。
    // （注：语言切换断言依赖 node_i18n 插件的语言条目——本测试
    // 只装配 SettingsPlugin，语言流程由 node_i18n 侧测试覆盖。
    // 选项文案 = i18n 键（默认 zh → '大'，非 'Large'）。）
    // 条目列表可滚动——外观条目（含字体选项）滚动到可视区。
    await tester.scrollUntilVisible(
      find.text('大'),
      100,
      scrollable: find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(find.text('大'));
    await tester.pumpAndSettle();
    expect(host.themeController.textScale, 1.25);

    // 关闭 → 重开（回收/重物化路径）。
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(find.text('主题'), findsOneWidget);
  });
}
