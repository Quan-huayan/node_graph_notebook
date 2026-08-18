/// ToolbarActionsRow —— 工具栏按钮行（M7.2，00 删除清单"工具栏 =
/// 容器 Node 的 Hook"落地）。
///
/// ToolbarContainerHook.render 挂载本行；**子级 = HookView 递归**
/// （02 §3.2：父 Hook 驱动子 Hook，不代替子渲染——每个按钮 = 自己的
/// ToolbarHook，自动枚举）。与 FolderView 模式同构。
///
/// M7.3（Flowing UI）：本行也是 **DragTarget**——拖节点到工具栏 =
/// 建按钮（语义服务 ToolbarDropSemantics 决定命令，缺省
/// CreateToolbarButtonCommand：按钮点击打开该节点对话框）。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import '../command/create_toolbar_button.dart';
import '../host/host_runtime.dart';
import '../interaction/drag_controller.dart';
import 'hook_view.dart';
import 'toolbar_container_concept.dart';

/// 工具栏按钮行（AppBar actions 内容）。
class ToolbarActionsRow extends StatelessWidget {
  /// 注入宿主与工具栏容器节点。
  const ToolbarActionsRow({super.key, required this.host, required this.node});

  /// 宿主组合根。
  final HostRuntime host;

  /// 工具栏容器节点（kind == 'toolbar-root'）。
  final Node node;

  /// toolbar 语义的命令工厂：ToolbarDropSemantics 服务先问
  /// （插件 last-wins 覆盖），null → 默认建打开源节点的按钮。
  Command _toolbarMoveFactory({
    required String draggedNodeId,
    required String targetContainerId,
    required Map<String, String> newReferences,
  }) {
    final semantics = host.serviceProvider.get<ToolbarDropSemantics>();
    return semantics(draggedNodeId: draggedNodeId) ??
        CreateToolbarButtonCommand(sourceId: draggedNodeId);
  }

  @override
  Widget build(BuildContext context) {
    final childIds =
        const ToolbarContainerConcept().childNodeIdsOf(node, host.graph) ??
        const <String>[];
    // M7.3：整行接收拖拽（拖到工具栏 = 建按钮）。高亮反馈 = 边框
    // （拖拽中提示可放置区）。
    return DragTarget<String>(
      onAcceptWithDetails: (details) async {
        final source = host.graph.get(details.data);
        final targetHook = const ToolbarContainerConcept().createHook(
          node,
          const HookContext(kind: 'toolbar-root'),
        );
        // M7.4（Flowing UI 落点语义统一）：工具栏 drop 也走共享
        // DragController/FlightShell——成功飞行、失败回弹、状态清理与
        // folder 路径同一套事务（旧实现直接 dispatch，绕过了 03 §一）。
        final outcome = await host.dragController.onDrop(
          draggedNodeId: details.data,
          targetContainerHook: targetHook,
          dropPoint: details.offset,
          from: host.dragController.dragStartOffset ?? details.offset,
          overlay: Overlay.of(context),
          flightChild: source == null
              ? null
              : _ToolbarFlightCard(title: source.title),
          moveCommandFactory: _toolbarMoveFactory,
        );
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              outcome.kind == DropOutcomeKind.committed
                  ? '${host.i18nService.t('toolbar.buttonCreated')}「${source?.title ?? details.data}」'
                  : '${host.i18nService.t('error.operationFailed')}：${outcome.reason ?? ''}',
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      builder: (context, candidates, rejected) {
        final highlight = candidates.isNotEmpty;
        return DecoratedBox(
          decoration: highlight
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                )
              : const BoxDecoration(),
          child: ConstrainedBox(
            // 空工具栏也可拖放（M7.3：拖入建按钮——零尺寸行不可命中；
            // 高度对齐 AppBar 标准 48）。
            constraints: const BoxConstraints(minWidth: 56, minHeight: 48),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final childId in childIds)
                  HookView(host: host, nodeId: childId, kind: 'toolbar'),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 工具栏拖拽飞行影像（03 §二 壳层影像——纯渲染，不接触数据层）。
class _ToolbarFlightCard extends StatelessWidget {
  const _ToolbarFlightCard({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: Card(
      elevation: 6,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      ),
    ),
  );
}
