/// Markdown 聚合/拆分测试（M7.2，B：旧版能力恢复——## 分段聚合导出、
/// 按 ## 拆分导入）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_converter/node_converter.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_md');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
  });

  Future<HostRuntime> seed() async {
    final host = HostRuntime(dataRoot: root);
    final now = DateTime.now();
    <StoredNode>[
      StoredNode(
        id: 'a',
        title: '笔记A',
        content: 'A 的正文',
        createdAt: now,
        updatedAt: now,
      ),
      StoredNode(
        id: 'b',
        title: '笔记B',
        content: 'B 的正文',
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    await host.start(
      plugins: <Plugin>[ConverterPlugin()],
      rootNodeId: 'a',
      rootKind: 'sidebar',
    );
    return host;
  }

  test('导出 .md → 聚合文档（## 分段）；再导入 → 拆分为节点', () async {
    final host = await seed();
    final mdPath = '${root.path}${Platform.pathSeparator}export.md';

    final exported = await host.commandBus
        .dispatch<ExportCommand, ExportResult>(ExportCommand(path: mdPath));
    expect(exported.exportedCount, 2);

    final md = File(mdPath).readAsStringSync();
    expect(md, contains('## 笔记A'));
    expect(md, contains('## 笔记B'));
    expect(md, contains('A 的正文'));

    // 导入拆分（导入到新 host 验证拆分而非覆盖）。
    final host2 = HostRuntime(dataRoot: Directory('${root.path}2'));
    await host2.start(
      plugins: <Plugin>[ConverterPlugin()],
      rootNodeId: 'a',
      rootKind: 'sidebar',
    );
    final imported = await host2.commandBus
        .dispatch<ImportCommand, ImportResult>(ImportCommand(path: mdPath));
    expect(imported.importedNodeIds, hasLength(2));
    expect(
      host2.graph.getAll().map((n) => n.title),
      containsAll(<String>['笔记A', '笔记B']),
    );
  });

  test('导出 .json 仍往返保真（引用/元数据）', () async {
    final host = await seed();
    final jsonPath = '${root.path}${Platform.pathSeparator}export.json';
    await host.commandBus.dispatch<ExportCommand, ExportResult>(
      ExportCommand(path: jsonPath),
    );

    final host2 = HostRuntime(dataRoot: Directory('${root.path}2'));
    await host2.start(
      plugins: <Plugin>[ConverterPlugin()],
      rootNodeId: 'a',
      rootKind: 'sidebar',
    );
    await host2.commandBus.dispatch<ImportCommand, ImportResult>(
      ImportCommand(path: jsonPath),
    );

    expect(host2.graph.get('a')!.content, 'A 的正文');
    expect(host2.graph.get('b')!.title, '笔记B');
  });
}
