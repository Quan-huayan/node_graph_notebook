import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_base.dart';
import 'bloc/converter_bloc.dart';
import 'converter_toolbar_hook.dart';
import 'service/converter_service_bindings.dart';
import 'service/import_export_service.dart';

/// Converter 插件
///
/// 提供导入导出功能：数据导入、数据导出等
class ConverterPlugin extends Plugin {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'converter',
    name: 'Converter',
    version: '1.0.0',
    description: 'Data import and export functionality',
    author: 'Node Graph Notebook',
    enabledByDefault: true,
  );

  @override
  List<ServiceBinding> registerServices() => [
    ConverterServiceBinding(),
    ImportExportServiceBinding(),
  ];

  @override
  List<BlocProvider> registerBlocs() => [
    BlocProvider<ConverterBloc>(
      create: (ctx) =>
          ConverterBloc(importExportService: ctx.read<ImportExportService>()),
    ),
  ];

  @override
  List<HookFactory> registerHooks() => [
    ConverterToolbarHook.new,
  ];

  @override
  Future<void> onLoad(PluginContext context) async {
    // 加载时的逻辑
  }

  @override
  Future<void> onEnable() async {
    // 启用时的逻辑
  }

  @override
  Future<void> onDisable() async {
    // 禁用时的逻辑
  }

  @override
  Future<void> onUnload() async {
    // 卸载时的逻辑
  }
}
