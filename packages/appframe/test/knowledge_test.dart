/// 知识语义壳层服务测试（A2 标签 / A3 反链）。
///
/// 覆盖：TagService.parseTags（CJK 标签 / 代码区排除 / 边界）/ nodesForTag
/// （内容 ∪ metadata）/ tagsWithCount；BacklinkService.linkedBacklinks（关系
/// 实例对端 / UI 代理排除 / 自排除）/ unlinkedMentions（内容提及 / 短标题
/// 不匹配 / 带引用节点跳过）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

FSTGraph _graph(Directory root) => FSTGraph(dataRoot: root);

void _saveNode(
  FSTGraph graph,
  String id, {
  required String title,
  String? content,
  Map<String, String>? references,
  Map<String, dynamic>? metadata,
}) {
  graph.save(
    StoredNode(
      id: id,
      title: title,
      content: content,
      references: references ?? const <String, String>{},
      metadata: metadata ?? const <String, dynamic>{},
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    ),
  );
}

void main() {
  group('TagService（A2）', () {
    test('parseTags：中文/英文/连字符标签 + 去重', () {
      const content = '计划 #工作 #工作 #react-notes 正文';
      final tags = TagService.parseTags(content);
      expect(tags, <String>{'工作', 'react-notes'});
    });

    test('parseTags：代码区排除（围栏 + 行内码）', () {
      const content = '#标题\n```\n#code-tag\n```\n行内 `#inline-tag` 保留外 #out';
      final tags = TagService.parseTags(content);
      expect(tags, <String>{'标题', 'out'});
      expect(tags, isNot(contains('code-tag')));
      expect(tags, isNot(contains('inline-tag')));
    });

    test('parseTags：边界（a#b 非标签；C# 非标签）', () {
      const content = 'a#b 语言 C# 与 #tag';
      final tags = TagService.parseTags(content);
      expect(tags, <String>{'tag'});
    });

    test('nodesForTag：内容标签 ∪ metadata.tags 双来源', () {
      final root = createTempDir('tag_service');
      final graph = _graph(root);
      _saveNode(graph, 'n1', title: '一', content: '提到 #工作 的事');
      _saveNode(graph, 'n2', title: '二', metadata: <String, dynamic>{
        'tags': <String>['工作'],
      });
      _saveNode(graph, 'n3', title: '三', content: '无关');

      final service = TagService(graph: graph);
      expect(
        service.nodesForTag('工作').map((n) => n.id).toSet(),
        <String>{'n1', 'n2'},
      );
    });

    test('tagsWithCount：计数降序', () {
      final root = createTempDir('tag_count');
      final graph = _graph(root);
      _saveNode(graph, 'n1', title: '一', content: '#a #b');
      _saveNode(graph, 'n2', title: '二', content: '#a');
      _saveNode(graph, 'n3', title: '三', content: '#c');

      final counts = TagService(graph: graph).tagsWithCount();
      expect(counts['a'], 2);
      expect(counts['b'], 1);
      expect(counts['c'], 1);
      // 计数降序：a 在前。
      expect(counts.keys.toList().first, 'a');
    });
  });

  group('BacklinkService（A3）', () {
    test('linkedBacklinks：关系实例对端（connect 双端）', () {
      final root = createTempDir('backlink');
      final graph = _graph(root);
      // 连接实例：references {from, to}——指向目标 n2 的关系给出对端 n1。
      _saveNode(
        graph,
        'edge1',
        title: '连接1',
        references: <String, String>{'from': 'n1', 'to': 'n2'},
      );
      _saveNode(graph, 'n1', title: '甲');
      _saveNode(graph, 'n2', title: '乙');

      final links =
          BacklinkService(graph: graph).linkedBacklinks('n2').map((n) => n.id);
      expect(links, <String>['n1']);
    });

    test('linkedBacklinks：UI 代理排除（canvas 等 kind 不参与）', () {
      final root = createTempDir('backlink_proxy');
      final graph = _graph(root);
      _saveNode(
        graph,
        'edge2',
        title: '连接2',
        references: <String, String>{'from': 'canvas', 'to': 'n2'},
      );
      _saveNode(
        graph,
        'canvas',
        title: '画布',
        metadata: const <String, dynamic>{'kind': 'canvas'},
      );
      _saveNode(graph, 'n2', title: '乙');

      final links =
          BacklinkService(graph: graph).linkedBacklinks('n2').map((n) => n.id);
      expect(links, isEmpty);
    });

    test('unlinkedMentions：content 含标题 → 提及；自排除', () {
      final root = createTempDir('mention');
      final graph = _graph(root);
      _saveNode(graph, 'target', title: '目标笔记');
      _saveNode(graph, 'm1', title: '提到', content: '我引用了 目标笔记 的观点');
      _saveNode(graph, 'm2', title: '无关', content: '别的内容');

      final mentions =
          BacklinkService(graph: graph).unlinkedMentions('target')
              .map((n) => n.id);
      expect(mentions, <String>['m1']);
    });

    test('unlinkedMentions：短标题不匹配（防泛标题误报）', () {
      final root = createTempDir('mention_short');
      final graph = _graph(root);
      _saveNode(graph, 't', title: '它');
      _saveNode(graph, 'm', title: '提到', content: '它 出现在这里');

      final mentions = BacklinkService(graph: graph).unlinkedMentions('t');
      expect(mentions, isEmpty);
    });

    test('unlinkedMentions：已建立引用的节点不算提及', () {
      final root = createTempDir('mention_ref');
      final graph = _graph(root);
      _saveNode(graph, 'target', title: '目标笔记');
      _saveNode(
        graph,
        'm1',
        title: '已链接',
        content: '目标笔记 见',
        references: const <String, String>{'related': 'target'},
      );

      final mentions =
          BacklinkService(graph: graph).unlinkedMentions('target');
      expect(mentions, isEmpty);
    });
  });
}