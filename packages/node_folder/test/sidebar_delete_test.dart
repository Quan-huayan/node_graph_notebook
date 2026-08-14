/// 侧边栏删除入口测试（P1-5）：
///
/// 文件夹行删除按钮 → 共用确认对话框（appframe 壳）→ DeleteNodeCommand
/// 写路径（DTO 在 core——node_folder 零 node_graph 依赖，04 §三 约束 3；
/// 测试以桩 Handler 替代 graph 插件贡献）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:node_folder/node_folder.dart';

/// 桩删除 Handler（测试替代 GraphPlugin 贡献）。
class _StubDeleteHandler
    extends CommandHandler<DeleteNodeCommand, DeleteNodeResult> {
  _StubDeleteHandler(this.graph);

  final Graph graph;

  @override
  Type get commandType => DeleteNodeCommand;

  @override
  Future<DeleteNodeResult> handle(DeleteNodeCommand command) async {
    graph.delete(command.nodeId);
    return DeleteNodeResult(affectedNodeIds: <String>{command.nodeId});
  }
}

void main() {
  late Directory root;
  late HostRuntime host;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_sidebar_del');
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
      StoredNode(
        id: 'folderA',
        title: '文件夹A',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    host.commandBus.register(_StubDeleteHandler(host.graph));
  });

  testWidgets('删除入口：确认 → 节点删除', (tester) async {
    final folderA = host.graph.get('folderA')!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FolderView(host: host, node: folderA, kind: 'sidebar'),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    // 确认对话框（共用壳文案）。
    expect(find.text(host.i18nService.t('node.deleteTitle')), findsOneWidget);

    await tester.tap(find.text(host.i18nService.t('node.delete')));
    await tester.pumpAndSettle();
    expect(host.graph.get('folderA'), isNull);
  });

  testWidgets('删除入口：取消 → 节点保留', (tester) async {
    final folderA = host.graph.get('folderA')!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FolderView(host: host, node: folderA, kind: 'sidebar'),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text(host.i18nService.t('dialog.cancel')));
    await tester.pumpAndSettle();
    expect(host.graph.get('folderA'), isNotNull);
  });

  testWidgets('根容器：无删除入口（数据树地基不可删）', (tester) async {
    final rootNode = host.graph.get('root')!;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FolderView(host: host, node: rootNode, kind: 'sidebar-root'),
        ),
      ),
    );
    expect(find.byIcon(Icons.delete_outline), findsNothing);
  });
}
