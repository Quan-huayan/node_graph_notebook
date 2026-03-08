import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import 'exceptions.dart';

/// 图仓库接口
abstract class GraphRepository {
  /// 保存图
  Future<void> save(Graph graph);

  /// 加载图
  Future<Graph?> load(String graphId);

  /// 删除图
  Future<void> delete(String graphId);

  /// 获取所有图
  Future<List<Graph>> getAll();

  /// 获取当前图
  Future<Graph?> getCurrent();

  /// 设置当前图
  Future<void> setCurrent(String graphId);

  /// 导出图
  Future<void> export(String graphId, String filePath);

  /// 导入图
  Future<Graph> import(String filePath);
}

/// 文件系统图仓库实现
class FileSystemGraphRepository implements GraphRepository {
  FileSystemGraphRepository({String graphsDir = 'data/graphs'})
      : _graphsDir = graphsDir,
        _uuid = const Uuid();

  final String _graphsDir;
  final Uuid _uuid;

  /// 初始化目录
  Future<void> init() async {
    final dir = Directory(_graphsDir);
    if (!dir.existsSync()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        throw RepositoryException('Failed to create graphs directory: $e');
      }
    }

    // 验证目录可写
    try {
      final testFile = File(path.join(_graphsDir, '.write_test'));
      await testFile.writeAsString('test');
      await testFile.delete();
    } catch (e) {
      throw RepositoryException('Graphs directory is not writable: $e');
    }
  }

  @override
  Future<void> save(Graph graph) async {
    final dir = Directory(_graphsDir);
    if (!dir.existsSync()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        throw const RepositoryException(
          'Data folder does not exist and cannot be created. '
          'Please check your file system permissions.',
        );
      }
    }

    final file = _getGraphFilePath(graph.id);
    final json = graph.toJson();

    try {
      await file.writeAsString(_encodeJson(json));
    } on FileSystemException catch (e) {
      throw RepositoryException(
        'Cannot write to data folder. The folder may have been deleted or is inaccessible. '
        'Error: ${e.message}',
      );
    }
  }

  @override
  Future<Graph?> load(String graphId) async {
    final file = _getGraphFilePath(graphId);
    if (!file.existsSync()) return null;

    try {
      final content = await file.readAsString();

      // === 架构说明：空文件处理 ===
      // 设计意图：防止文件损坏导致应用崩溃
      // 实现方式：检查文件内容是否为空或仅包含空白字符
      // 重要性：允许应用从损坏的数据中恢复
      if (content.trim().isEmpty) {
        debugPrint('[GraphRepository] Graph file is empty: $graphId');
        return null;
      }

      final json = _decodeJson(content);
      return Graph.fromJson(json);
    } on FileSystemException catch (e) {
      throw RepositoryException(
        'Cannot read graph data. The data folder may have been deleted or is inaccessible. '
        'Error: ${e.message}',
      );
    } catch (e) {
      throw RepositoryException('Failed to load graph $graphId: $e');
    }
  }

  @override
  Future<void> delete(String graphId) async {
    final file = _getGraphFilePath(graphId);
    if (file.existsSync()) {
      await file.delete();
    }

    // 如果是当前图，清除设置
    final current = await getCurrent();
    if (current?.id == graphId) {
      await _clearCurrent();
    }
  }

  @override
  Future<List<Graph>> getAll() async {
    final dir = Directory(_graphsDir);
    if (!dir.existsSync()) {
      // 目录不存在，尝试创建
      try {
        await dir.create(recursive: true);
        return [];
      } catch (e) {
        throw const RepositoryException(
          'Data folder does not exist and cannot be created. '
          'Please check your file system permissions.',
        );
      }
    }

    final graphs = <Graph>[];
    final List<String> corruptedFiles = [];

    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.json')) {
          // 跳过 current.json
          if (path.basename(entity.path) == 'current.json') continue;

          try {
            final content = await entity.readAsString();
            final json = _decodeJson(content);
            final graph = Graph.fromJson(json);
            graphs.add(graph);
          } catch (e) {
            // 记录损坏的文件，但继续处理其他文件
            corruptedFiles.add(entity.path);
            debugPrint('Failed to load graph file ${entity.path}: $e');
          }
        }
      }
    } on FileSystemException catch (e) {
      throw RepositoryException(
        'Cannot access data folder. It may have been deleted or is inaccessible. '
        'Error: ${e.message}',
      );
    } catch (e) {
      throw RepositoryException('Failed to list graphs: $e');
    }

    // 如果有损坏的文件，记录日志
    if (corruptedFiles.isNotEmpty) {
      debugPrint('Found ${corruptedFiles.length} corrupted graph file(s)');

      // 尝试清理 current.json 如果当前图已损坏
      await _cleanupCurrentGraphIfNeeded(graphs);
    }

    return graphs;
  }

  @override
  Future<Graph?> getCurrent() async {
    final settingsFile = File(path.join(_graphsDir, 'current.json'));
    if (!settingsFile.existsSync()) {
      // 返回第一个图作为默认图
      final graphs = await getAll();
      if (graphs.isNotEmpty) {
        try {
          await setCurrent(graphs.first.id);
          return graphs.first;
        } catch (e) {
          debugPrint('Failed to set default current graph: $e');
          return graphs.first;
        }
      }
      return null;
    }

    try {
      final content = await settingsFile.readAsString();
      final json = _decodeJson(content);
      final graphId = json['current_graph_id'] as String?;
      if (graphId == null) return null;

      final graph = await load(graphId);
      if (graph != null) {
        return graph;
      }

      // 当前图已被删除，清除设置并返回第一个可用的图
      debugPrint('Current graph $graphId not found, clearing settings');
      await _clearCurrent();

      final graphs = await getAll();
      if (graphs.isNotEmpty) {
        await setCurrent(graphs.first.id);
        return graphs.first;
      }
      return null;
    } on FileSystemException catch (e) {
      debugPrint('Failed to load current graph: $e');
      // 如果读取设置文件失败，尝试清除它
      try {
        await _clearCurrent();
      } catch (e2) {
        debugPrint('Failed to clear current graph settings: $e2');
      }

      // 返回第一个可用的图
      final graphs = await getAll();
      return graphs.isNotEmpty ? graphs.first : null;
    } catch (e) {
      debugPrint('Failed to load current graph: $e');
      // 如果读取设置文件失败，尝试清除它
      try {
        await _clearCurrent();
      } catch (e2) {
        debugPrint('Failed to clear current graph settings: $e2');
      }

      // 返回第一个可用的图
      final graphs = await getAll();
      return graphs.isNotEmpty ? graphs.first : null;
    }
  }

  @override
  Future<void> setCurrent(String graphId) async {
    final settingsFile = File(path.join(_graphsDir, 'current.json'));
    final json = {'current_graph_id': graphId};
    await settingsFile.writeAsString(_encodeJson(json));
  }

  @override
  Future<void> export(String graphId, String filePath) async {
    final graph = await load(graphId);
    if (graph == null) {
      throw RepositoryException('Graph not found: $graphId');
    }

    final file = File(filePath);
    final json = graph.toJson();
    await file.writeAsString(_encodeJson(json));
  }

  @override
  Future<Graph> import(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw RepositoryException('File not found: $filePath');
    }

    try {
      final content = await file.readAsString();
      final json = _decodeJson(content);
      var graph = Graph.fromJson(json);

      // 生成新ID避免冲突
      final newId = _uuid.v4();
      graph = graph.copyWith(id: newId);

      // 保存到仓库
      await save(graph);

      return graph;
    } catch (e) {
      throw RepositoryException('Failed to import graph: $e');
    }
  }

  /// 创建默认图
  Future<Graph> createDefaultGraph() async {
    final graph = Graph(
      id: _uuid.v4(),
      name: 'My First Graph',
      nodeIds: [],
      viewConfig: GraphViewConfig.defaultConfig,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      nodePositions: {}
    );

    await save(graph);
    await setCurrent(graph.id);

    return graph;
  }

  File _getGraphFilePath(String graphId) {
    return File(path.join(_graphsDir, '$graphId.json'));
  }

  Future<void> _clearCurrent() async {
    final settingsFile = File(path.join(_graphsDir, 'current.json'));
    if (settingsFile.existsSync()) {
      await settingsFile.delete();
    }
  }

  String _encodeJson(Map<String, dynamic> json) {
    return jsonEncode(json);
  }

  Map<String, dynamic> _decodeJson(String content) {
    return jsonDecode(content) as Map<String, dynamic>;
  }

  /// 清理当前图设置（如果引用的图已损坏或不存在）
  Future<void> _cleanupCurrentGraphIfNeeded(List<Graph> validGraphs) async {
    final settingsFile = File(path.join(_graphsDir, 'current.json'));
    if (!settingsFile.existsSync()) return;

    try {
      final content = await settingsFile.readAsString();
      final json = _decodeJson(content);
      final currentGraphId = json['current_graph_id'] as String?;

      if (currentGraphId != null) {
        // 检查当前图是否在有效图列表中
        final currentExists = validGraphs.any((g) => g.id == currentGraphId);
        if (!currentExists) {
          debugPrint('Current graph $currentGraphId is corrupted or missing, clearing settings');
          await _clearCurrent();
        }
      }
    } catch (e) {
      debugPrint('Failed to cleanup current graph settings: $e');
      // 如果读取设置失败，尝试删除设置文件
      try {
        await settingsFile.delete();
      } catch (e2) {
        debugPrint('Failed to delete corrupted current.json: $e2');
      }
    }
  }
}
