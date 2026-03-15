import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../bloc/graph/graph_bloc.dart';
import '../../plugins/hooks/graph_plugin.dart';
import '../../bloc/graph/graph_state.dart';

/// 导出插件
/// 支持将图导出为各种格式
class ExportPlugin extends GraphPlugin {
  ExportPlugin();

  @override
  String get id => 'export';

  @override
  String get name => 'Export';

  @override
  String get description => 'Export graph to various formats (JSON, PNG, Markdown)';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize(GraphBloc bloc) async {
    // 初始化
  }

  @override
  Future<void> dispose() async {
    // 清理
  }

  @override
  Future<void> execute(
    Map<String, dynamic> data,
    GraphBloc bloc,
    Emitter<GraphState> emit,
  ) async {
    final format = data['format'] as String? ?? 'json';
    final filePath = data['filePath'] as String?;

    try {
      switch (format) {
        case 'json':
          await _exportJson(bloc.state, filePath);
          break;
        case 'markdown':
          await _exportMarkdown(bloc.state, filePath);
          break;
        case 'csv':
          await _exportCSV(bloc.state, filePath);
          break;
        default:
          debugPrint('Unsupported export format: $format');
      }
    } catch (e) {
      debugPrint('Export failed: $e');
    }
  }

  /// 导出为 JSON
  Future<void> _exportJson(GraphState state, String? filePath) async {
    final exportData = {
      'graph': {
        'id': state.graph.id,
        'name': state.graph.name,
        'createdAt': state.graph.createdAt.toIso8601String(),
        'updatedAt': state.graph.updatedAt.toIso8601String(),
      },
      'nodes': state.nodes.map((node) => node.toJson()).toList(),
      'connections': state.connections
          .map((conn) => {
                'from': conn.fromNodeId,
                'to': conn.toNodeId,
                'type': conn.type,
              })
          .toList(),
    };

    final json = const JsonEncoder.withIndent('  ').convert(exportData);
    await _writeFile(filePath ?? 'graph_export.json', json);
  }

  /// 导出为 Markdown
  Future<void> _exportMarkdown(GraphState state, String? filePath) async {
    final buffer = StringBuffer();

    // 标题
    buffer.writeln('# ${state.graph.name.isNotEmpty ? state.graph.name : "Graph"}\n');

    // 元数据
    buffer.writeln('**Created:** ${state.graph.createdAt}');
    buffer.writeln('**Updated:** ${state.graph.updatedAt}');
    buffer.writeln('**Nodes:** ${state.nodes.length}');
    buffer.writeln('**Connections:** ${state.connections.length}');
    buffer.writeln();

    // 节点列表
    buffer.writeln('## Nodes\n');
    for (final node in state.nodes) {
      buffer.writeln('### ${node.title}');
      if (node.content != null && node.content!.isNotEmpty) {
        buffer.writeln(node.content);
      }
      buffer.writeln();
    }

    await _writeFile(filePath ?? 'graph_export.md', buffer.toString());
  }

  /// 导出为 CSV
  Future<void> _exportCSV(GraphState state, String? filePath) async {
    final buffer = StringBuffer();

    // CSV 头部
    buffer.writeln('node_id,title,content,position_x,position_y');

    // 节点数据
    for (final node in state.nodes) {
      final content = node.content?.replaceAll('\n', '\\n') ?? '';
      buffer.writeln(
        '${node.id},"${node.title}","$content",${node.position.dx},${node.position.dy}',
      );
    }

    await _writeFile(filePath ?? 'graph_export.csv', buffer.toString());
  }

  /// 写入文件
  Future<void> _writeFile(String fileName, String content) async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = path.join(directory.path, fileName);
    final file = File(filePath);
    await file.writeAsString(content);
    debugPrint('Exported to: $filePath');
  }
}
