/// MarketPlugin —— 插件市场插件（M7，01 拍板 #40）。
///
/// 市场对话框 = 插件内 UI（M7 修正）：注册 'market.open' 工具栏动作
/// （按钮 = UI 节点，动作 = 本插件 UI）；已装插件列表经 plugon DI
/// 的 `List<Plugin>` 服务（宿主注册），不依赖组合根。
///
/// M7.1 修正（M7 插件约束 #41 补漏）：动作点击解析服务必须经构造
/// 注入的 servicesProvider 宿主入口——onLoad 快照会被后续 loadPlugin
/// dispose（plugon：每次 loadPlugin 销毁旧 provider），设置/市场
/// 插件此前漏改，点击即崩（"ServiceProvider 已销毁"）。
library;

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:plugon/plugon.dart';

import 'src/market_dialog.dart';

/// 插件市场插件。
class MarketPlugin extends Plugin {
  /// [servicesProvider] 宿主注入的**最新** provider 解析入口
  /// （M7 修正模式，见 GraphPlugin 同款注释）。
  MarketPlugin({ServiceProvider Function()? servicesProvider})
    : _servicesProvider = servicesProvider;

  final ServiceProvider Function()? _servicesProvider;

  ServiceProvider? _snapshot;

  /// 服务解析：宿主入口（运行时最新）优先；缺省回退 onLoad 快照
  /// （单插件测试兼容）。
  ServiceProvider get _provider => _servicesProvider?.call() ?? _snapshot!;

  /// 市场插件元数据（R6 简注）：插件市场身份 com.example.market，版本 1.0.0，
  /// 静态列表来自宿主已装配插件（MVP 无网络）。
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.market',
    name: '插件市场插件',
    version: '1.0.0',
  );

  @override
  Future<void> onLoad(PluginContext context) async {
    // R13 豁免注释（docs/review 总览 P1-5 裁决）：生产路径永远经宿主注入的
    // servicesProvider 运行时求值（01 #47）；快照仅单插件测试兜底，非生产装配依赖。
    _snapshot = context.services;
    // M7 修正（Hook 承载 UI）：注册市场动作——按钮 = UI 节点
    // （metadata.action = 'market.open'），动作 = 本插件对话框。
    _provider.get<ToolbarActionRegistry>().register('market.open', (ctx) {
      showDialog<void>(
        context: ctx,
        builder: (context) => MarketDialog(
          plugins: _provider.get<List<Plugin>>(),
          i18n: _provider.get<I18nService>(),
        ),
      );
    });
  }
}
