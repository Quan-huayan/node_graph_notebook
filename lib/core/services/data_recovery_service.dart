import 'dart:io';

import 'package:path/path.dart' as path;

import '../repositories/exceptions.dart';
import '../repositories/repositories.dart';
import '../services/services.dart';
import '../utils/logger.dart';

/// 数据恢复服务日志记录器
const _log = AppLogger('DataRecoveryService');

/// 数据恢复结果
class DataRecoveryResult {
  /// 创建数据恢复结果
  ///
  /// [success] - 是否成功
  /// [repairedIssues] - 修复的问题数量
  /// [issuesFound] - 发现的问题数量
  /// [message] - 结果消息
  const DataRecoveryResult({
    required this.success,
    required this.repairedIssues,
    required this.issuesFound,
    this.message,
  });

  /// 是否成功
  final bool success;
  
  /// 修复的问题数量
  final int repairedIssues;
  
  /// 发现的问题数量
  final int issuesFound;
  
  /// 结果消息
  final String? message;
}

/// 数据恢复服务
///
/// 提供数据验证和恢复功能，处理文件被外部删除或损坏的情况
class DataRecoveryService {
  /// 创建数据恢复服务
  ///
  /// [nodeRepository] - 节点仓库
  /// [graphRepository] - 图仓库
  /// [settingsService] - 设置服务
  DataRecoveryService({
    required this.nodeRepository,
    required this.graphRepository,
    required this.settingsService,
  });

  /// 节点仓库
  final NodeRepository nodeRepository;
  
  /// 图仓库
  final GraphRepository graphRepository;
  
  /// 设置服务
  final SettingsService settingsService;

  /// 验证数据完整性
  Future<DataRecoveryResult> validateData() async {
    var issuesFound = 0;

    try {
      // 1. 验证存储目录是否存在
      final storagePath = await settingsService.getStoragePath();
      final storageDir = Directory(storagePath);
      if (!storageDir.existsSync()) {
        issuesFound++;
        _log.warning('Storage directory does not exist: $storagePath');
      }

      // 2. 验证节点目录
      final nodesPath = await settingsService.getNodesPath();
      final nodesDir = Directory(nodesPath);
      if (!nodesDir.existsSync()) {
        issuesFound++;
        _log.warning('Nodes directory does not exist: $nodesPath');
      }

      // 3. 验证图目录
      final graphsPath = await settingsService.getGraphsPath();
      final graphsDir = Directory(graphsPath);
      if (!graphsDir.existsSync()) {
        issuesFound++;
        _log.warning('Graphs directory does not exist: $graphsPath');
      }

      // 4. 验证节点文件
      try {
        final nodes = await nodeRepository.queryAll();
        // 检查索引是否有效
        final index = await nodeRepository.getMetadataIndex();
        if (index.nodes.length != nodes.length) {
          issuesFound++;
          _log.warning(
            'Index mismatch: ${index.nodes.length} in index, ${nodes.length} actual files',
          );
        }
      } catch (e) {
        issuesFound++;
        _log.error('Failed to validate nodes', error: e);
      }

      // 5. 验证图文件
      try {
        final graphs = await graphRepository.getAll();
        final currentGraph = await graphRepository.getCurrent();
        if (graphs.isNotEmpty && currentGraph == null) {
          issuesFound++;
          _log.warning('Current graph setting is invalid');
        }
      } catch (e) {
        issuesFound++;
        _log.error('Failed to validate graphs', error: e);
      }

      return DataRecoveryResult(
        success: true,
        repairedIssues: 0,
        issuesFound: issuesFound,
        message: issuesFound == 0 ? '所有数据验证通过' : '发现 $issuesFound 个问题',
      );
    } catch (e) {
      return DataRecoveryResult(
        success: false,
        repairedIssues: 0,
        issuesFound: issuesFound,
        message: '验证失败: $e',
      );
    }
  }

