import 'dart:io';
import 'package:node_graph_notebook/core/services/services.dart';
import '../models/models.dart';
import '../../converter/converter_service.dart';
import '../../converter/models/models.dart';

/// 导入导出服务接口
abstract class ImportExportService {
  /// 预览导入
  Future<List<Node>> previewImport({
    required String filePath,
    required ConversionRule rule,
  });

  /// 执行导入
  Future<ConversionResult> executeImport({
    required String filePath,
    required ConversionRule rule,
    required List<int> selectedIndices,
    bool addToGraph = true,
  });

  /// 预览导出
  Future<String> previewExport({
    required List<String> nodeIds,
    required MergeRule rule,
  });

  /// 执行导出
  Future<File> executeExport({
    required List<String> nodeIds,
    required MergeRule rule,
    required String outputPath,
  });

  /// 批量导入
  Future<ConversionResult> batchImport({
    required List<String> filePaths,
    required ConversionConfig config,
    void Function(int current, int total)? onProgress,
  });
}

/// 导入导出服务实现
class ImportExportServiceImpl implements ImportExportService {
  ImportExportServiceImpl(this._converterService, this._nodeService);

  final ConverterService _converterService;
  final NodeService _nodeService;
  final Stopwatch _stopwatch = Stopwatch();

  @override
  Future<List<Node>> previewImport({
    required String filePath,
    required ConversionRule rule,
  }) async {
    return _converterService.fileToNodes(
      filePath: filePath,
      rule: rule,
    );
  }

  @override
  Future<ConversionResult> executeImport({
    required String filePath,
    required ConversionRule rule,
    required List<int> selectedIndices,
    bool addToGraph = true,
  }) async {
    _stopwatch.reset();
    _stopwatch.start();

    // 获取所有节点
    final allNodes = await previewImport(
      filePath: filePath,
      rule: rule,
    );

    // 筛选选中的节点
    final selectedNodes = <Node>[];
    for (final index in selectedIndices) {
      if (index >= 0 && index < allNodes.length) {
        selectedNodes.add(allNodes[index]);
      }
    }

    // 创建节点
    final createdNodeIds = <String>[];
    final errors = <String>[];

    for (final node in selectedNodes) {
      try {
        final created = await _nodeService.createContentNode(
          title: node.title,
          content: node.content ?? '',
          metadata: node.metadata,
        );
        createdNodeIds.add(created.id);
      } catch (e) {
        errors.add('Failed to create node "${node.title}": ${e.toString()}');
      }
    }

    _stopwatch.stop();

    return ConversionResult(
      successCount: createdNodeIds.length,
      failureCount: errors.length,
      errors: errors,
      duration: _stopwatch.elapsed,
      createdNodeIds: createdNodeIds,
    );
  }

  @override
  Future<String> previewExport({
    required List<String> nodeIds,
    required MergeRule rule,
  }) async {
    // 获取节点
    final nodes = <Node>[];
    for (final nodeId in nodeIds) {
      final node = await _nodeService.getNode(nodeId);
      if (node != null) {
        nodes.add(node);
      }
    }

    if (nodes.isEmpty) {
      throw const FormatException('No valid nodes found for export');
    }

    return _converterService.nodesToMarkdown(
      nodes: nodes,
      rule: rule,
    );
  }

  @override
  Future<File> executeExport({
    required List<String> nodeIds,
    required MergeRule rule,
    required String outputPath,
  }) async {
    // 生成 markdown
    final markdown = await previewExport(
      nodeIds: nodeIds,
      rule: rule,
    );

    // 写入文件
    final file = File(outputPath);
    await file.writeAsString(markdown);

    return file;
  }

  @override
  Future<ConversionResult> batchImport({
    required List<String> filePaths,
    required ConversionConfig config,
    void Function(int current, int total)? onProgress,
  }) async {
    _stopwatch.reset();
    _stopwatch.start();

    int successCount = 0;
    int failureCount = 0;
    final errors = <String>[];
    final createdNodeIds = <String>[];

    for (final filePath in filePaths) {
      try {
        // 检查文件是否存在
        final file = File(filePath);
        if (!file.existsSync()) {
          errors.add('File not found: $filePath');
          failureCount++;
          continue;
        }

        // 获取所有节点
        final allNodes = await previewImport(
          filePath: filePath,
          rule: config.rule,
        );

        // 创建所有节点
        for (final node in allNodes) {
          try {
            final created = await _nodeService.createContentNode(
              title: node.title,
              content: node.content ?? '',
              metadata: node.metadata,
            );
            createdNodeIds.add(created.id);
            successCount++;
          } catch (e) {
            errors.add('Failed to create node from $filePath: ${e.toString()}');
            failureCount++;
          }
        }

        // 报告进度
        onProgress?.call(createdNodeIds.length, filePaths.length);
      } catch (e) {
        errors.add('$filePath: ${e.toString()}');
        failureCount++;
      }
    }

    _stopwatch.stop();

    return ConversionResult(
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
      duration: _stopwatch.elapsed,
      createdNodeIds: createdNodeIds,
    );
  }
}
