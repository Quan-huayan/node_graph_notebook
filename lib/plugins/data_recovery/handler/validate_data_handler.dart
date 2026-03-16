import 'dart:io';

import '../../../../core/commands/models/command.dart';
import '../../../../core/commands/models/command_context.dart';
import '../../../../core/commands/models/command_handler.dart';
import '../../../../core/repositories/graph_repository.dart';
import '../../../../core/repositories/node_repository.dart';
import '../../../../core/services/infrastructure/storage_path_service.dart';
import '../command/validate_data_command.dart';

/// 数据验证命令处理器
///
/// 验证数据完整性，检查目录、索引等
class ValidateDataHandler implements CommandHandler<ValidateDataCommand> {
  /// 创建数据验证处理器
  ValidateDataHandler({
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
  Future<CommandResult<DataValidationResult>> execute(
    ValidateDataCommand command,
    CommandContext context,
  ) async {
    var issuesFound = 0;
    final issues = <String>[];

    try {
      // 1. 验证存储目录是否存在
      final storagePath = await _storagePathService.getStoragePath();
      final storageDir = Directory(storagePath);
      if (!storageDir.existsSync()) {
        issuesFound++;
        issues.add('存储目录不存在: $storagePath');
      }

      // 2. 验证节点目录
      final nodesPath = await _storagePathService.getNodesPath();
      final nodesDir = Directory(nodesPath);
      if (!nodesDir.existsSync()) {
        issuesFound++;
        issues.add('节点目录不存在: $nodesPath');
      }

      // 3. 验证图目录
      final graphsPath = await _storagePathService.getGraphsPath();
      final graphsDir = Directory(graphsPath);
      if (!graphsDir.existsSync()) {
        issuesFound++;
        issues.add('图目录不存在: $graphsPath');
      }

      // 4. 验证节点文件
      try {
        final nodes = await _nodeRepository.queryAll();
        // 检查索引是否有效
        final index = await _nodeRepository.getMetadataIndex();
        if (index.nodes.length != nodes.length) {
          issuesFound++;
          issues.add(
            '索引不匹配: 索引中有 ${index.nodes.length} 个节点，实际有 ${nodes.length} 个文件',
          );
        }
      } catch (e) {
        issuesFound++;
        issues.add('节点验证失败: $e');
      }

      // 5. 验证图文件
      try {
        final graphs = await _graphRepository.getAll();
        final currentGraph = await _graphRepository.getCurrent();
        if (graphs.isNotEmpty && currentGraph == null) {
          issuesFound++;
          issues.add('当前图设置无效');
        }
      } catch (e) {
        issuesFound++;
        issues.add('图验证失败: $e');
      }

      final result = DataValidationResult(
        success: true,
        issuesFound: issuesFound,
        message: issuesFound == 0 ? '所有数据验证通过' : '发现 $issuesFound 个问题',
        issues: issues,
      );

      return CommandResult.success(result);
    } catch (e) {
      return CommandResult.failure('验证失败: $e');
    }
  }
}
