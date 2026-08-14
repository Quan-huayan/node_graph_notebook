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
  late final DragController _drag;

  /// 拖拽起点（飞行视觉——子 Hook 经 onDragStart 记录）。

  @override
  void initState() {
    super.initState();
    // 拖拽事务（folder 语义：contain 实例变更——数据命令）。
    // M7.3（Flowing UI 语义分发）：宿主 SidebarDropSemantics 服务先问
    // （插件覆盖——node_ai 对 AI 节点返回 CreateAIPanelCommand = 拖 AI
    // 入侧边栏钉面板 tab）；null → 默认 folder 语义。
    _drag = DragController(
      graph: widget.host.graph,
      concepts: widget.host.concepts,
      commandBus: widget.host.commandBus,
      uiStateStore: widget.host.uiStateStore,
      flightShell: FlightShell(),
      moveCommandFactory:
          ({
            required String draggedNodeId,
            required String targetContainerId,
            required Map<String, String> newReferences,
          }) {
            final semantics = widget.host.serviceProvider
                .get<SidebarDropSemantics>();
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
          },
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
        // M7 落地（Flowing UI）：影像从源飞向目标（03 §二 壳层）。
        final start = _drag.dragStartOffset ?? details.offset;
        final child = widget.host.graph.get(details.data);
        if (child != null) {
          _drag.flightShell.fly(
            overlay: Overlay.of(context),
            child: _FlightCard(title: child.title),
            from: start,
            to: details.offset,
            onFinished: (_) {},
          );
        }
        final hook = const FolderConcept().createHook(
          node,
          const HookContext(kind: 'sidebar'),
        );
        final outcome = await _drag.onDrop(
          draggedNodeId: details.data,
          targetContainerHook: hook,
          dropPoint: details.offset,
        );
        if (outcome.kind != DropOutcomeKind.committed) {
          // 失败 → 回弹（03 Phase 4：影像弹回源位置，无副作用）。
          _drag.flightShell.bounce(
            overlay: Overlay.of(context),
            child: _FlightCard(title: child?.title ?? ''),
            from: start,
            to: details.offset,
            onFinished: (_) {},
          );
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                outcome.kind == DropOutcomeKind.committed
                    ? '${widget.host.i18nService.t('folder.moved')}「${node.title}」'
                    : '${widget.host.i18nService.t('folder.rejected')}：${outcome.reason ?? ''}',
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
            trailing: isRoot
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    tooltip: widget.host.i18nService.t('node.delete'),
                    onPressed: () => _delete(context),
                  ),
            children: [
              // 02 §3.2：子级 = HookView 递归——子 Hook 渲染自己
              // （笔记行由 editor 插件 NoteConcept 的 Hook 渲染）。
              for (final childId in children)
                HookView(
                  host: widget.host,
                  nodeId: childId,
                  kind: 'sidebar',
                  onDragStart: _drag.recordDragStart,
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
                onDragStart: _drag.recordDragStart,
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
        _drag.recordDragStart(
          box == null ? Offset.zero : box.localToGlobal(Offset.zero),
        );
      },
      child: content,
    );
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
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.host.i18nService.t('error.operationFailed')}: $error',
            ),
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
