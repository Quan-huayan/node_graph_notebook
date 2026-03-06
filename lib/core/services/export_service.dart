import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../models/models.dart';
import '../../converter/models/models.dart';

/// 导出服务
class ExportService {
  /// 导出为 Markdown
  String exportToMarkdown({
    required List<Node> nodes,
    required MergeRule rule,
  }) {
    // 使用 ConverterService 的逻辑
    final buffer = StringBuffer();
    buffer.writeln('# Exported Notes');
    buffer.writeln();
    buffer.writeln('Generated at: ${DateTime.now()}');
    buffer.writeln();
    buffer.writeln('---');
    buffer.writeln();

    for (final node in nodes) {
      buffer.writeln('## ${node.title}');
      buffer.writeln();
      buffer.writeln(node.content ?? '');
      buffer.writeln();
      buffer.writeln('---');
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// 导出为 JSON
  String exportToJSON({
    required List<Node> nodes,
    required List<Connection> connections,
  }) {
    final exportData = {
      'version': '1.0.0',
      'exported_at': DateTime.now().toIso8601String(),
      'nodes': nodes.map((n) => n.toJson()).toList(),
      'connections': connections.map((c) => c.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }

  /// 导出为图片（需要渲染到图片）
  Future<File> exportToImage({
    required List<Node> nodes,
    required String filePath,
    GlobalKey? graphKey,
  }) async {
    try {
      if (graphKey == null) {
        throw UnimplementedError('GraphKey is required for image export');
      }

      // 捕获图表为图片
      final RenderRepaintBoundary boundary =
          graphKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to capture image');
      }

      // 保存到文件
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());

      return file;
    } catch (e) {
      throw Exception('Failed to export image: $e');
    }
  }

  /// 导出为 PDF（使用 Markdown 渲染为文本，基础实现）
  Future<File> exportToPDF({
    required List<Node> nodes,
    required String filePath,
  }) async {
    try {
      // 简单实现：将 Markdown 内容写入文本文件
      // 完整实现需要使用 pdf 包
      final buffer = StringBuffer();

      buffer.writeln('# ${nodes.first.title}');
      buffer.writeln();
      buffer.writeln('Generated: ${DateTime.now()}');
      buffer.writeln('=' * 60);
      buffer.writeln();

      for (final node in nodes) {
        buffer.writeln('## ${node.title}');
        buffer.writeln();
        buffer.writeln(node.content ?? '');
        buffer.writeln();
        buffer.writeln('-' * 40);
        buffer.writeln();
      }

      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      return file;
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  /// 保存文件
  Future<File> saveFile({
    required String content,
    required String fileName,
    required String directory,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final exportDir = Directory(path.join(dir.path, directory));
    await exportDir.create(recursive: true);

    final file = File(path.join(exportDir.path, fileName));
    await file.writeAsString(content);

    return file;
  }

  /// 导出完整图
  Future<File> exportGraph({
    required Graph graph,
    required List<Node> nodes,
    required ExportFormat format,
  }) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = '${graph.name}_$timestamp';

    switch (format) {
      case ExportFormat.json:
        final connections = Connection.calculateConnections(nodes);
        final json = exportToJSON(nodes: nodes, connections: connections);
        return saveFile(
          content: json,
          fileName: '$fileName.json',
          directory: 'exports',
        );

      case ExportFormat.markdown:
        final markdown = exportToMarkdown(
          nodes: nodes,
          rule: const MergeRule(
            strategy: MergeStrategy.hierarchy,
            hierarchyRule: HierarchyMergeRule(),
          ),
        );
        return saveFile(
          content: markdown,
          fileName: '$fileName.md',
          directory: 'exports',
        );

      case ExportFormat.image:
        return exportToImage(nodes: nodes, filePath: fileName);

      case ExportFormat.pdf:
        return exportToPDF(nodes: nodes, filePath: fileName);
    }
  }
}

/// 导出格式
enum ExportFormat {
  json,
  markdown,
  image,
  pdf,
}
