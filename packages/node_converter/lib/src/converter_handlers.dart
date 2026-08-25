/// 导入导出 Handler（M7 converter 插件，写操作唯一执行者，01-D）。
///
/// **双格式**（M7.2，用户裁决——恢复旧 markdown 聚合/拆分能力）：
/// - JSON（.json）：往返保真（01 拍板 #37）——节点字段序列化
/// - Markdown（.md）：**聚合/拆分**——导出 = 多节点聚合为单文档
///   （`## 标题` 分段）；导入 = 按 `## ` 拆分为节点（旧版行为）。
///
/// 格式按路径后缀推断。Markdown 只保 title/content（kind 等元数据
/// 丢失——MVP 明示；结构权威仍是 Graph，导入走写路径）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

import 'converter_commands.dart';

/// 导出 Handler。
class ExportHandler extends CommandHandler<ExportCommand, ExportResult> {
  /// [graphProvider] 延迟解析结构存储。
  ExportHandler({required Graph Function() graphProvider})
    : _graphProvider = graphProvider;

  final Graph Function() _graphProvider;

  @override
  Type get commandType => ExportCommand;

  @override
  Future<ExportResult> handle(ExportCommand command) async {
    final graph = _graphProvider();
    final nodes = graph.getAll().where((n) {
      final ids = command.nodeIds;
      return ids == null || ids.contains(n.id);
    }).toList();
    final file = File(command.path);
    file.parent.createSync(recursive: true);
    if (command.path.toLowerCase().endsWith('.md')) {
      // Markdown 聚合（旧版能力恢复）：## 标题分段，多节点 → 单文档。
      file.writeAsStringSync(_toMarkdown(nodes));
    } else {
      file.writeAsStringSync(_toJson(nodes));
    }
    return ExportResult(exportedCount: nodes.length);
  }

  String _toJson(List<Node> nodes) =>
      const JsonEncoder.withIndent('  ').convert(<Map<String, dynamic>>[
        for (final node in nodes)
          <String, dynamic>{
            'id': node.id,
            'title': node.title,
            'content': node.content,
            'references': node.references,
            'metadata': node.metadata,
            'createdAt': node.createdAt.toIso8601String(),
            'updatedAt': node.updatedAt.toIso8601String(),
          },
      ]);

  /// 聚合 markdown：`# 笔记本` 头 + 每节点 `## 标题\n\n正文`。
  String _toMarkdown(List<Node> nodes) {
    final buffer = StringBuffer('# 节点图谱导出（${nodes.length} 个节点）\n\n');
    for (final node in nodes) {
      buffer.writeln('## ${node.title}\n');
      final content = node.content?.trim();
      if (content != null && content.isNotEmpty) {
        buffer.writeln(content);
        buffer.writeln();
      }
    }
    return buffer.toString();
  }
}

/// 导入 Handler（JSON 或 Markdown 文件 → 节点落盘）。
///
/// 信任边界（docs/review 总览 P0-2，audit-node_converter #1/#6）：
/// 导入文件是外部输入，**落盘 references 前必须 AcyclicChecker 环校验**
/// ——恶意/手工 JSON 的自引用或互引不得写入图（与 MoveNodesHandler
/// 同一增量校验 + CycleError 语义）。导入对既有 id 属**整体覆盖**
/// （往返恢复语义），覆盖数在 ImportResult 回显，降低误导入风险。
class ImportHandler extends CommandHandler<ImportCommand, ImportResult> {
  /// [graphProvider] 延迟解析结构存储；[checker] 环校验器（缺省内置）。
  ImportHandler({required Graph Function() graphProvider, AcyclicChecker? checker})
    : _graphProvider = graphProvider,
      _checker = checker ?? const AcyclicChecker();

  final Graph Function() _graphProvider;

  final AcyclicChecker _checker;

  @override
  Type get commandType => ImportCommand;

