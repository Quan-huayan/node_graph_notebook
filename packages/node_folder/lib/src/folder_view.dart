/// FolderView —— 文件夹容器视图（M7 修正，02 §3.2 Hook Tree 落地）。
///
/// **父 Hook 驱动子 Hook 的递归，不代替子 Hook 渲染**：
/// FolderHook.render 挂载本容器；容器内子级 = **HookView 递归**
/// （childNodeIdsOf 容器语义推导 → 子节点 Hook 渲染——笔记行由
/// editor 插件 NoteConcept 的 Hook（kind='sidebar'）渲染，拖拽源、
/// 点击打开全在子 Hook）。
///
/// 容器自身职责：DragTarget（接收拖入 = 数据命令，判据①）+ 展开态。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import 'contain_concept.dart';
import 'folder_concept.dart';
import 'folder_create.dart';
import 'folder_create_dialog.dart';
import 'move_nodes.dart';

/// 文件夹容器视图（Hook Tree 的一层）。
class FolderView extends StatefulWidget {
  /// 注入宿主、文件夹节点与渲染形态。
  const FolderView({
    super.key,
    required this.host,
    required this.node,
    required this.kind,
  });

  /// 宿主组合根。
  final HostRuntime host;

  /// 文件夹节点。
  final Node node;

  /// 渲染形态（子级继承）。
  final String kind;

  @override
  State<FolderView> createState() => _FolderViewState();
}

class _FolderViewState extends State<FolderView> {
  /// 共享拖拽事务（HostRuntime 单例，M7.4）——dragStart/onDrop 同源。
  DragController get _drag => widget.host.dragController;

  /// Phase 1：开启共享事务并记录影像起点（拖拽源统一入口）。
  void _recordDragStart(String nodeId, Offset position) {
    _drag.dragStart(nodeId);
    _drag.recordDragStart(position);
  }

