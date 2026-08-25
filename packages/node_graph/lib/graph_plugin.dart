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

import 'dart:io';

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
import 'src/node_dialogs.dart';

/// 新建笔记对话框 + 写路径（M8：动作实现归插件——Ctrl+N 与画布双击
/// 空白共用 NodeEditDialog，数据命令经 CommandBus 落盘，判据①）。
Future<void> _showCreateNoteDialog(
  BuildContext context,
  ServiceProvider services,
) async {
  final i18n = services.get<I18nService>();
  final form = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) => NodeEditDialog(
      dialogTitle: i18n.t('node.create'),
      i18n: i18n,
    ),
  );
  if (form == null) {
    return;
  }
  final id = newNodeId();
  final kind = form['kind'] as String?;
  try {
    await services.get<CommandBus>().dispatch<CreateNodeCommand, CreateNodeResult>(
      CreateNodeCommand(
        id: id,
        title: form['title'] as String,
        content: form['content'] as String,
        metadata: kind == null || kind == 'note'
            ? null
            : <String, dynamic>{'kind': kind},
      ),
    );
  } on IOException {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(i18n.t('error.saveFailed')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
    return;
  } on StateError {
    // 已知类型化失败（命令路由/前置校验）→ 用户可见反馈，原始 error
    // 不上屏（R11 统一裁决）。
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(i18n.t('error.operationFailed')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (error) {
    // UI 边界兜底豁免（R9 注释，docs/review 总览 P0-1 裁决）：用户入口的
    // 回调不得泄漏未捕获异常（05 纪律 8：任何失败须有用户可见反馈）；
    // 未知编程错误保留诊断痕迹（debugPrint），原始 error 文本不上屏。
    debugPrint('<新建笔记> failed: $error');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(i18n.t('error.operationFailed')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

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

  /// R13 豁免注释（docs/review 总览 P1-5 裁决）：生产路径永远经宿主注入的
  /// servicesProvider 运行时求值（01 #47）；快照仅单插件测试兜底，非生产
  /// 装配依赖。
  ServiceProvider? _snapshot;

  /// 服务解析：宿主入口（运行时最新）优先；缺省回退 onLoad 快照。
  ///
  /// R13 豁免注释（docs/review 总览 P1-5 裁决）：生产路径永远经宿主注入的
  /// servicesProvider 运行时求值（01 #47）；快照仅单插件测试兜底，非生产
  /// 装配依赖。
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
    // R13 豁免注释（docs/review 总览 P1-5 裁决）：生产路径永远经宿主注入的
    // servicesProvider 运行时求值（01 #47）；快照仅单插件测试兜底，非生产
    // 装配依赖。
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
    // M8（组合根回调移除，01 拍板 #32 反转）：Ctrl+N / 命令面板「新建
    // 笔记」= 动作注册——**拥有 NodeEditDialog + CreateNodeCommand 写
    // 路径的插件注册实现**（本插件 = 对话框归属方）。壳层（NotebookApp）
    // 只把 NewNoteIntent 映射到动作名 'note.create'，app 组合根零实现。
    _provider.get<ToolbarActionRegistry>().register('note.create', (ctx) {
      // 运行时最新 provider（M7 修正模式——plugon 每次 loadPlugin 重建）。
      _showCreateNoteDialog(ctx, _provider);
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
