/// Converter 插件测试（M7，01 拍板 #37）：JSON 往返保真、导入宽容。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_converter/node_converter.dart';
import 'package:plugon/plugon.dart';

void main() {
  late Directory root;
  late HostRuntime host;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('ngn_converter');
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
        id: 'noteA',
        title: '笔记A',
        content: '# 内容',
        references: const <String, String>{'related': 'root'},
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

  test('Export → Import 往返保真（结构/内容/引用/元数据）', () async {
    final path = '${root.path}${Platform.pathSeparator}export.json';
    await host.commandBus.dispatch<ExportCommand, ExportResult>(
      ExportCommand(path: path),
    );
    // 清库后导入。
    for (final node in host.graph.getAll().toList()) {
      host.graph.delete(node.id);
    }
    final result = await host.commandBus.dispatch<ImportCommand, ImportResult>(
      ImportCommand(path: path),
    );
    expect(result.importedNodeIds, <String>{'root', 'noteA'});
    final note = host.graph.get('noteA')!;
    expect(note.title, '笔记A');
    expect(note.content, '# 内容');
    expect(note.references['related'], 'root');
    expect(host.graph.get('root')!.metadata['kind'], 'folder');
  });

  test('Export 指定节点子集', () async {
    final path = '${root.path}${Platform.pathSeparator}subset.json';
    final result = await host.commandBus.dispatch<ExportCommand, ExportResult>(
      ExportCommand(path: path, nodeIds: <String>{'noteA'}),
    );
    expect(result.exportedCount, 1);
    final file = File(path);
    expect(file.readAsStringSync(), contains('noteA'));
    // 不含 root 节点条目（引用值 'root' 出现在 noteA 的 references 中，
    // 断言精确到节点条目）。
    expect(file.readAsStringSync(), isNot(contains('"id": "root"')));
  });

  test('导入文件不存在 → StateError', () async {
    expect(
      () => host.commandBus.dispatch<ImportCommand, ImportResult>(
        ImportCommand(path: '${root.path}${Platform.pathSeparator}ghost.json'),
      ),
      throwsStateError,
    );
  });

  test('P2-5 契约：空库导出 → 0 节点 + 空数组', () async {
    for (final node in host.graph.getAll().toList()) {
      host.graph.delete(node.id);
    }
    final path = '${root.path}${Platform.pathSeparator}empty.json';
    final result = await host.commandBus.dispatch<ExportCommand, ExportResult>(
      ExportCommand(path: path),
    );
    expect(result.exportedCount, 0);
    expect(File(path).readAsStringSync().trim(), '[]');
  });

  test('P2-5 契约：JSON 坏条目跳过（导入宽容不崩溃）', () async {
    final path = '${root.path}${Platform.pathSeparator}mixed.json';
    File(path).writeAsStringSync('''
[
  {"id": "ok1", "title": "好节点"},
  {"foo": 1},
  "字符串条目",
  {"id": "ok2", "title": "另一个", "content": "内容"}
]
''');
    final result = await host.commandBus.dispatch<ImportCommand, ImportResult>(
      ImportCommand(path: path),
    );
    expect(result.importedNodeIds, <String>{'ok1', 'ok2'});
    expect(host.graph.get('ok1')!.title, '好节点');
  });

  test('P2-5 契约：markdown 重导幂等（标题派生 id）', () async {
    final path = '${root.path}${Platform.pathSeparator}notes.md';
    File(path).writeAsStringSync(
      '# 笔记本\n\n## 第一篇\n\n内容一\n\n## 第二篇\n\n内容二\n',
    );
    for (var round = 0; round < 2; round++) {
      await host.commandBus.dispatch<ImportCommand, ImportResult>(
        ImportCommand(path: path),
      );
    }
    final imported = host
        .graph
        .getAll()
        .where((n) => n.id.startsWith('imported-'))
        .toList();
    expect(imported, hasLength(2)); // 重导 = 更新，不产生重复节点。
    expect(host.graph.get('imported-第一篇')!.content, '内容一');
  });
}
