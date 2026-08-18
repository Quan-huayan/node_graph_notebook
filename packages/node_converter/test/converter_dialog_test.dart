/// ConverterDialog 错误反馈测试（UX/纪律 8：错误路径必须有用户可见反馈）。
///
/// 导入不存在的文件 / 导出失败 → SnackBar 提示（不再静默/未处理异常）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_converter/node_converter.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;
  late HostRuntime host;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_converter_dialog');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'root',
        title: '根目录',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[ConverterPlugin(servicesProvider: resolveServices)],
      rootNodeId: 'root',
    );
  });

  testWidgets('导入不存在的文件 → 失败 SnackBar（含可读文案）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConverterDialog(host: host)),
      ),
    );
    final ghost = '${root.path}${Platform.pathSeparator}ghost.json';
    await tester.enterText(find.byType(TextField), ghost);
    await tester.tap(find.text(host.i18nService.t('converter.import')));
    await tester.pump(); // 异步 dispatch + 失败路径。
    await tester.pump(const Duration(milliseconds: 100)); // SnackBar 入场。

    expect(
      find.textContaining(host.i18nService.t('converter.importFailed')),
      findsOneWidget,
    );

    // SnackBar 定时器清理。
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('导出成功 → 成功 SnackBar（导出路径回显）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConverterDialog(host: host)),
      ),
    );
    await tester.tap(find.text(host.i18nService.t('converter.exportAll')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.textContaining(
        host.i18nService.t('converter.exported').split('%s').first,
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
