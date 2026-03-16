import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../../../../core/commands/models/command_handler.dart';
import '../../../../core/services/infrastructure/storage_path_service.dart';
import '../command/backup_data_command.dart';

/// 数据备份命令处理器
///
/// 创建当前数据的完整备份
class BackupDataHandler implements CommandHandler<BackupDataCommand> {
  /// 创建数据备份处理器
  BackupDataHandler({
    required StoragePathService storagePathService,
  }) : _storagePathService = storagePathService;

  final StoragePathService _storagePathService;

  @override
  Future<CommandResult<BackupDataResult>> execute(
    BackupDataCommand command,
    CommandContext context,
  ) async {
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
        debugPrint('Backed up nodes to: $backupPath/nodes');
      }

      // 备份图
      final graphsPath = await _storagePathService.getGraphsPath();
      final graphsDir = Directory(graphsPath);
      if (graphsDir.existsSync()) {
        await _copyDirectory(graphsDir, Directory('$backupPath/graphs'));
        debugPrint('Backed up graphs to: $backupPath/graphs');
      }

      final result = BackupDataResult(
        success: true,
        backupPath: backupPath,
        message: '备份成功创建于: $backupPath',
      );

      return CommandResult.success(result);
    } catch (e) {
      return CommandResult.failure('备份失败: $e');
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
}
