/// NoteRowView —— 笔记行（M7 修正，Hook Tree 落地）。
///
/// NoteConcept 的 Hook 在 kind == 'sidebar' 时的呈现——**侧边栏笔记
/// 行 = 笔记自己的 Hook 渲染**（02 §3.2：父容器不代替子 Hook 渲染）。
/// 职责：Draggable（拖拽源——拖到 folder 的 DragTarget = 数据命令）
/// + 点击打开（渲染自己的 'open' 形态 Hook——编辑器视图）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

/// 笔记行（sidebar 形态）。
class NoteRowView extends StatelessWidget {
  /// 注入宿主、笔记节点与拖拽起点记录（飞行视觉）。
  const NoteRowView({
    super.key,
    required this.host,
    required this.node,
    this.onDragStart,
  });

  /// 宿主组合根。
  final HostRuntime host;

  /// 笔记节点。
  final Node node;

  /// 拖拽起点记录（飞行视觉——目标容器经 DragController 读取）。
  final DragStartHandler? onDragStart;

  @override
  Widget build(BuildContext context) => Draggable<String>(
    data: node.id,
    feedback: Material(
      color: Colors.transparent,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(node.title),
        ),
      ),
    ),
    onDragStarted: () {
      final box = context.findRenderObject() as RenderBox?;
      onDragStart?.call(
        node.id,
        box == null ? Offset.zero : box.localToGlobal(Offset.zero),
      );
    },
    child: ListTile(
      dense: true,
      leading: const Icon(Icons.description, size: 18),
      title: Text(node.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      // P1-5：侧边栏删除入口（确认 → DeleteNodeCommand，DTO 在 core——
      // 插件互相不依赖，通信走 Command，04 §三 约束 3）。
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 18),
        tooltip: host.i18nService.t('node.delete'),
        onPressed: () => _delete(context),
      ),
      // 打开 = 渲染自己的 'open' 形态 Hook（编辑器视图）——
      // Hook Tree 的一致呈现（02 §1.2 形态由 kind 决定）。
      // M7.2（D1 弹框归属，用户裁决）：外壳收敛 = openNodeDialog 共用助手
      // （关闭按钮 + 回收 + 最近打开记录）。
      onTap: () => openNodeDialog(context, host, node.id),
    ),
  );

  /// 删除（P1-5：确认对话框共用壳 → DeleteNodeCommand 写路径；
  /// 失败反馈对齐架构 §8）。
  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDeleteNodeConfirm(
      context,
      i18n: host.i18nService,
      title: node.title,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await host.commandBus.dispatch<DeleteNodeCommand, DeleteNodeResult>(
        DeleteNodeCommand(nodeId: node.id),
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${host.i18nService.t('error.operationFailed')}: $error',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
}
