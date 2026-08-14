/// FSTGraph 行为测试（architecture.md §6：sidecar 分区 / 原子写 /
/// 懒加载 / 二级索引 / 损坏兜底）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

StoredNode _node(
  String id, {
  String title = 't',
  Map<String, dynamic>? metadata,
}) => StoredNode(
  id: id,
  title: title,
  content: '内容 $id',
  references: const <String, String>{},
  metadata: metadata ?? const <String, dynamic>{},
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

void main() {
  group('FSTGraph（architecture.md §6）', () {
    late Directory root;
    late FSTGraph graph;

    setUp(() {
      root = createTempDir('fs_graph');
      graph = FSTGraph(dataRoot: root);
    });

    test('save → get 往返；结构 + 内容镜像双写', () {
      graph.save(
        _node(
          '3f5a9c2e',
          title: '我的笔记',
          metadata: const <String, dynamic>{
            'tags': <String>['工作'],
          },
        ),
      );

      final node = graph.get('3f5a9c2e');
      expect(node, isNotNull);
      expect(node!.title, '我的笔记');
      expect(node.content, '内容 3f5a9c2e');
      expect(node.metadata['tags'], <String>['工作']);

      // 内容镜像落盘（00 §3.2：数据目录是文件树，可外部管理）。
      final mirror = File(
        '${root.path}${Platform.pathSeparator}files'
        '${Platform.pathSeparator}note${Platform.pathSeparator}3f'
        '${Platform.pathSeparator}3f5a9c2e_我的笔记.md',
      );
      expect(mirror.existsSync(), isTrue);
      expect(mirror.readAsStringSync(), '内容 3f5a9c2e');
    });

    test('sidecar 哈希分区：id 前两位建目录（256 分区）', () {
      graph.save(_node('aabbccdd'));
      graph.save(_node('ccddeeff'));

      expect(
        Directory(
          '${root.path}${Platform.pathSeparator}.node'
          '${Platform.pathSeparator}aa',
        ),
        isNotNull,
      );
      expect(
        File(
          '${root.path}${Platform.pathSeparator}.node'
          '${Platform.pathSeparator}aa${Platform.pathSeparator}aabbccdd.node.json',
        ).existsSync(),
        isTrue,
      );
      expect(
        File(
          '${root.path}${Platform.pathSeparator}.node'
          '${Platform.pathSeparator}cc${Platform.pathSeparator}ccddeeff.node.json',
        ).existsSync(),
        isTrue,
      );
    });

    test('原子写：无 .tmp 残留；整体替换同 id', () {
      graph.save(_node('aaaabbbb', title: '旧'));
      graph.save(_node('aaaabbbb', title: '新'));

      expect(graph.get('aaaabbbb')!.title, '新');
      final partition = Directory(
        '${root.path}${Platform.pathSeparator}.node${Platform.pathSeparator}aa',
      );
      final tmpFiles = partition.listSync().where(
        (e) => e.path.endsWith('.tmp'),
      );
      expect(tmpFiles, isEmpty);
    });

    test('损坏 sidecar → 兜底加载（可编辑状态），不抛', () {
      graph.save(_node('deadbeef'));
      final sidecar = File(
        '${root.path}${Platform.pathSeparator}.node'
        '${Platform.pathSeparator}de${Platform.pathSeparator}deadbeef.node.json',
      );
      sidecar.writeAsStringSync('{ not valid json');

      final node = graph.get('deadbeef');
      expect(node, isNotNull);
      expect(node!.title, contains('[损坏节点]'));
    });

    test('getByMetadata：冷启动构建 + 变更增量更新', () {
      graph.save(
        _node('11111111', metadata: const <String, dynamic>{'kind': 'note'}),
      );
      graph.save(
        _node('22222222', metadata: const <String, dynamic>{'kind': 'folder'}),
      );

      expect(graph.getByMetadata('kind', 'note').map((n) => n.id), <String>[
        '11111111',
      ]);

      // 变更增量更新：修改 kind 后索引即时反映。
      graph.save(
        _node('11111111', metadata: const <String, dynamic>{'kind': 'folder'}),
      );
      expect(graph.getByMetadata('kind', 'note'), isEmpty);
      expect(
        graph.getByMetadata('kind', 'folder').map((n) => n.id).toSet(),
        <String>{'11111111', '22222222'},
      );
    });

    test('delete：sidecar + 内容镜像 + 索引同步清理', () {
      graph.save(_node('55555555'));
      graph.delete('55555555');

      expect(graph.get('55555555'), isNull);
      expect(graph.getByMetadata('kind', 'note'), isEmpty);
      // 内容镜像同步删除（文件不残留；空目录无害，下次写复用）。
      expect(
        File(
          '${root.path}${Platform.pathSeparator}files'
          '${Platform.pathSeparator}note${Platform.pathSeparator}55'
          '${Platform.pathSeparator}55555555_t.md',
        ).existsSync(),
        isFalse,
      );
    });

    test('重启恢复：新实例从磁盘读回全部结构', () {
      graph.save(
        _node(
          '66666666',
          title: '持久化',
          metadata: const <String, dynamic>{'kind': 'note'},
        ),
      );

      final reopened = FSTGraph(dataRoot: root);

      expect(reopened.get('66666666')!.title, '持久化');
      expect(reopened.scanIndex().keys, <String>{'66666666'});
      expect(reopened.getByMetadata('kind', 'note').map((n) => n.id), <String>[
        '66666666',
      ]);
    });
  });
}
