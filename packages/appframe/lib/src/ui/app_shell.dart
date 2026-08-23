/// AppShell —— 应用壳（M7 修正，00"UI 是 Hook 构成的图"落地）。
///
/// app 包零 UI（强限制）——本壳在 appframe：只提供布局骨架与
/// **Hook 渲染宿主**，不 import 任何插件：
/// - AppBar：渲染 kind == 'toolbar' 的 UI 节点 Hook（按钮动作 =
///   ToolbarActionRegistry，All is Node——不发明 UI 扩展点）
/// - 左侧区域：根节点 Hook（FolderHook 挂载文件夹树）
/// - 主区域：canvas 节点 Hook（CanvasHook 挂载画布）
///
/// 节点打开 = HookView（点击节点 → 渲染其 Hook——AIHook 对话视图、
/// 笔记 Hook 编辑器视图）；插件 UI 全在插件内；app 只组装。
library;

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../host/host_runtime.dart';
import '../host/vault_manager.dart';
import '../knowledge/backlink_service.dart';
import '../render/flutter_render_context.dart';
import 'hook_view.dart';

/// 应用壳。
class AppShell extends StatefulWidget {
  /// 注入宿主（组合根）、根节点与数据层回调（01 拍板 #32）。
  const AppShell({
    super.key,
    required this.host,
    required this.rootNodeId,
    this.onCardDrop,
    this.vaultManager,
  });

  /// 宿主组合根。
  final HostRuntime host;

  /// 前端图根节点（sidebar 语义）。
  final String rootNodeId;

  /// 画布卡片 drop 语义分发（数据层——组合根注入）。
  final CanvasCardDropHandler? onCardDrop;

  /// 多仓库管理器（null = 单仓库模式；非空 → AppBar 仓库切换器，
  /// M7.3 Obsidian 式多仓库）。
  final VaultManager? vaultManager;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final void Function(InvalidationEvent) _onInvalidation;
  late final void Function() _onI18n;

