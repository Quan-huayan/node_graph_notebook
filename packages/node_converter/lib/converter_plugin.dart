/// ConverterPlugin —— 导入导出插件（M7，01 拍板 #37）。
///
/// 贡献：Export / Import Handler（写命令，03 §四）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:plugon/plugon.dart';

import 'src/converter_dialog.dart';
import 'src/converter_handlers.dart';

/// 导入导出插件。
class ConverterPlugin extends Plugin {
  /// 插件实例。
  ///
  /// [servicesProvider] 宿主最新 provider 入口（M7 修正，见
  /// HostRuntime.serviceProvider；缺省 = onLoad 快照，兼容单插件测试）。
  ConverterPlugin({ServiceProvider Function()? servicesProvider})
    : _servicesProvider = servicesProvider;

  final ServiceProvider Function()? _servicesProvider;

  ServiceProvider? _snapshot;

  /// 服务解析：宿主入口（运行时最新）优先；缺省回退 onLoad 快照。
  ServiceProvider get _services => _servicesProvider?.call() ?? _snapshot!;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.converter',
    name: '导入导出插件',
    version: '1.0.0',
  );

  @override
  Future<void> onLoad(PluginContext context) async {
    _snapshot = context.services;
    // M7.2（converter 可见性恢复）：注册导入导出动作——按钮 = UI 节点
    // （metadata.action = 'converter.open'），动作 = 本插件对话框。
    _services.get<ToolbarActionRegistry>().register('converter.open', (ctx) {
      showDialog<void>(
        context: ctx,
        builder: (context) => Dialog(
          child: SizedBox(
            width: 520,
            height: 360,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: _services.get<I18nService>().t('dialog.close'),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                Expanded(
                  child: ConverterDialog(host: _services.get<HostRuntime>()),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  void registerExtensions(ExtensionRegistry registry) {
    final graphProvider = () => _services.get<Graph>();
    registry.addContribution(
      commandHandlerPoint,
      ExportHandler(graphProvider: graphProvider),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      ImportHandler(graphProvider: graphProvider),
      ownerPluginId: metadata.id,
    );
  }
}
