/// NotebookApp —— 应用根（M7 修正，app 包零 UI 强限制）。
///
/// MaterialApp 包装（主题/明暗）+ AppShell——**应用壳全在 appframe**，
/// app 包只组装（runApp(NotebookApp)），无任何 UI 代码。
///
/// M7.2（E3 实施缺口修复）：主题状态 = 壳层概念——组合根注入
/// [ThemeController]（拍板 #39"组合根读取并应用"接线）：设置插件经
/// DI 编辑控制器，本根经 ListenableBuilder 响应运行时切换。
library;

import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../host/host_runtime.dart';
import '../host/vault_manager.dart';
import '../render/flutter_render_context.dart';
import 'app_shell.dart';
import 'command_palette.dart';
import 'quick_switcher.dart';
import 'theme_controller.dart';
import 'toolbar_concept.dart';

/// 应用根。
class NotebookApp extends StatelessWidget {
  /// 注入宿主、根节点、数据层回调与主题控制器（组合根注入）。
  ///
  /// [vaultManager] 多仓库管理器（null = 单仓库模式，测试兼容）——
  /// 非空时整树随仓库切换键控重建（M7.3：热切换不重启进程）。
  NotebookApp({
    super.key,
    required this.host,
    required this.rootNodeId,
    this.onCardDrop,
    this.onNewNote,
    this.themeController,
    this.vaultManager,
  });

  /// Navigator 全局键（P1-4：全局快捷键在 MaterialApp 外层——无焦点时
  /// 也须生效；Ctrl+N 弹对话框需要 Navigator 之下的上下文，经此键取得）。
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 宿主组合根。
  final HostRuntime host;

  /// 前端图根节点（sidebar 语义）。
  final String rootNodeId;

  /// 画布卡片 drop 语义分发（数据层——组合根注入，01 拍板 #32）。
  final CanvasCardDropHandler? onCardDrop;

  /// Ctrl+N 新建笔记（组合根注入——对话框在 graph 插件，appframe
  /// 零插件依赖，01 拍板 #32 同款语义分发模式）。
  final void Function(BuildContext context)? onNewNote;

  /// 主题控制器（null = 固定跟随系统，测试/无设置场景）。
  final ThemeController? themeController;

  /// 多仓库管理器（M7.3）。
  final VaultManager? vaultManager;

