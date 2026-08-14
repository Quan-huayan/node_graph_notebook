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

  @override
  Widget build(BuildContext context) {
    final childIds =
        const ToolbarContainerConcept().childNodeIdsOf(node, host.graph) ??
        const <String>[];
    // M7.3：整行接收拖拽（拖到工具栏 = 建按钮）。高亮反馈 = 边框
    // （拖拽中提示可放置区）。
    return DragTarget<String>(
      onAcceptWithDetails: (details) async {
        final semantics = host.serviceProvider.get<ToolbarDropSemantics>();
        final custom = semantics(draggedNodeId: details.data);
        final command =
            custom ?? CreateToolbarButtonCommand(sourceId: details.data);
        try {
          await host.commandBus.dispatch<Command, WriteResult>(command);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${host.i18nService.t('toolbar.buttonCreated')}「${host.graph.get(details.data)?.title ?? details.data}」',
                ),
                duration: const Duration(seconds: 1),
              ),
            );
          }
        } catch (error) {
          // 命令失败（源节点缺失等）→ 静默（无副作用）。
          debugPrint('toolbar drop failed: $error');
        }
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
