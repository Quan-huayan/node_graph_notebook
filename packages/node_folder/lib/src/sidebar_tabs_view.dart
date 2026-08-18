/// SidebarTabsView —— 侧边栏容器（M7.2，Flowing UI 具象化：
/// 侧边栏 = 多形态容器，用户裁决——搜索等工具面板应在侧边栏）。
///
/// 'sidebar-root' 形态 = **Tab 容器**：Tab1 = 文件夹树（本容器内容），
/// Tab2..N = **面板节点**（`references.sidebar == 根节点 id` 反查——
/// settings 容器同款模式，插件不互依赖）：面板 = 子 Hook 的
/// 'sidebar-panel' 形态渲染（搜索面板 = node_search 贡献）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import 'folder_view.dart';

/// 侧边栏 Tab 容器（sidebar-root 形态）。
class SidebarTabsView extends StatefulWidget {
  /// 注入宿主与根节点。
  const SidebarTabsView({
    super.key,
    required this.host,
    required this.node,
    this.onDragStart,
  });

  /// 宿主组合根。
  final HostRuntime host;

  /// 根节点（kind == 'folder'，sidebar 语义）。
  final Node node;

  /// 面板内拖拽源起点上报（共享 DragController，M7.4）。
  final DragStartHandler? onDragStart;

  @override
  State<SidebarTabsView> createState() => _SidebarTabsViewState();
}

class _SidebarTabsViewState extends State<SidebarTabsView>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  late final void Function() _onSearchSignal;

  @override
  void initState() {
    super.initState();
    // P1-4（Ctrl+F）：壳层信号 → 切到搜索面板 tab（判据③ 会话态，
    // 信号只通知不落盘——UIStateStore 是判据② 外观通道）。
    _onSearchSignal = () {
      final controller = _tabController;
      final panelIds = _panelIds();
      final index = panelIds
          .where(
            (id) =>
                widget.host.graph.get(id)?.metadata['kind'] == 'search-panel',
          )
          .map(panelIds.indexOf)
          .firstOrNull;
      if (controller != null && index != null && mounted) {
        controller.animateTo(index + 1);
      }
    };
    widget.host.shellSignals.addListener(_onSearchSignal);
  }

  @override
  void dispose() {
    widget.host.shellSignals.removeListener(_onSearchSignal);
    _tabController?.dispose();
    super.dispose();
  }

  /// 面板节点 id（references.sidebar == 根 id，数据引用，零插件依赖）。
  List<String> _panelIds() => widget.host.graph
      .getAll()
      .where((n) => n.references['sidebar'] == widget.node.id)
      .map((n) => n.id)
      .toList();

  /// Tab 变化 → 若切到搜索面板 tab（点击或 Ctrl+F 动画到达），再发一次
  /// 聚焦信号——搜索面板据此聚焦输入框（键盘/鼠标直达搜索，UX P2）。
  /// 幂等：已聚焦再通知无副作用；无搜索面板时无操作。
  void _onTabChanged() {
    final controller = _tabController;
    if (!mounted || controller == null) {
      return;
    }
    final panelIds = _panelIds();
    final index = controller.index - 1; // 0 = 文件夹 tab，面板从 1 起。
    if (index < 0 || index >= panelIds.length) {
      return;
    }
    final panel = widget.host.graph.get(panelIds[index]);
    if (panel?.metadata['kind'] == 'search-panel') {
      widget.host.shellSignals.requestSearchFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final root = widget.node;
    final panelIds = _panelIds();
    final folderView = FolderView(
      host: widget.host,
      node: root,
      kind: 'sidebar-root',
    );
    if (panelIds.isEmpty) {
      return folderView;
    }
    // 显式 TabController（P1-4：壳层信号可切换；UX：tab 变更 → 聚焦信号）。
    _tabController ??= TabController(length: panelIds.length + 1, vsync: this)
      ..addListener(_onTabChanged);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: <Widget>[
            Tab(text: widget.host.i18nService.t('folder.header')),
            // 面板 Tab 标签 = 面板节点标题（容器呈现子级标签的最小数据）。
            for (final id in panelIds)
              Tab(text: widget.host.graph.get(id)?.title ?? id),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: <Widget>[
              folderView,
              // 面板内容 = 子 Hook 的 'sidebar-panel' 形态（父驱动子，
              // 不代替子渲染）。
              for (final id in panelIds)
                HookView(
                  host: widget.host,
                  nodeId: id,
                  kind: 'sidebar-panel',
                  onDragStart: widget.onDragStart,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
