/// Search 插件测试（M7，01 拍板 #36）：标题/内容包含匹配、kind 过滤。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_search/node_search.dart';
import 'package:plugon/plugon.dart';

void main() {
  late HostRuntime host;

  setUp(() async {
    final root = Directory.systemTemp.createTempSync('ngn_search');
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
      StoredNode(id: 'a', title: 'Flutter 笔记', createdAt: now, updatedAt: now),
      StoredNode(
        id: 'b',
        title: 'Dart 语言',
        content: '关于 flutter 的思考',
        createdAt: now,
        updatedAt: now,
      ),
    ].forEach(host.graph.save);
    await host.start(plugins: <Plugin>[SearchPlugin()], rootNodeId: 'root');
  });

  test('标题命中优先排序 + 内容命中', () {
    final service = host.serviceProvider.get<SearchService>();
    final results = service.search(const SearchQuery(text: 'flutter'));
    expect(results.map((n) => n.id), <String>['a', 'b']); // 标题命中优先。
  });

  test('kind 过滤 + 大小写不敏感', () {
    final service = host.serviceProvider.get<SearchService>();
    expect(
      service.search(const SearchQuery(text: 'FLUTTER')).map((n) => n.id),
      <String>['a', 'b'],
    );
    expect(
      service
          .search(const SearchQuery(text: '根', kind: 'folder'))
          .map((n) => n.id),
      <String>['root'],
    );
  });

  test('C3 文件夹过滤：folderId → 仅 contain.parent 成员', () {
    final now = DateTime.now();
    host.graph.save(
      StoredNode(
        id: 'folderA',
        title: '文件夹A',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
    );
    host.graph.save(
      StoredNode(id: 'in-folder', title: '文件夹内笔记', createdAt: now, updatedAt: now),
    );
    // contain 实例（L1：父文件夹 → 子笔记）。
    host.graph.save(
      StoredNode(
        id: 'contain-1',
        title: '包含',
        references: const <String, String>{'parent': 'folderA', 'child': 'in-folder'},
        createdAt: now,
        updatedAt: now,
      ),
    );
    final service = host.serviceProvider.get<SearchService>();
    expect(
      service
          .search(const SearchQuery(text: '', folderId: 'folderA'))
          .map((n) => n.id),
      <String>['in-folder'],
    );
    // 不存在/无成员的文件夹 → 空。
    expect(
      service.search(const SearchQuery(text: '', folderId: 'missing')).isEmpty,
      isTrue,
    );
  });

  test('A2 标签过滤：SearchQuery.tag（内容 #tag ∪ metadata.tags）', () {
    host.graph.save(
      StoredNode(
        id: 'tagged',
        title: '标签笔记',
        content: '计划 #工作 事项',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    host.graph.save(
      StoredNode(
        id: 'meta-tagged',
        title: '元数据标签',
        metadata: const <String, dynamic>{'tags': <String>['工作']},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final service = host.serviceProvider.get<SearchService>();
    final results = service
        .search(const SearchQuery(text: '', tag: '工作'))
        .map((n) => n.id)
        .toSet();
    expect(results, <String>{'tagged', 'meta-tagged'});
  });
}