  /// folder 语义的命令工厂（共享事务按目标容器路由的实例级覆盖）。
  Command _folderMoveFactory({
    required String draggedNodeId,
    required String targetContainerId,
    required Map<String, String> newReferences,
  }) {
    final semantics = widget.host.serviceProvider.get<SidebarDropSemantics>();
    final custom = semantics(
      draggedNodeId: draggedNodeId,
      targetContainerId: targetContainerId,
    );
    if (custom != null) {
      return custom;
    }
    return MoveNodesCommand(
      containerId: targetContainerId,
      childId: draggedNodeId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final node = widget.node;
    // 子级 = 容器语义推导（00 推论 3：childNodeIdsOf）。
    final children = childrenOf(widget.host.graph, node.id).toList();
    // 根容器（kind == 'sidebar-root'）：额外渲染"未归类笔记"区——
    // 游离内容节点（无 contain 指向的普通笔记）。
    final isRoot = widget.kind == 'sidebar-root';
    // M7.2（E2 实施缺口修复）：folder 也是拖拽源（03 判据① 侧边栏
    // 重排含 folder——嵌套文件夹拖拽）；根容器除外（树根不可被拖入
    // 其他容器）。拖拽起点记录（飞行视觉，同 NoteRowView 模式）。
    final content = DragTarget<String>(
      onAcceptWithDetails: (details) async {
        final start = _drag.dragStartOffset ?? details.offset;
        final child = widget.host.graph.get(details.data);
        final hook = const FolderConcept().createHook(
          node,
          const HookContext(kind: 'sidebar'),
        );
        // M7.4：成功飞行 / 失败回弹统一由 DragController 编排——
        // 不再先 fly 再按结果 bounce（旧路径存在双影像竞态）。
        final outcome = await _drag.onDrop(
          draggedNodeId: details.data,
          targetContainerHook: hook,
          dropPoint: details.offset,
          from: start,
          overlay: Overlay.of(context),
          flightChild: child == null ? null : _FlightCard(title: child.title),
          moveCommandFactory: _folderMoveFactory,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              // R11 裁决（docs/review 总览 P0-1）：成功 = 键内置 %s 占位并入
              // 标题（「」括号随语言进词典）；失败按 kind 分键——reason 为
              // 内部诊断文本不上屏。
              content: Text(
                outcome.kind == DropOutcomeKind.committed
                    ? widget.host.i18nService
                          .t('folder.moved')
                          .replaceFirst('%s', node.title)
                    : widget.host.i18nService.t(
                        outcome.kind == DropOutcomeKind.cycleRejected
                            ? 'drag.cycleRejected'
                            : 'drag.rejected',
                      ),
              ),
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
      builder: (context, candidates, rejected) {
        final highlight = candidates.isNotEmpty;
        final card = Card(
          color: highlight
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ExpansionTile(
            leading: const Icon(Icons.folder),
            title: Text(node.title),
            subtitle: Text(
              widget.host.i18nService
                  .t('folder.itemCount')
                  .replaceFirst('%s', '${children.length}'),
            ),
            // P1-5：侧边栏删除入口（根容器除外——根 = 数据树地基）。
            // B3：文件夹内新建入口（Obsidian 同款「+」——根除外，
            // 根下建 = 未归类，语义归属普通新建）。
            trailing: isRoot
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        icon: const Icon(Icons.note_add_outlined, size: 18),
                        tooltip: widget.host.i18nService.t('folder.createIn'),
                        onPressed: () => _create(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: widget.host.i18nService.t('node.delete'),
                        onPressed: () => _delete(context),
                      ),
                    ],
                  ),
            children: [
              // 02 §3.2：子级 = HookView 递归——子 Hook 渲染自己
              // （笔记行由 editor 插件 NoteConcept 的 Hook 渲染）。
              for (final childId in children)
                HookView(
                  host: widget.host,
                  nodeId: childId,
                  kind: 'sidebar',
                  onDragStart: _recordDragStart,
                ),
            ],
          ),
        );
        // 根容器：未归类笔记区（游离内容节点 = 无 contain 指向的
        // 普通笔记——00 语义：不属于任何文件夹的笔记挂在根）。
        if (!isRoot) {
          return card;
        }
        final unfiled = _unfiledNotes();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            card,
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                // M7.2（i18n 壳层）：文案走语言包（切换即时生效）。
                widget.host.i18nService.t('note.unfiled'),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
            // 02 §3.2：游离笔记 = 笔记 Hook 渲染（同树递归）。
            for (final noteId in unfiled)
              HookView(
                host: widget.host,
                nodeId: noteId,
                kind: 'sidebar',
                onDragStart: _recordDragStart,
              ),
          ],
        );
      },
    );
    if (isRoot) {
      return content;
    }
    // 拖拽源（非根容器）：feedback = 飞行影像卡片；起点记录 =
    // 目标容器飞行视觉的 from（03 §二 壳层）。
    return Draggable<String>(
      data: node.id,
      feedback: _FlightCard(title: node.title),
      onDragStarted: () {
        final box = context.findRenderObject() as RenderBox?;
        _recordDragStart(
          node.id,
          box == null ? Offset.zero : box.localToGlobal(Offset.zero),
        );
      },
      child: content,
    );
  }

  /// 文件夹内新建（B3：对话框收集 → CreateNodeInFolderCommand 写路径，
  /// 判据①；一步撤销 = 删除新笔记（级联 contain）——UndoManager Ctrl+Z）。
  Future<void> _create(BuildContext context) async {
    final result = await showFolderCreateDialog(
      context,
      widget.host.i18nService,
    );
    if (result == null || !context.mounted) {
      return;
    }
    final (title, content) = result;
    try {
      await widget.host.commandBus
          .dispatch<CreateNodeInFolderCommand, CreateNodeInFolderResult>(
            CreateNodeInFolderCommand(
              folderId: widget.node.id,
              id: folderNewNodeId(),
              title: title,
              content: content,
            ),
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.host.i18nService
                  .t('folder.createdIn')
                  .replaceFirst('%s', title),
            ),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } on StateError catch (error) {
      // 已知失败：目标文件夹不存在 / 目标 id 已存在（R9 类型化捕获，
      // R3b 失败可见——audit-node_folder #2）。
      debugPrint('folder view create rejected: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.host.i18nService.t('error.operationFailed')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on CycleError catch (error) {
      // 已知失败：新建 contain 成环（R9 类型化捕获）。
      debugPrint('folder view create cycle rejected: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.host.i18nService.t('error.operationFailed')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      // UI 边界兜底豁免（R9 注释，docs/review 总览 P0-1 裁决）：用户入口的
      // 回调不得泄漏未捕获异常（05 纪律 8：任何失败须有用户可见反馈）；
      // 未知编程错误保留诊断痕迹（debugPrint），原始 error 文本不上屏。
      debugPrint('folder view create failed: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.host.i18nService.t('error.operationFailed')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 删除（P1-5：确认对话框共用壳 → DeleteNodeCommand 写路径；
  /// 级联 = 引用本文件夹的 contain 实例一并删除，子笔记保留）。
  Future<void> _delete(BuildContext context) async {
    final node = widget.node;
    final confirmed = await showDeleteNodeConfirm(
      context,
      i18n: widget.host.i18nService,
      title: node.title,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    try {
      await widget.host.commandBus
          .dispatch<DeleteNodeCommand, DeleteNodeResult>(
            DeleteNodeCommand(nodeId: node.id),
          );
    } on StateError catch (error) {
      // 已知失败：目标文件夹不存在（R9 类型化捕获，R3b 失败可见）。
      debugPrint('folder view delete rejected: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.host.i18nService.t('error.operationFailed')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on CycleError catch (error) {
      // 已知失败：级联删除成环（R9 类型化捕获）。
      debugPrint('folder view delete cycle rejected: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.host.i18nService.t('error.operationFailed')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      // UI 边界兜底豁免（R9 注释，docs/review 总览 P0-1 裁决）：用户入口的
      // 回调不得泄漏未捕获异常（05 纪律 8：任何失败须有用户可见反馈）；
      // 未知编程错误保留诊断痕迹（debugPrint），原始 error 文本不上屏。
      debugPrint('folder view delete failed: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.host.i18nService.t('error.operationFailed')),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// 游离笔记：普通笔记（references 空 ∧ 无 kind）∧ 无 contain 指向。
  List<String> _unfiledNotes() {
    final graph = widget.host.graph;
    final contained = graph
        .getAll()
        .where((n) => n.references['child'] != null)
        .map((n) => n.references['child']!)
        .toSet();
    return graph
        .getAll()
        .where(
          (n) =>
              n.references.isEmpty &&
              n.metadata['kind'] == null &&
              !contained.contains(n.id),
        )
        .map((n) => n.id)
        .toList();
  }
}

/// 飞行影像卡片（03 §二 壳层影像——纯渲染，不接触数据层）。
class _FlightCard extends StatelessWidget {
  const _FlightCard({required this.title});

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
