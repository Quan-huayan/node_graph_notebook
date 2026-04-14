import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../core/repositories/graph_repository.dart';
import '../../../../core/repositories/node_repository.dart';
import '../../../../core/services/infrastructure/storage_path_service.dart';
import '../../../core/cqrs/commands/models/command.dart';
import '../../../core/cqrs/commands/models/command_context.dart';
import '../../../core/cqrs/commands/models/command_handler.dart';
import '../command/repair_data_command.dart';

/// 数据修复命令处理器
///
/// 修复发现的数据问题
class RepairDataHandler implements CommandHandler<RepairDataCommand> {
  /// 创建数据修复处理器
  RepairDataHandler({
    required NodeRepository nodeRepository,
    required GraphRepository graphRepository,
    required StoragePathService storagePathService,
  })  : _nodeRepository = nodeRepository,
        _graphRepository = graphRepository,
        _storagePathService = storagePathService;

  final NodeRepository _nodeRepository;
  final GraphRepository _graphRepository;
  final StoragePathService _storagePathService;

  @override
  Future<CommandResult<DataRepairResult>> execute(
    RepairDataCommand command,
    CommandContext context,
  ) async {
    var repairedIssues = 0;
    var issuesFound = 0;
    String? backupPath;

    try {
      // 0. 如果需要，先创建备份
      if (command.createBackup) {
        backupPath = await _createBackup();
        if (backupPath != null) {
          debugPrint('Created backup at: $backupPath');
        }
      }

      // 1. 重建存储目录
      final storagePath = await _storagePathService.getStoragePath();
      final storageDir = Directory(storagePath);
      if (!storageDir.existsSync()) {
        issuesFound++;
        try {
          await storageDir.create(recursive: true);
          repairedIssues++;
          debugPrint('Created storage directory: $storagePath');
        } catch (e) {
          debugPrint('Failed to create storage directory: $e');
        }
      }

      // 2. 重建节点目录
      final nodesPath = await _storagePathService.getNodesPath();
      final nodesDir = Directory(nodesPath);
      if (!nodesDir.existsSync()) {
        issuesFound++;
        try {
          await nodesDir.create(recursive: true);
          repairedIssues++;
          debugPrint('Created nodes directory: $nodesPath');
        } catch (e) {
          debugPrint('Failed to create nodes directory: $e');
        }
      }

      // 3. 重建图目录
      final graphsPath = await _storagePathService.getGraphsPath();
      final graphsDir = Directory(graphsPath);
      if (!graphsDir.existsSync()) {
        issuesFound++;
        try {
          await graphsDir.create(recursive: true);
          repairedIssues++;
          debugPrint('Created graphs directory: $graphsPath');
        } catch (e) {
          debugPrint('Failed to create graphs directory: $e');
        }
      }

      // 4. 重新初始化仓库
      if (_nodeRepository is FileSystemNodeRepository) {
        issuesFound++;
        try {
          await _nodeRepository.init();
          repairedIssues++;
        } catch (e) {
          debugPrint('Failed to reinitialize node repository: $e');
        }
      }

      if (_graphRepository is FileSystemGraphRepository) {
        issuesFound++;
        try {
          await _graphRepository.init();
          repairedIssues++;
        } catch (e) {
          debugPrint('Failed to reinitialize graph repository: $e');
        }
      }

      // 5. 重建索引
      try {
        await _rebuildIndex();
        repairedIssues++;
      } catch (e) {
        issuesFound++;
        debugPrint('Failed to rebuild index: $e');
      }

      // 6. 修复当前图设置
      try {
        await _repairCurrentGraph();
        repairedIssues++;
      } catch (e) {
        issuesFound++;
        debugPrint('Failed to repair current graph: $e');
      }

      final result = DataRepairResult(
        success: true,
        repairedIssues: repairedIssues,
        issuesFound: issuesFound,
        message:
            repairedIssues > 0 ? '成功修复 $repairedIssues 个问题' : '没有需要修复的问题',
        backupPath: backupPath,
      );

      return CommandResult.success(result);
    } catch (e) {
      return CommandResult.failure('修复失败: $e');
    }
  }

  /// 创建备份
  Future<String?> _createBackup() async {
    try {
      final backupPath =
          '${await _storagePathService.getStoragePath()}/backup_${DateTime.now().millisecondsSinceEpoch}';
      final backupDir = Directory(backupPath);
      await backupDir.create(recursive: true);

      // 备份节点
      final nodesPath = await _storagePathService.getNodesPath();
      final nodesDir = Directory(nodesPath);
      if (nodesDir.existsSync()) {
        await _copyDirectory(nodesDir, Directory('$backupPath/nodes'));
      }

      // 备份图
      final graphsPath = await _storagePathService.getGraphsPath();
      final graphsDir = Directory(graphsPath);
      if (graphsDir.existsSync()) {
        await _copyDirectory(graphsDir, Directory('$backupPath/graphs'));
      }

      return backupPath;
    } catch (e) {
      debugPrint('Failed to backup data: $e');
      return null;
    }
  }

  /// 重建节点索引
  Future<void> _rebuildIndex() async {
    final nodes = await _nodeRepository.queryAll();
    // 通过保存所有节点来重建索引
    for (final node in nodes) {
      try {
        await _nodeRepository.updateIndex(node);
      } catch (e) {
        debugPrint('Failed to update index for node ${node.id}: $e');
      }
    }
    debugPrint('Rebuilt index with ${nodes.length} nodes');
  }

  /// 修复当前图设置
  Future<void> _repairCurrentGraph() async {
    final currentGraph = await _graphRepository.getCurrent();
    if (currentGraph == null) {
      // 尝试设置第一个可用图为当前图
      final graphs = await _graphRepository.getAll();
      if (graphs.isNotEmpty) {
        await _graphRepository.setCurrent(graphs.first.id);
        debugPrint('Set current graph to: ${graphs.first.name}');
      } else {
        // 创建默认图
        if (_graphRepository is FileSystemGraphRepository) {
          await _graphRepository
              .createDefaultGraph();
          debugPrint('Created default graph');
        }
      }
    }
  }

  /// 复制目录
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list()) {
      if (entity is File) {
        final newPath = '${destination.path}/${_basename(entity.path)}';
        await entity.copy(newPath);
      } else if (entity is Directory) {
        final newDir = Directory('${destination.path}/${_basename(entity.path)}');
        await _copyDirectory(entity, newDir);
      }
    }
  }

  /// 获取路径的基名
  String _basename(String path) => path.split(Platform.pathSeparator).last;
}
