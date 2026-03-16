import '../../../../core/plugin/plugin.dart';
import '../../../../core/repositories/graph_repository.dart';
import '../../../../core/repositories/node_repository.dart';
import '../../../../core/services/infrastructure/storage_path_service.dart';
import 'command/backup_data_command.dart';
import 'command/repair_data_command.dart';
import 'command/validate_data_command.dart';
import 'handler/backup_data_handler.dart';
import 'handler/repair_data_handler.dart';
import 'handler/validate_data_handler.dart';

/// 数据恢复插件
///
/// 提供数据验证、修复和备份功能
/// 处理文件被外部删除或损坏的情况
class DataRecoveryPlugin extends Plugin {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
        id: 'data_recovery',
        name: 'Data Recovery',
        version: '1.0.0',
        description: 'Data validation, repair, and backup functionality',
        author: 'Node Graph Notebook',
        enabledByDefault: true,
      );

  @override
  Future<void> onLoad(PluginContext context) async {
    // 注册命令处理器
    _registerCommandHandlers(context);
    context.logger?.info('DataRecovery plugin loaded');
  }

  @override
  Future<void> onEnable() async {
    // 启用逻辑（如果需要）
  }

  @override
  Future<void> onDisable() async {
    // 禁用逻辑（如果需要）
  }

  @override
  Future<void> onUnload() async {
    // 清理逻辑（如果需要）
  }

  /// 注册命令处理器
  void _registerCommandHandlers(PluginContext context) {
    final commandBus = context.commandBus;
    final nodeRepository = context.read<NodeRepository>();
    final graphRepository = context.read<GraphRepository>();
    final storagePathService = context.read<StoragePathService>();

    // 注册命令处理器
    commandBus.registerHandlers({
      // 数据验证命令处理器
      ValidateDataCommand: ValidateDataHandler(
        nodeRepository: nodeRepository,
        graphRepository: graphRepository,
        storagePathService: storagePathService,
      ),

      // 数据修复命令处理器
      RepairDataCommand: RepairDataHandler(
        nodeRepository: nodeRepository,
        graphRepository: graphRepository,
        storagePathService: storagePathService,
      ),

      // 数据备份命令处理器
      BackupDataCommand: BackupDataHandler(
        storagePathService: storagePathService,
      ),
    });
  }
}
