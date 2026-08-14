import 'package:appframe/service/storage_path_service.dart';
import 'package:core/core.dart' hide Plugin, PluginManager;
import 'package:flutter/material.dart';
import 'package:plugin/plugin.dart';

import 'command/backup_data_command.dart';
import 'command/repair_data_command.dart';
import 'command/validate_data_command.dart';
import 'handler/backup_data_handler.dart';
import 'handler/repair_data_handler.dart';
import 'handler/validate_data_handler.dart';

/// 数据恢复插件
class DataRecoveryPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'data_recovery',
    name: 'Data Recovery',
    version: '1.0.0',
    description: 'Data validation, repair, and backup functionality',
    author: 'Node Graph Notebook',
  );

  @override
  Future<void> onLoad(PluginContext context) async {
    _registerCommandHandlers(context);
    debugPrint('[DataRecoveryPlugin] DataRecovery plugin loaded');
  }

  void _registerCommandHandlers(PluginContext context) {
    final commandBus = context.get<CommandBus>();
    final nodeRepository = context.get<NodeRepository>();
    final graphRepository = context.get<GraphRepository>();
    final storagePathService = context.get<StoragePathService>();

    commandBus.registerHandlers({
      ValidateDataCommand: ValidateDataHandler(
        nodeRepository: nodeRepository,
        graphRepository: graphRepository,
        storagePathService: storagePathService,
      ),
      RepairDataCommand: RepairDataHandler(
        nodeRepository: nodeRepository,
        graphRepository: graphRepository,
        storagePathService: storagePathService,
      ),
      BackupDataCommand: BackupDataHandler(
        storagePathService: storagePathService,
      ),
    });
  }
}
