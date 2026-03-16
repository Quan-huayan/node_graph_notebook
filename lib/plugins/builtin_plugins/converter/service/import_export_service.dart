import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/models/models.dart';
import '../../graph/service/graph_service.dart';
import '../../graph/service/node_service.dart';
import '../models/models.dart';
import 'converter_service.dart';

/// 导入导出服务接口，提供文件导入导出功能
abstract class ImportExportService {
  /// 预览导入结果，不实际创建节点
  /// 
  /// [filePath] - 要导入的文件路径
  /// [rule] - 转换规则，定义如何拆分 Markdown
  /// 
  /// 返回转换后的节点列表，用于预览
  Future<List<Node>> previewImport({
    required String filePath,
    required ConversionRule rule,
  });

  /// 执行导入操作，创建节点并处理引用关系
  /// 
  /// [filePath] - 要导入的文件路径
  /// [rule] - 转换规则，定义如何拆分 Markdown
  /// [selectedIndices] - 要导入的节点索引列表
  /// [addToGraph] - 是否将创建的节点添加到当前图，默认为 true
  /// 
  /// 返回导入结果，包含成功和失败的统计信息
  Future<ConversionResult> executeImport({
    required String filePath,
    required ConversionRule rule,
    required List<int> selectedIndices,
    bool addToGraph = true,
  });

  /// 预览导出结果，生成 Markdown 内容但不写入文件
  /// 
  /// [nodeIds] - 要导出的节点 ID 列表
  /// [rule] - 合并规则，定义如何将多个节点合并为单个 Markdown 文档
  /// 
  /// 返回生成的 Markdown 字符串
  Future<String> previewExport({
    required List<String> nodeIds,
    required MergeRule rule,
  });

  /// 执行导出操作，生成 Markdown 并写入文件
  /// 
  /// [nodeIds] - 要导出的节点 ID 列表
  /// [rule] - 合并规则，定义如何将多个节点合并为单个 Markdown 文档
  /// [outputPath] - 输出文件路径
  /// 
  /// 返回保存的文件
  Future<File> executeExport({
    required List<String> nodeIds,
    required MergeRule rule,
    required String outputPath,
  });

  /// 批量导入多个文件
  /// 
  /// [filePaths] - 要导入的文件路径列表
  /// [config] - 转换配置
  /// [onProgress] - 进度回调函数，参数为当前处理的节点数和总文件数
  /// 
  /// 返回导入结果，包含成功和失败的统计信息
  Future<ConversionResult> batchImport({
    required List<String> filePaths,
    required ConversionConfig config,
    void Function(int current, int total)? onProgress,
  });
}

/// 导入导出服务实现
class ImportExportServiceImpl implements ImportExportService {
  /// 导入导出服务实现构造函数
  /// 
  /// [_converterService] - 转换服务，用于文件和节点之间的转换
  /// [_nodeService] - 节点服务，用于节点的创建和管理
  /// [_graphService] - 图服务，用于管理节点在图中的关系
  ImportExportServiceImpl(
    this._converterService,
    this._nodeService,
    this._graphService,
  );

  final ConverterService _converterService;
  final NodeService _nodeService;
  final GraphService _graphService; // 必需依赖：用于管理图中的节点
  final Stopwatch _stopwatch = Stopwatch();

  @override
  Future<List<Node>> previewImport({
    required String filePath,
    required ConversionRule rule,
  }) async => _converterService.fileToNodes(filePath: filePath, rule: rule);

