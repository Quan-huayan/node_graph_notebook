/// RecoveryPlugin —— 数据恢复插件（M7，01 拍板 #35）。
///
/// 贡献：Backup / Verify / Repair Handler（写命令，03 §四）——
/// 启动失败恢复路径 = 宿主调用方按需触发（架构 §4 失败行为）。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:plugon/plugon.dart';

import 'src/recovery_handlers.dart';

/// 数据恢复插件。
class RecoveryPlugin extends Plugin {
  /// 插件实例。
  ///
  /// [servicesProvider] 宿主最新 provider 入口（M7 修正，见
  /// HostRuntime.serviceProvider；缺省 = onLoad 快照，兼容单插件测试）。
  RecoveryPlugin({ServiceProvider Function()? servicesProvider})
    : _servicesProvider = servicesProvider;

  final ServiceProvider Function()? _servicesProvider;

  ServiceProvider? _snapshot;

  /// 服务解析：宿主入口（运行时最新）优先；缺省回退 onLoad 快照。
  ServiceProvider get _services => _servicesProvider?.call() ?? _snapshot!;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.recovery',
    name: '数据恢复插件',
    version: '1.0.0',
  );

  @override
  Future<void> onLoad(PluginContext context) async {
    _snapshot = context.services;
  }

  @override
  void registerExtensions(ExtensionRegistry registry) {
    final graphProvider = () => _services.get<Graph>();
    registry.addContribution(
      commandHandlerPoint,
      BackupHandler(graphProvider: graphProvider),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      VerifyHandler(graphProvider: graphProvider),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      RepairHandler(graphProvider: graphProvider),
      ownerPluginId: metadata.id,
    );
  }
}