  @override
  void initState() {
    super.initState();
    // P1-6：首启引导（一次性——onboarding.shown 标记经 host.prefs；
    // prefs null = 测试/无持久化场景，不弹）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final prefs = widget.host.prefs;
      if (prefs == null || (prefs.getBool('onboarding.shown') ?? false)) {
        return;
      }
      prefs.setBool('onboarding.shown', true);
      _showOnboarding();
    });
    // M7.1（UIManager 管线接入）：壳级重建由失效事件驱动，不再整树
    // setState——结构变更恒重建（标题/工具栏/画布发现是结构级）；
    // 数据变更仅当涉及壳直接呈现的节点（root 标题 / toolbar / canvas）。
    _onInvalidation = (event) {
      if (!mounted) {
        return;
      }
      if (event.changeKind == ChangeKind.structure ||
          event.nodeIds.contains(widget.rootNodeId) ||
          event.nodeIds.any(_isShellNode)) {
        setState(() {});
      }
    };
    if (widget.host.started) {
      widget.host.uiManager.addListener(_onInvalidation);
    }
    // M7.2（i18n 壳层）：语言切换 → 壳级重建（全局文案即时生效）。
    _onI18n = () {
      if (mounted) {
        setState(() {});
      }
    };
    widget.host.i18nService.addListener(_onI18n);
  }

  @override
  void dispose() {
    widget.host.i18nService.removeListener(_onI18n);
    if (widget.host.started) {
      widget.host.uiManager.removeListener(_onInvalidation);
    }
    super.dispose();
  }

  /// 壳直接呈现的节点（工具栏容器/按钮 / 画布容器——结构判定，无概念依赖）。
  bool _isShellNode(String nodeId) {
    final node = widget.host.graph.get(nodeId);
    if (node == null) {
      return false;
    }
    final kind = node.metadata['kind'];
    return kind == 'toolbar-root' || kind == 'toolbar' || kind == 'canvas';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_appTitle()),
      actions: <Widget>[
        // M7.3（多仓库）：仓库切换器（当前仓库名 + 下拉列表）。
        if (widget.vaultManager != null) _vaultSwitcher(context),
        ..._toolbarActions(context),
      ],
    ),
    body: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 左侧：根节点 Hook 渲染（FolderHook 挂载文件夹树；
        // 'sidebar-root' 形态 = 根容器含未归类区）。
        SizedBox(
          width: 300,
          child: HookView(
            host: widget.host,
            nodeId: widget.rootNodeId,
            kind: 'sidebar-root',
            onCardDrop: widget.onCardDrop,
            // M7.4：侧边栏内所有拖拽源（笔记行/搜索行）向共享事务
            // 记录起点——成功飞行/失败回弹的 from 不再退化到落点。
            onDragStart: _onDragStart,
          ),
        ),
        const VerticalDivider(width: 1),
        // 主区域：canvas 节点 Hook 渲染（CanvasHook 挂载画布）。
        Expanded(
          child: HookView(
            host: widget.host,
            nodeId: _canvasNodeId() ?? widget.rootNodeId,
            kind: 'graph',
            onCardDrop: widget.onCardDrop,
          ),
        ),
      ],
    ),
    // C4：状态栏（Obsidian 状态栏语义）——节点数（剔除 UI 代理，
    // 呈现计数稳定）+ 当前仓库名（多仓库）；结构失效已驱动壳级重建，
    // 计数在 build 时读 Graph（读侧直读，零额外监听）。
    bottomNavigationBar: _statusBar(context),
  );

  /// 状态栏（C4）：节点数（剔除 UI 代理）+ 当前仓库名。
  Widget _statusBar(BuildContext context) {
    final i18n = widget.host.i18nService;
    final count = widget.host.graph
        .getAll()
        .where((n) => !BacklinkService.isUiProxy(n))
        .length;
    return BottomAppBar(
      height: 28,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            Text(
              i18n.t('status.nodes').replaceFirst('%s', '$count'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Spacer(),
            if (widget.vaultManager != null)
              Text(
                '${i18n.t('status.vault')}：${widget.vaultManager!.current.name}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  /// 仓库切换器（PopupMenuButton：当前仓库名 + 列表切换，M7.3）。
  Widget _vaultSwitcher(BuildContext context) {
    final manager = widget.vaultManager!;
    return PopupMenuButton<VaultEntry>(
      tooltip: widget.host.i18nService.t('vault.title'),
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.storage, size: 18),
          const SizedBox(width: 4),
          Text(
            manager.current.name,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
      onSelected: (entry) async {
        if (entry.id == manager.current.id) {
          return;
        }
        // 切换前 pop 全部对话框（旧 host 的 UI 引用清理）。
        Navigator.of(context).popUntil((route) => route.isFirst);
        try {
          await manager.switchTo(entry.id);
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${widget.host.i18nService.t('vault.switchFailed')}: $error',
                ),
              ),
            );
          }
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<VaultEntry>>[
        for (final vault in manager.vaults)
          PopupMenuItem<VaultEntry>(
            value: vault,
            child: Row(
              children: <Widget>[
                Icon(
                  vault.id == manager.current.id
                      ? Icons.check_circle
                      : Icons.circle_outlined,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vault.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// M7.3 修正：AppBar 标题 = 应用名（语言包）。旧实现取根节点标题
  /// （seed 的 folder '根目录'）——那是侧边栏树的文件夹名，放左上角
  /// AppBar 当应用标题非常奇怪；当前仓库名已由仓库切换器呈现。
  String _appTitle() => widget.host.i18nService.t('app.title');

  /// 首启引导（P1-6：杀手演示玩法——同一份笔记在不同容器中变形）。
  void _showOnboarding() {
    final i18n = widget.host.i18nService;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n.t('onboarding.title')),
        content: Text(
          i18n.t('onboarding.body'),
          style: const TextStyle(height: 1.6),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(i18n.t('onboarding.dismiss')),
          ),
        ],
      ),
    );
  }

  /// canvas 节点（kind == 'canvas'，结构判定——不依赖 graph 插件概念）。
  String? _canvasNodeId() {
    for (final node in widget.host.graph.getAll()) {
      if (node.metadata['kind'] == 'canvas') {
        return node.id;
      }
    }
    return null;
  }

  /// AppBar 动作 = **工具栏容器 Hook 渲染**（M7.2，00 删除清单
  /// "工具栏 = 容器 Node 的 Hook"）：'toolbar-root' 容器节点 →
  /// HookView 渲染其 Hook → 容器内子级（按钮）= HookView 递归自动枚举。
  List<Widget> _toolbarActions(BuildContext context) {
    final id = _toolbarRootNodeId();
    if (id == null) {
      return const <Widget>[];
    }
    return <Widget>[
      HookView(host: widget.host, nodeId: id, kind: 'toolbar-root'),
    ];
  }

  /// 拖拽源起点上报（共享 DragController 的 Phase 1 入口）。
  void _onDragStart(String nodeId, Offset position) {
    widget.host.dragController
      ..dragStart(nodeId)
      ..recordDragStart(position);
  }

  /// 工具栏容器节点（kind == 'toolbar-root'，结构判定——壳不依赖
  /// 插件概念，同 _canvasNodeId 模式）。
  String? _toolbarRootNodeId() {
    for (final node in widget.host.graph.getAll()) {
      if (node.metadata['kind'] == 'toolbar-root') {
        return node.id;
      }
    }
    return null;
  }
}
