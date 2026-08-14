/// 主题接线测试（M7.2，E3：拍板 #39"组合根读取应用"——NotebookApp
/// 经 ThemeController 响应运行时切换）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ThemeController 持久化：setter 保存 → 新实例 attach 恢复（P1-1）', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();

    final first = ThemeController()..attach(prefs);
    first.setMode(AppThemeMode.dark);
    first.setTextScale(1.25);
    first.setFontFamily('serif');
    expect(prefs.getString('settings.themeMode'), 'dark');
    expect(prefs.getDouble('settings.textScale'), 1.25);
    expect(prefs.getString('settings.fontFamily'), 'serif');

    // 模拟重启：新实例 + 同一 prefs → 恢复上次值。
    final second = ThemeController()..attach(prefs);
    expect(second.mode, AppThemeMode.dark);
    expect(second.textScale, 1.25);
    expect(second.fontFamily, 'serif');
  });

  test('ThemeController 持久化：未绑定（null）→ 纯内存，不落盘', () {
    final controller = ThemeController()..attach(null);
    controller.setMode(AppThemeMode.light);
    expect(controller.mode, AppThemeMode.light);
  });

  testWidgets('ThemeController 切换 → MaterialApp themeMode 即时响应', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('ngn_theme');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    host.graph.save(
      StoredNode(id: 'root', title: '根', createdAt: now, updatedAt: now),
    );
    final controller = ThemeController();

    await tester.pumpWidget(
      NotebookApp(host: host, rootNodeId: 'root', themeController: controller),
    );
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    controller.setMode(AppThemeMode.dark);
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );

    controller.setMode(AppThemeMode.light);
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
  });

  testWidgets('无控制器（测试/无设置场景）：固定跟随系统', (tester) async {
    final root = Directory.systemTemp.createTempSync('ngn_theme2');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    host.graph.save(
      StoredNode(id: 'root', title: '根', createdAt: now, updatedAt: now),
    );

    await tester.pumpWidget(NotebookApp(host: host, rootNodeId: 'root'));

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );
  });
}
