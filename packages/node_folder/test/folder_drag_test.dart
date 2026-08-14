/// 文件夹拖拽源测试（M7.2，E2：03 判据① 侧边栏重排含 folder——
/// FolderView 也是拖拽源，嵌套文件夹 = contain 数据命令）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_folder/node_folder.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_folderdrag');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  testWidgets('拖 folderA 到 folderB → contain 实例（parent=B, child=A）', (
    tester,
  ) async {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'root',
        title: '根目录',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'folderA',
        title: '文件夹A',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'folderB',
        title: '文件夹B',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    ServiceProvider resolveServices() => host.serviceProvider;
    await host.start(
      plugins: <Plugin>[FolderPlugin(servicesProvider: resolveServices)],
      rootNodeId: 'root',
      rootKind: 'sidebar',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // folderA / folderB 并排的 FolderView（均为拖拽源 + 目标）。
              SizedBox(
                width: 200,
                child: FolderView(
                  host: host,
                  node: host.graph.get('folderA')!,
                  kind: 'sidebar',
                ),
              ),
              SizedBox(
                width: 200,
                child: FolderView(
                  host: host,
                  node: host.graph.get('folderB')!,
                  kind: 'sidebar',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // 拖 folderA 卡片到 folderB 卡片（判据①：contain 数据命令）。
    final from = tester.getCenter(find.text('文件夹A'));
    final to = tester.getCenter(find.text('文件夹B'));
    final gesture = await tester.startGesture(from);
    await gesture.moveTo(to);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    final contain = host.graph.getAll().firstWhere(
      (n) => n.references['child'] == 'folderA',
    );
    expect(contain.references, <String, String>{
      'parent': 'folderB',
      'child': 'folderA',
    });
  });
}
