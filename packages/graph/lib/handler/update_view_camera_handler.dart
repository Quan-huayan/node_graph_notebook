import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';
import 'package:core_data/core_data.dart';

import '../command/graph_commands.dart';
import '../service/graph_service.dart';

/// 更新视图相机处理器
///
/// 处理更新图视图相机配置的命令
class UpdateViewCameraHandler implements CommandHandler<UpdateViewCameraCommand> {
  /// 构造函数
  ///
  /// [_service] - 图形服务，用于获取和更新图
  UpdateViewCameraHandler(this._service);

  final GraphService _service;

  @override
  Future<CommandResult> execute(
    UpdateViewCameraCommand command,
    CommandContext context,
  ) async {
    try {
      // 保存旧视图配置（用于撤销）
      final oldGraph = await _service.getGraph(command.graphId);
      if (oldGraph == null) {
        return CommandResult.failure('图不存在：${command.graphId}');
      }
      command.oldViewConfig = oldGraph.viewConfig;

      // 构建新的相机配置
      final currentCamera = oldGraph.viewConfig.camera;
      final newZoomLevel = command.zoomLevel ?? currentCamera.zoom;

      final newViewConfig = oldGraph.viewConfig.copyWith(
        camera: Camera(
          x: command.position.dx,
          y: command.position.dy,
          zoom: newZoomLevel,
          centerWidth: currentCamera.centerWidth,
          centerHeight: currentCamera.centerHeight,
        ),
      );

      // 更新图
      final updatedGraph = await _service.updateGraph(
        command.graphId,
        viewConfig: newViewConfig,
      );

      return CommandResult.success(updatedGraph);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
