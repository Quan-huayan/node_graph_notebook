/// GraphPlugin —— 画布插件（M6 试金石，04 里程碑）。
///
/// 贡献：CanvasConcept（画布容器：UIMove 判据② 判定 + 成员语义）、
/// ConnectionConcept（连接关系 L1）+ 节点操作命令 Handler
/// （create/update/delete/connect——写操作唯一执行者，03 §四）。
///
/// M7 修正（Hook 承载 UI）：画布 UI 在插件内——CanvasHook.render 挂载
/// GraphCanvas（AppShell 主区经 HookView 渲染）；'canvas.manage' 动作
/// （按钮 = UI 节点，动作 = 本插件对话框）。M7.1：画布成员卡片 = 成员
/// 节点自己的物化 Hook 渲染（kind='graph'，卡片体进各自插件），
/// 画布只提供定位与交互壳。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:plugon/plugon.dart';

import 'src/canvas_concept.dart';
import 'src/connection_concept.dart';
import 'src/global_graph_dialog.dart';
import 'src/graph_nodes_dialog.dart';
import 'src/layout/layout_commands.dart';
import 'src/layout/layout_dialog.dart';
import 'src/node_commands.dart';

/// 画布插件。
class GraphPlugin extends Plugin {
  /// 无状态插件（画布渲染 UI 由宿主装配；命令依赖延迟解析）。
  ///
  /// [servicesProvider] 宿主注入的**最新** provider 解析入口（M7 修正：
  /// plugon loadPlugin 会 dispose 旧 provider——onLoad 快照在多插件场景
  /// 失效；缺省 = onLoad 快照，兼容单插件测试）。注入见
  /// `HostRuntime.serviceProvider`。
  GraphPlugin({ServiceProvider Function()? servicesProvider})
    : _servicesProvider = servicesProvider;

  final ServiceProvider Function()? _servicesProvider;

  ServiceProvider? _snapshot;

  /// 服务解析：宿主入口（运行时最新）优先；缺省回退 onLoad 快照。
  ServiceProvider get _provider => _servicesProvider?.call() ?? _snapshot!;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.graph',
    name: '画布插件',
    version: '1.0.0',
  );

  @override
  Future<void> onLoad(PluginContext context) async {
    // 快照兜底（单插件测试）；多插件场景由宿主注入最新 provider 入口。
    _snapshot = context.services;
    // M7 修正（Hook 承载 UI）：注册"画布管理"工具栏动作——按钮 =
    // UI 节点（metadata.action = 'canvas.manage'），动作 = 本插件 UI。
    _provider.get<ToolbarActionRegistry>().register('canvas.manage', (ctx) {
      showDialog<void>(
        context: ctx,
        builder: (context) => GraphNodesDialog(
          graph: _provider.get<Graph>(),
          uiStateStore: _provider.get<UIStateStore>(),
          i18n: _provider.get<I18nService>(),
        ),
      );
    });
    // M7.3 布局动作（工具栏按钮 'layout.apply' + 画布空白右键共用对话框）。
    _provider.get<ToolbarActionRegistry>().register('layout.apply', (ctx) {
      showDialog<void>(
        context: ctx,
        builder: (context) =>
            CanvasLayoutDialog(host: _provider.get<HostRuntime>()),
      );
    });
    // C1：全局图谱（Obsidian Graph view 语义）——只读只读对话框（纯内存
    // 力导向；按钮/命令面板数据驱动自动入列，动作名 'graph.global'）。
    _provider.get<ToolbarActionRegistry>().register('graph.global', (ctx) {
      showGlobalGraphDialog(ctx, _provider.get<HostRuntime>());
    });
  }

  @override
  void registerExtensions(ExtensionRegistry registry) {
    // 画布容器 Concept（drop 语义判定 + 结构识别）。
    registry.addContribution(
      conceptPoint,
      const CanvasConcept(),
      ownerPluginId: metadata.id,
    );
    // 连接关系 Concept（边 = L1-node 实例，00 §2.2）。
    registry.addContribution(
      conceptPoint,
      const ConnectionConcept(),
      ownerPluginId: metadata.id,
    );
    // 节点操作命令（写操作唯一执行者：Graph/UIStateStore 写）。
    registry.addContribution(
      commandHandlerPoint,
      CreateNodeHandler(graphProvider: () => _provider.get<Graph>()),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      UpdateNodeHandler(graphProvider: () => _provider.get<Graph>()),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      DeleteNodeHandler(
        graphProvider: () => _provider.get<Graph>(),
        uiStateProvider: () => _provider.get<UIStateStore>(),
      ),
      ownerPluginId: metadata.id,
    );
    // P1-2：删除撤销的对偶 Handler（快照回写）。
    registry.addContribution(
      commandHandlerPoint,
      RestoreNodeHandler(
        graphProvider: () => _provider.get<Graph>(),
        uiStateProvider: () => _provider.get<UIStateStore>(),
      ),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      ConnectNodesHandler(graphProvider: () => _provider.get<Graph>()),
      ownerPluginId: metadata.id,
    );
    // M7.3 布局（长任务 Handler：计算 → UIStateStore 位置键直写，判据②）。
    registry.addContribution(
      commandHandlerPoint,
      ApplyLayoutHandler(
        graphProvider: () => _provider.get<Graph>(),
        uiStateProvider: () => _provider.get<UIStateStore>(),
      ),
      ownerPluginId: metadata.id,
    );
  }
}
