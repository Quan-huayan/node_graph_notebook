/// ConverterPlugin —— 导入导出插件（M7，01 拍板 #37）。
///
/// 贡献：Export / Import Handler（写命令，03 §四）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:plugon/plugon.dart';

import 'src/converter_commands.dart';
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
    // A4（单节点导出）：注册**目标动作** `converter.exportNote`——编辑器
    // （node_editor，插件互不依赖）经 registry 查动作名触发，不 import
    // 本插件；target = 节点 id → 导出该节点为 Markdown（ExportCommand
    // nodeIds 已支持单节点，M7 双格式复用）。动作未注册（插件未加载）
    // → 编辑器菜单隐藏（registry 驱动，零耦合）。
    _services.get<ToolbarActionRegistry>().registerTargeted(
      'converter.exportNote',
      (ctx, nodeId) {
        final host = _services.get<HostRuntime>();
        final sep = Platform.pathSeparator;
        final dir = '${host.dataRoot.path}${sep}exports';
        final node = host.graph.get(nodeId);
        final slug = (node?.title ?? nodeId)
            .trim()
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .replaceAll(RegExp(r'\s+'), '_');
        final path =
            '$dir${sep}note-$slug-${DateTime.now().microsecondsSinceEpoch}.md';
        host.commandBus
            .dispatch<ExportCommand, ExportResult>(
              ExportCommand(path: path, nodeIds: <String>{nodeId}),
            )
            .then((_) {
          if (ctx.mounted) {
            final i18n = _services.get<I18nService>();
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text(
                  i18n.t('converter.exported')
                      .replaceFirst('%s', '1')
                      .replaceFirst('%s', path),
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }).catchError((Object error) {
          if (ctx.mounted) {
            final i18n = _services.get<I18nService>();
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text('${i18n.t('converter.exportFailed')}: $error'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
      },
    );
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