  @override
  Future<ConversionResult> executeImport({
    required String filePath,
    required ConversionRule rule,
    required List<int> selectedIndices,
    bool addToGraph = true,
  }) async {
    _stopwatch..reset()
    ..start();

    // 获取所有节点
    final allNodes = await previewImport(filePath: filePath, rule: rule);

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

    // === 关键修复：维护 ID 映射表 ===
    // 说明：从 converter 返回的节点使用临时 UUID，但 createNode 会生成新的 UUID。
    // 因此需要建立临时 ID 到真实 ID 的映射，并在创建所有节点后更新引用。
    final idMapping = <String, String>{}; // 临时ID -> 真实ID

    // 第一步：创建所有节点，建立映射关系
    for (final node in selectedNodes) {
      try {
        // 创建节点时不传递 references，稍后通过映射表更新
        final created = await _nodeService.createNode(
          title: node.title,
          content: node.content ?? '',
          metadata: node.metadata,
          references: {}, // 先创建空引用，稍后更新
        );
        createdNodeIds.add(created.id);
        idMapping[node.id] = created.id; // 记录临时ID到真实ID的映射
      } catch (e) {
        errors.add('Failed to create node "${node.title}": ${e.toString()}');
      }
    }

    // 第二步：更新所有节点的引用关系
    for (final node in selectedNodes) {
      final newId = idMapping[node.id];
      if (newId == null) continue; // 节点创建失败，跳过

      // 如果节点有引用，需要更新引用的节点ID
      if (node.references.isNotEmpty) {
        final updatedReferences = <String, NodeReference>{};

        for (final entry in node.references.entries) {
          final oldRefId = entry.key;
          final reference = entry.value;

          // 查找被引用节点的新ID
          final newRefId = idMapping[oldRefId];
          if (newRefId != null) {
            // 找到映射，使用新的ID创建引用
            updatedReferences[newRefId] = NodeReference(
              nodeId: newRefId,
              properties: reference.properties,
            );
          } else {
            // 被引用的节点可能没有被选中导入，忽略此引用
            debugPrint(
              'Reference $oldRefId not found in imported nodes, skipping',
            );
          }
        }

        // 更新节点的引用
        try {
          await _nodeService.updateNode(
            newId,
            references: updatedReferences.isNotEmpty ? updatedReferences : {},
          );
        } catch (e) {
          errors.add(
            'Failed to update references for "${node.title}": ${e.toString()}',
          );
        }
      }
    }

    // 如果需要，将创建的节点添加到当前图
    if (addToGraph && createdNodeIds.isNotEmpty) {
      try {
        final currentGraph = await _graphService.getCurrentGraph();
        if (currentGraph != null) {
          for (final nodeId in createdNodeIds) {
            await _graphService.addNodeToGraph(currentGraph.id, nodeId);
          }
          debugPrint(
            'Added ${createdNodeIds.length} nodes to graph ${currentGraph.id}',
          );
        } else {
          errors.add(
            'No active graph found. Nodes were created but not added to any graph.',
          );
        }
      } catch (e) {
        errors.add('Failed to add nodes to graph: ${e.toString()}');
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

    return _converterService.nodesToMarkdown(nodes: nodes, rule: rule);
  }

  @override
  Future<File> executeExport({
    required List<String> nodeIds,
    required MergeRule rule,
    required String outputPath,
  }) async {
    // 生成 markdown
    final markdown = await previewExport(nodeIds: nodeIds, rule: rule);

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
    _stopwatch..reset()
    ..start();

    var successCount = 0;
    var failureCount = 0;
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

        // === 关键修复：维护 ID 映射表 ===
        // 说明：批量导入时也需要处理临时ID到真实ID的映射
        final idMapping = <String, String>{};
        final currentFileNodeIds = <String>[];

        // 第一步：创建所有节点，建立映射关系
        for (final node in allNodes) {
          try {
            final created = await _nodeService.createNode(
              title: node.title,
              content: node.content ?? '',
              metadata: node.metadata,
              references: {}, // 先创建空引用，稍后更新
            );
            currentFileNodeIds.add(created.id);
            idMapping[node.id] = created.id;
            successCount++;
          } catch (e) {
            errors.add('Failed to create node from $filePath: ${e.toString()}');
            failureCount++;
          }
        }

        // 第二步：更新所有节点的引用关系
        for (final node in allNodes) {
          final newId = idMapping[node.id];
          if (newId == null) continue;

          if (node.references.isNotEmpty) {
            final updatedReferences = <String, NodeReference>{};

            for (final entry in node.references.entries) {
              final oldRefId = entry.key;
              final reference = entry.value;

              final newRefId = idMapping[oldRefId];
              if (newRefId != null) {
                updatedReferences[newRefId] = NodeReference(
                  nodeId: newRefId,
                  properties: reference.properties,
                );
              }
            }

            if (updatedReferences.isNotEmpty) {
              try {
                await _nodeService.updateNode(
                  newId,
                  references: updatedReferences,
                );
              } catch (e) {
                errors.add(
                  'Failed to update references for "${node.title}": ${e.toString()}',
                );
              }
            }
          }
        }

        createdNodeIds.addAll(currentFileNodeIds);

        // 报告进度
        onProgress?.call(createdNodeIds.length, filePaths.length);
      } catch (e) {
        errors.add('$filePath: ${e.toString()}');
        failureCount++;
      }
    }

    // 批量导入默认也添加到当前图
    if (createdNodeIds.isNotEmpty) {
      try {
        final currentGraph = await _graphService.getCurrentGraph();
        if (currentGraph != null) {
          for (final nodeId in createdNodeIds) {
            await _graphService.addNodeToGraph(currentGraph.id, nodeId);
          }
          debugPrint(
            'Added ${createdNodeIds.length} nodes to graph ${currentGraph.id}',
          );
        } else {
          errors.add(
            'No active graph found. Nodes were created but not added to any graph.',
          );
        }
      } catch (e) {
        errors.add('Failed to add nodes to graph: ${e.toString()}');
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