  @override
  Future<ImportResult> handle(ImportCommand command) async {
    final graph = _graphProvider();
    final file = File(command.path);
    if (!file.existsSync()) {
      throw StateError('导入文件不存在: ${command.path}');
    }
    final imported = <String>{};
    var overwritten = 0; // R3b：覆盖既有节点计数（info #6 回显）。
    if (command.path.toLowerCase().endsWith('.md')) {
      // Markdown 拆分（旧版能力恢复）：## 段 → 节点。
      for (final node in _parseMarkdown(file.readAsStringSync())) {
        graph.save(node);
        imported.add(node.id);
      }
      return ImportResult(importedNodeIds: imported);
    }
    final data = jsonDecode(file.readAsStringSync());
    if (data is! List) {
      throw StateError('导入文件格式错误（应为节点数组）');
    }
    for (final entry in data) {
      if (entry is! Map<String, dynamic> || entry['id'] is! String) {
        continue; // 坏条目跳过（导入宽容，坏数据不崩溃）。
      }
      final id = entry['id'] as String;
      final references = _stringMap(entry['references']);
      // P0-2（R3a 信任边界）：落盘 references 前增量环校验——已落盘图 +
      // 本批次先前节点为参照；自引用立即命中；互引在第二个节点落盘时命中
      // （A→B 先落盘无恙，B→A 落盘时 A→B 已可见 → CycleError 拦截）。
      if (references.isNotEmpty) {
        final cycle = _checker.check(
          affectedRefs: <String, Set<String>>{id: references.values.toSet()},
          graph: graph,
        );
        if (cycle != null) {
          throw CycleError(cycle);
        }
      }
      // R3b：导入对既有 id 属整体覆盖（往返恢复语义）；覆盖数回显（info #6）。
      if (graph.get(id) != null) {
        overwritten++;
      }
      graph.save(
        StoredNode(
          id: id,
          title: entry['title'] as String? ?? id,
          content: entry['content'] as String?,
          references: references,
          metadata: entry['metadata'] is Map<String, dynamic>
              ? entry['metadata'] as Map<String, dynamic>
              : const <String, dynamic>{},
          createdAt: _parseTime(entry['createdAt']),
          updatedAt: _parseTime(entry['updatedAt']),
        ),
      );
      imported.add(id);
    }
    return ImportResult(importedNodeIds: imported, overwrittenCount: overwritten);
  }

  /// 拆分 markdown：`## 标题` 段 → 节点（跳过 `#` 文档头与空段）。
  List<Node> _parseMarkdown(String source) {
    final sections = <(String, String)>[];
    String? currentTitle;
    final currentLines = <String>[];
    void flush() {
      if (currentTitle != null && currentTitle!.isNotEmpty) {
        sections.add((currentTitle!, currentLines.join('\n').trim()));
      }
      currentTitle = null;
      currentLines.clear();
    }

    for (final line in source.split('\n')) {
      if (line.startsWith('## ')) {
        flush();
        currentTitle = line.substring(3).trim();
      } else if (line.startsWith('# ')) {
        flush(); // 文档头，跳过。
      } else if (currentTitle != null) {
        currentLines.add(line);
      }
    }
    flush();

    final now = DateTime.now();
    return <Node>[
      for (final (title, content) in sections)
        StoredNode(
          // 幂等 id：标题派生（同标题再导入 = 更新而非重复）。
          id: 'imported-${_slug(title)}',
          title: title,
          content: content.isEmpty ? null : content,
          createdAt: now,
          updatedAt: now,
        ),
    ];
  }

  String _slug(String title) =>
      title.trim().replaceAll(RegExp(r'[^\w一-龥]+'), '-').toLowerCase();

  Map<String, String> _stringMap(dynamic value) {
    if (value is! Map<String, dynamic>) {
      return const <String, String>{};
    }
    return value.map((k, v) => MapEntry(k, v.toString()));
  }

  DateTime _parseTime(dynamic value) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    return parsed ?? DateTime.now();
  }
}