  @override
  Widget build(BuildContext context) {
    final controller = themeController;
    final manager = vaultManager;
    // 主题运行时切换 + 仓库热切换（键控整树重建）。
    // 注意：builder 内必须重新 _buildApp（闭包捕获旧 widget 实例
    // 会冻结重建——实测 theme 切换失效）。
    Widget buildApp() => _buildApp(context);
    if (manager != null) {
      // 仓库切换 → 以仓库 id 为 key 强制重建全部子树（新 host 的
      // HookView 树；旧树销毁后旧 host 才 post-frame dispose）。
      return ListenableBuilder(
        listenable: manager,
        builder: (context, _) => KeyedSubtree(
          key: ValueKey<String>('vault-${manager.current.id}'),
          child: controller == null
              ? buildApp()
              : ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) => buildApp(),
                ),
        ),
      );
    }
    if (controller == null) {
      return buildApp();
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => buildApp(),
    );
  }

  Widget _buildApp(BuildContext context) {
    // M7.3（vault）：当前仓库的 host 为准（键控重建后 manager.host 已换新）。
    final effectiveHost = vaultManager?.host ?? host;
    final effectiveTheme =
        vaultManager?.host.themeController ?? themeController;
    // P1-2/P1-4：全局快捷键在 MaterialApp **外层**——焦点无处时按键
    // 事件仍会冒泡到本 Shortcuts（在 AppShell 内层则无焦点即失效）。
    // Ctrl+N 的对话框上下文经 navigatorKey 取得（Navigator 之下）。
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyZ, control: true): UndoIntent(),
        SingleActivator(LogicalKeyboardKey.keyY, control: true): RedoIntent(),
        SingleActivator(LogicalKeyboardKey.keyN, control: true): NewNoteIntent(),
        SingleActivator(LogicalKeyboardKey.keyF, control: true): SearchIntent(),
        // B1/B2：命令面板 Ctrl+P / 快速切换 Ctrl+O（Obsidian 同款）。
        SingleActivator(LogicalKeyboardKey.keyP, control: true): PaletteIntent(),
        SingleActivator(LogicalKeyboardKey.keyO, control: true): QuickSwitchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          UndoIntent: CallbackAction<UndoIntent>(
            onInvoke: (_) {
              effectiveHost.undoManager.undo();
              return null;
            },
          ),
          RedoIntent: CallbackAction<RedoIntent>(
            onInvoke: (_) {
              effectiveHost.undoManager.redo();
              return null;
            },
          ),
          NewNoteIntent: CallbackAction<NewNoteIntent>(
            onInvoke: (_) {
              final navContext = navigatorKey.currentContext;
              if (navContext != null) {
                onNewNote?.call(navContext);
              }
              return null;
            },
          ),
          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (_) {
              effectiveHost.shellSignals.requestSearchFocus();
              return null;
            },
          ),
          PaletteIntent: CallbackAction<PaletteIntent>(
            onInvoke: (_) {
              final ctx = navigatorKey.currentContext;
              if (ctx != null) {
                showCommandPalette(
                  ctx,
                  _paletteEntries(ctx, effectiveHost, onNewNote),
                  emptyMessage: effectiveHost.i18nService.t('palette.empty'),
                );
              }
              return null;
            },
          ),
          QuickSwitchIntent: CallbackAction<QuickSwitchIntent>(
            onInvoke: (_) {
              final ctx = navigatorKey.currentContext;
              if (ctx != null) {
                showQuickSwitcher(
                  ctx,
                  effectiveHost,
                  hint: effectiveHost.i18nService.t('quickswitch.hint'),
                  empty: effectiveHost.i18nService.t('quickswitch.empty'),
                );
              }
              return null;
            },
          ),
        },
        child: MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Node Graph Notebook',
          theme: _themeData(Brightness.light, effectiveTheme),
          darkTheme: _themeData(Brightness.dark, effectiveTheme),
          themeMode: _themeModeOf(effectiveTheme),
          // M7.2（字体设置）：文字缩放经 MediaQuery 应用（设置条目可调）。
          builder: (context, child) {
            final scale = effectiveTheme?.textScale ?? 1.0;
            if (scale == 1.0) {
              return child!;
            }
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
          home: AppShell(
            host: effectiveHost,
            rootNodeId: rootNodeId,
            onCardDrop: onCardDrop,
            vaultManager: vaultManager,
          ),
        ),
      ),
    );
  }

  ThemeData _themeData(Brightness brightness, ThemeController? controller) =>
      ThemeData(
        colorSchemeSeed: const Color(0xFF4F46E5),
        brightness: brightness,
        useMaterial3: true,
        // M7.2（字体设置）：具体字体族切换（null = 平台默认）。
        fontFamily: controller?.fontFamily,
      );

  ThemeMode _themeModeOf(ThemeController? controller) {
    switch (controller?.mode ?? AppThemeMode.system) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

/// Ctrl+Z 撤销意图。
class UndoIntent extends Intent {
  /// 构造意图。
  const UndoIntent();
}

/// Ctrl+Y 重做意图。
class RedoIntent extends Intent {
  /// 构造意图。
  const RedoIntent();
}

/// Ctrl+N 新建笔记意图。
class NewNoteIntent extends Intent {
  /// 构造意图。
  const NewNoteIntent();
}

/// Ctrl+F 搜索面板意图。
class SearchIntent extends Intent {
  /// 构造意图。
  const SearchIntent();
}

/// Ctrl+P 命令面板意图（B1）。
class PaletteIntent extends Intent {
  /// 构造意图。
  const PaletteIntent();
}

/// Ctrl+O 快速切换意图（B2）。
class QuickSwitchIntent extends Intent {
  /// 构造意图。
  const QuickSwitchIntent();
}

/// 命令面板条目（B1：内置 + 工具栏动作数据驱动）。
///
/// 工具栏按钮 = 节点（00"All is Node"）：kind=='toolbar' 的节点即命令
/// 入口——动作名查 ToolbarActionRegistry（targeted 优先），图标/标签
/// 取节点 metadata（icon/tooltip）。
List<PaletteEntry> _paletteEntries(
  BuildContext ctx,
  HostRuntime host,
  void Function(BuildContext)? newNote,
) {
  final t = host.i18nService.t;
  return <PaletteEntry>[
    if (newNote != null)
      PaletteEntry(
        label: t('palette.newNote'),
        icon: Icons.note_add_outlined,
        run: () => newNote(ctx),
      ),
    PaletteEntry(
      label: t('palette.search'),
      icon: Icons.search,
      run: () => host.shellSignals.requestSearchFocus(),
    ),
    PaletteEntry(
      label: t('palette.quickSwitch'),
      icon: Icons.swap_horiz,
      run: () => showQuickSwitcher(
        ctx,
        host,
        hint: t('quickswitch.hint'),
        empty: t('quickswitch.empty'),
      ),
    ),
    PaletteEntry(
      label: t('palette.toggleTheme'),
      icon: Icons.brightness_6_outlined,
      run: () => host.themeController.cycle(),
    ),
    // 工具栏动作（kind=='toolbar' 且有 action + tooltip）。
    for (final node in host.graph.getAll())
      if (node.metadata['kind'] == 'toolbar' &&
          node.metadata['action'] is String &&
          node.metadata['tooltip'] is String)
        PaletteEntry(
          label: node.metadata['tooltip'] as String,
          icon: ToolbarHook.iconFor(node.metadata['icon'] as String?),
          run: () => _runPaletteAction(
            ctx,
            host,
            node,
            node.metadata['action'] as String,
          ),
        ),
  ];
}

/// 执行工具栏动作（targeted 优先——M7.3 同 ToolbarHook._runAction 语义）。
void _runPaletteAction(
  BuildContext ctx,
  HostRuntime host,
  Node node,
  String action,
) {
  final registry = host.toolbarActions;
  final target = node.metadata['target'] as String?;
  final targeted = registry.lookupTargeted(action);
  if (targeted != null && target != null) {
    targeted(ctx, target);
    return;
  }
  registry.lookup(action)?.call(ctx);
}