  /// 修复数据问题
  Future<DataRecoveryResult> repairData() async {
    var repairedIssues = 0;
    var issuesFound = 0;

    try {
      // 1. 重建存储目录
      final storagePath = await settingsService.getStoragePath();
      final storageDir = Directory(storagePath);
      if (!storageDir.existsSync()) {
        issuesFound++;
        try {
          await storageDir.create(recursive: true);
          repairedIssues++;
          _log.info('Created storage directory: $storagePath');
        } catch (e) {
          _log.error('Failed to create storage directory', error: e);
        }
      }

      // 2. 重建节点目录
      final nodesPath = await settingsService.getNodesPath();
      final nodesDir = Directory(nodesPath);
      if (!nodesDir.existsSync()) {
        issuesFound++;
        try {
          await nodesDir.create(recursive: true);
          repairedIssues++;
          _log.info('Created nodes directory: $nodesPath');
        } catch (e) {
          _log.error('Failed to create nodes directory', error: e);
        }
      }

      // 3. 重建图目录
      final graphsPath = await settingsService.getGraphsPath();
      final graphsDir = Directory(graphsPath);
      if (!graphsDir.existsSync()) {
        issuesFound++;
        try {
          await graphsDir.create(recursive: true);
          repairedIssues++;
          _log.info('Created graphs directory: $graphsPath');
        } catch (e) {
          _log.error('Failed to create graphs directory', error: e);
        }
      }

      // 4. 重新初始化仓库
      if (nodeRepository is FileSystemNodeRepository) {
        issuesFound++;
        try {
          await (nodeRepository as FileSystemNodeRepository).init();
          repairedIssues++;
        } catch (e) {
          _log.error('Failed to reinitialize node repository', error: e);
        }
      }

      if (graphRepository is FileSystemGraphRepository) {
        issuesFound++;
        try {
          await (graphRepository as FileSystemGraphRepository).init();
          repairedIssues++;
        } catch (e) {
          _log.error('Failed to reinitialize graph repository', error: e);
        }
      }

      // 5. 重建索引
      try {
        await _rebuildIndex();
        repairedIssues++;
      } catch (e) {
        issuesFound++;
        _log.error('Failed to rebuild index', error: e);
      }

      // 6. 修复当前图设置
      try {
        await _repairCurrentGraph();
        repairedIssues++;
      } catch (e) {
        issuesFound++;
        _log.error('Failed to repair current graph', error: e);
      }

      return DataRecoveryResult(
        success: true,
        repairedIssues: repairedIssues,
        issuesFound: issuesFound,
        message: repairedIssues > 0 ? '成功修复 $repairedIssues 个问题' : '没有需要修复的问题',
      );
    } catch (e) {
      return DataRecoveryResult(
        success: false,
        repairedIssues: repairedIssues,
        issuesFound: issuesFound,
        message: '修复失败: $e',
      );
    }
  }

  /// 重建节点索引
  Future<void> _rebuildIndex() async {
    final nodes = await nodeRepository.queryAll();
    // 通过保存所有节点来重建索引
    for (final node in nodes) {
      try {
        await nodeRepository.updateIndex(node);
      } catch (e) {
        _log.warning('Failed to update index for node ${node.id}', error: e);
      }
    }
    _log.info('Rebuilt index with ${nodes.length} nodes');
  }

  /// 修复当前图设置
  Future<void> _repairCurrentGraph() async {
    final currentGraph = await graphRepository.getCurrent();
    if (currentGraph == null) {
      // 尝试设置第一个可用图为当前图
      final graphs = await graphRepository.getAll();
      if (graphs.isNotEmpty) {
        await graphRepository.setCurrent(graphs.first.id);
        _log.info('Set current graph to: ${graphs.first.name}');
      } else {
        // 创建默认图
        if (graphRepository is FileSystemGraphRepository) {
          await (graphRepository as FileSystemGraphRepository)
              .createDefaultGraph();
          _log.info('Created default graph');
        }
      }
    }
  }

  /// 备份当前数据
  Future<String?> backupData() async {
    try {
      final backupPath =
          '${await settingsService.getStoragePath()}/backup_${DateTime.now().millisecondsSinceEpoch}';
      final backupDir = Directory(backupPath);
      await backupDir.create(recursive: true);

      // 备份节点
      final nodesPath = await settingsService.getNodesPath();
      final nodesDir = Directory(nodesPath);
      if (nodesDir.existsSync()) {
        await _copyDirectory(nodesDir, Directory('$backupPath/nodes'));
      }

      // 备份图
      final graphsPath = await settingsService.getGraphsPath();
      final graphsDir = Directory(graphsPath);
      if (graphsDir.existsSync()) {
        await _copyDirectory(graphsDir, Directory('$backupPath/graphs'));
      }

      return backupPath;
    } catch (e) {
      _log.error('Failed to backup data', error: e);
      return null;
    }
  }

  /// 复制目录
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list()) {
      if (entity is File) {
        final newPath = path.join(destination.path, path.basename(entity.path));
        await entity.copy(newPath);
      } else if (entity is Directory) {
        final newDir = Directory(
          path.join(destination.path, path.basename(entity.path)),
        );
        await _copyDirectory(entity, newDir);
      }
    }
  }

  /// 获取可恢复的错误信息
  String getRecoveryMessage(Object error) {
    if (error is FileSystemException) {
      if (error.message.contains('Cannot find file') ||
          error.message.contains('No such file') ||
          error.message.contains('does not exist')) {
        return '数据文件丢失或被删除。点击"修复数据"来自动恢复。';
      }
      if (error.message.contains('Permission denied')) {
        return '没有访问权限。请检查文件权限或选择其他存储位置。';
      }
    }
    if (error is RepositoryException) {
      if (error.message.contains('Failed to create') ||
          error.message.contains('does not exist')) {
        return '数据目录丢失。点击"修复数据"来自动创建必要目录。';
      }
    }
    return '发生错误: $error';
  }

  /// 检查是否为可恢复的错误
  bool isRecoverableError(Object error) {
    if (error is FileSystemException) {
      final msg = error.message.toLowerCase();
      return msg.contains('cannot find') ||
          msg.contains('no such file') ||
          msg.contains('does not exist') ||
          msg.contains('directory');
    }
    if (error is RepositoryException) {
      final msg = error.message.toLowerCase();
      return msg.contains('failed to create') ||
          msg.contains('does not exist') ||
          msg.contains('not found') ||
          msg.contains('directory');
    }
    return false;
  }
}
