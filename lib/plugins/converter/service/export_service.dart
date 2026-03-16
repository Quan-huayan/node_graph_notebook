import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../../core/models/models.dart';
import '../models/models.dart';

/// 导出服务，提供多种格式的导出功能
class ExportService {
  /// 导出为 Markdown 格式
  /// 
  /// [nodes] - 要导出的节点列表
  /// [rule] - 合并规则，定义如何将多个节点合并为单个 Markdown 文档
  /// 
  /// 返回生成的 Markdown 字符串
  String exportToMarkdown({
    required List<Node> nodes,
    required MergeRule rule,
  }) {
    // 使用 ConverterService 的逻辑
    final buffer = StringBuffer()
    ..writeln('# Exported Notes')
    ..writeln()
    ..writeln('Generated at: ${DateTime.now()}')
    ..writeln()
    ..writeln('---')
    ..writeln();

    for (final node in nodes) {
      buffer..writeln('## ${node.title}')
      ..writeln()
      ..writeln(node.content ?? '')
      ..writeln()
      ..writeln('---')
      ..writeln();
    }

    return buffer.toString();
  }

  /// 导出为 JSON 格式
  /// 
  /// [nodes] - 要导出的节点列表
  /// [connections] - 节点之间的连接关系列表
  /// 
  /// 返回生成的 JSON 字符串
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

  /// 导出为图片格式
  /// 
  /// [nodes] - 要导出的节点列表
  /// [filePath] - 保存图片的文件路径
  /// [graphKey] - 用于捕获图表的 GlobalKey，必须提供
  /// 
  /// 返回保存的图片文件
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
      final boundary =
          graphKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

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

  /// 导出为 PDF 格式（基础实现）
  /// 
  /// [nodes] - 要导出的节点列表
  /// [filePath] - 保存 PDF 的文件路径
  /// 
  /// 返回保存的 PDF 文件
  Future<File> exportToPDF({
    required List<Node> nodes,
    required String filePath,
  }) async {
    try {
      // 简单实现：将 Markdown 内容写入文本文件
      // 完整实现需要使用 pdf 包
      final buffer = StringBuffer()
      ..writeln('# ${nodes.first.title}')
      ..writeln()
      ..writeln('Generated: ${DateTime.now()}')
      ..writeln('=' * 60)
      ..writeln();

      for (final node in nodes) {
        buffer..writeln('## ${node.title}')
        ..writeln()
        ..writeln(node.content ?? '')
        ..writeln()
        ..writeln('-' * 40)
        ..writeln();
      }

      final file = File(filePath);
      await file.writeAsString(buffer.toString());

      return file;
    } catch (e) {
      throw Exception('Failed to export PDF: $e');
    }
  }

  /// 保存文件到应用文档目录
  /// 
  /// [content] - 文件内容
  /// [fileName] - 文件名
  /// [directory] - 子目录名称
  /// 
  /// 返回保存的文件
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

  /// 导出完整图到指定格式
  /// 
  /// [graph] - 要导出的图
  /// [nodes] - 图中的节点列表
  /// [format] - 导出格式
  /// 
  /// 返回保存的文件
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
  /// JSON格式导出
  json,
  /// Markdown格式导出
  markdown,
  /// 图片格式导出
  image,
  /// PDF格式导出
  pdf
}
