import 'package:flutter/material.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_lifecycle.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import '../../../core/plugin/ui_hooks/hook_registry.dart';
import 'lua_engine_service.dart';

/// Lua动态Hook管理器
///
/// 允许Lua脚本动态注册和注销UI Hook
///
/// 功能：
/// - 管理Lua脚本创建的动态Hook
/// - 提供注册/注销API
/// - 自动管理Hook生命周期
class LuaDynamicHookManager {
  /// 构造函数
  LuaDynamicHookManager({
    required this.engineService,
    required this.hookRegistry,
  });

  /// Lua引擎服务
  final LuaEngineService engineService;

  /// Hook注册表
  final HookRegistry hookRegistry;

  /// 动态Hook映射
  ///
  /// Key: Hook ID
  /// Value: Hook实例
  final Map<String, UIHookBase> _dynamicHooks = {};

  /// 注册API
  void registerAPIs() {
    // 注册工具栏按钮API
    engineService.registerFunction('registerToolbarButton', (args) {
      try {
        if (args.length < 2) {
          throw ArgumentError('registerToolbarButton requires buttonId and label');
        }

        final buttonId = args[0] as String;
        final label = args[1] as String;
        final callbackName = args.length > 2 ? args[2] as String? : null;
        final iconName = args.length > 3 ? args[3] as String? : null;

        // 异步启用Hook，不阻塞Lua脚本
        _registerToolbarButton(
          buttonId: buttonId,
          label: label,
          callbackName: callbackName,
          iconName: iconName,
        ).catchError((e) {
          debugPrint('[LuaDynamicHookManager] Error enabling hook: $e');
        });

        return 1;
      } catch (e) {
        debugPrint('[LuaDynamicHookManager] Error registering toolbar button: $e');
        return 0;
      }
    });

    // 注销工具栏按钮API
    engineService.registerFunction('unregisterToolbarButton', (args) {
      try {
        if (args.isEmpty) {
          throw ArgumentError('unregisterToolbarButton requires buttonId');
        }

        final buttonId = args[0] as String;
        return _unregisterToolbarButton(buttonId);
      } catch (e) {
        debugPrint('[LuaDynamicHookManager] Error unregistering toolbar button: $e');
        return 0;
      }
    });

    // 列出所有动态按钮（返回按钮数量）
    engineService.registerFunction('listDynamicButtons', (args) {
      final buttons = _listDynamicButtons();
      // 打印按钮列表到控制台
      debugPrint('[LuaDynamicHookManager] Dynamic buttons list:');
      for (final btn in buttons) {
        debugPrint('  - ${btn['label']} (ID: ${btn['id']})');
      }
      // 返回按钮数量
      return buttons.length;
    });

    debugPrint('[LuaDynamicHookManager] APIs registered successfully');
  }

  /// 注册工具栏按钮
  Future<int> _registerToolbarButton({
    required String buttonId,
    required String label,
    String? callbackName,
    String? iconName,
  }) async {
    // 检查是否已存在
    final hookId = 'lua.dynamic.toolbar.$buttonId';
    if (_dynamicHooks.containsKey(hookId)) {
      debugPrint('[LuaDynamicHookManager] Button $buttonId already registered, updating...');
      _unregisterToolbarButton(buttonId);
    }

    // 创建动态Hook
    final hook = _DynamicToolbarHook(
      id: hookId,
      label: label,
      callbackName: callbackName,
      iconName: iconName,
      engineService: engineService,
    );

    // 注册Hook
    hookRegistry.registerHook(hook);
    _dynamicHooks[hookId] = hook;

    // ✅ 自动初始化并启用Hook（动态Hook需要立即生效）
    // 获取HookWrapper并启用
    final hooks = hookRegistry.getHookWrappers('main.toolbar', includeDisabled: true);
    final hookWrapper = hooks.where((h) => h.hook.metadata.id == hookId).firstOrNull;

    if (hookWrapper != null) {
      // 先初始化（创建临时的HookContext）
      final tempContext = BasicHookContext(
        data: {'hookPointId': hook.hookPointId},
        pluginContext: null,
        hookAPIRegistry: null,
      );

      await hookWrapper.lifecycle.transitionTo(
        HookState.initialized,
        () => hook.onInit(tempContext),
      );
      // 再启用
      await hookWrapper.lifecycle.transitionTo(
        HookState.enabled,
        hook.onEnable,
      );
      debugPrint('[LuaDynamicHookManager] Hook enabled successfully');

      // ✅ 通知 UI 重新构建
      hookRegistry.notifyListeners();
    } else {
      debugPrint('[LuaDynamicHookManager] Warning: Hook wrapper not found');
    }

    debugPrint('[LuaDynamicHookManager] Registered toolbar button: $buttonId');
    debugPrint('  - Label: $label');
    debugPrint('  - Callback: $callbackName');
    debugPrint('  - Icon: $iconName');
    debugPrint('  - Status: Enabled ✓');

    return 1;
  }

  /// 注销工具栏按钮
  int _unregisterToolbarButton(String buttonId) {
    final hookId = 'lua.dynamic.toolbar.$buttonId';
    final hook = _dynamicHooks.remove(hookId);

    if (hook != null) {
      // ✅ 先禁用Hook，然后注销
      final hooks = hookRegistry.getHookWrappers('main.toolbar', includeDisabled: true);
      final hookWrapper = hooks.where((h) => h.hook.metadata.id == hookId).firstOrNull;

      if (hookWrapper != null && hookWrapper.isEnabled) {
        hookWrapper.lifecycle.transitionTo(
          HookState.disabled,
          hook.onDisable,
        );
        debugPrint('[LuaDynamicHookManager] Hook disabled successfully');
      }

      // ✅ 从HookRegistry中移除Hook（使用已有的hooks变量）
      hooks.removeWhere((h) => h.hook.metadata.id == hookId);

      // ✅ 通知 UI 重新构建
      hookRegistry.notifyListeners();

      debugPrint('[LuaDynamicHookManager] Unregistered toolbar button: $buttonId');
      debugPrint('  - Status: Disabled ✓');
      return 1;
    }

    debugPrint('[LuaDynamicHookManager] Button $buttonId not found');
    return 0;
  }

  /// 列出所有动态按钮
  List<Map<String, dynamic>> _listDynamicButtons() {
    final buttons = <Map<String, dynamic>>[];

    for (final entry in _dynamicHooks.entries) {
      if (entry.value is _DynamicToolbarHook) {
        final hook = entry.value as _DynamicToolbarHook;
        buttons.add({
          'id': hook.id.replaceAll('lua.dynamic.toolbar.', ''),
          'label': hook.label,
          'callback': hook.callbackName,
          'icon': hook.iconName,
        });
      }
    }

    return buttons;
  }

  /// 清空所有动态Hook
  void clear() {
    for (final hook in _dynamicHooks.values) {
      hookRegistry.unregisterHook(hook);
    }
    _dynamicHooks.clear();
    debugPrint('[LuaDynamicHookManager] All dynamic hooks cleared');
  }
}

/// 动态工具栏Hook
///
/// 由Lua脚本创建的工具栏按钮
class _DynamicToolbarHook extends MainToolbarHookBase {
  /// 构造函数
  _DynamicToolbarHook({
    required this.id,
    required this.label,
    this.callbackName,
    this.iconName,
    required this.engineService,
  });

  /// Hook ID
  final String id;

  /// 按钮标签
  final String label;

  /// Lua回调函数名
  final String? callbackName;

  /// 图标名称
  final String? iconName;

  /// Lua引擎服务
  final LuaEngineService engineService;

  @override
  HookMetadata get metadata => HookMetadata(
        id: id,
        name: 'Lua Dynamic Toolbar: $label',
        version: '1.0.0',
        description: 'Dynamic toolbar button created by Lua script',
      );

  @override
  HookPriority get priority => HookPriority.medium;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    // 解析图标
    IconData icon;
    try {
      icon = _getIconData(iconName ?? 'play_arrow');
    } catch (e) {
      icon = Icons.extension;
    }

    return IconButton(
      icon: Icon(icon, color: Colors.purple),
      tooltip: label,
      onPressed: () => _handleButtonPress(context),
    );
  }

  /// 处理按钮点击
  void _handleButtonPress(MainToolbarHookContext context) async {
    debugPrint('[$_DynamicToolbarHook] Button clicked! Label: $label, Callback: $callbackName');

    if (callbackName == null) {
      debugPrint('[$_DynamicToolbarHook] No callback specified for button $label');
      return;
    }

    debugPrint('[$_DynamicToolbarHook] Executing Lua callback: $callbackName()');

    // ✅ 使用executeString来调用Lua全局函数
    final result = await engineService.executeString('$callbackName()');

    debugPrint('[$_DynamicToolbarHook] Callback result: success=${result.success}, output=${result.output}');

    if (result.success) {
      debugPrint('[$_DynamicToolbarHook] Callback executed successfully');
    } else {
      debugPrint('[$_DynamicToolbarHook] Callback error: ${result.error}');
    }
  }

  /// 获取图标数据
  IconData _getIconData(String iconName) {
    // 常用图标映射（使用final而不是const，因为Icons.*不是编译时常量）
    final iconMap = {
      'play_arrow': Icons.play_arrow,
      'pause': Icons.pause,
      'stop': Icons.stop,
      'refresh': Icons.refresh,
      'add': Icons.add,
      'remove': Icons.remove,
      'delete': Icons.delete,
      'edit': Icons.edit,
      'save': Icons.save,
      'settings': Icons.settings,
      'search': Icons.search,
      'home': Icons.home,
      'favorite': Icons.favorite,
      'star': Icons.star,
      'thumb_up': Icons.thumb_up,
      'thumb_down': Icons.thumb_down,
      'visibility': Icons.visibility,
      'visibility_off': Icons.visibility_off,
      'lock': Icons.lock,
      'lock_open': Icons.lock_open,
      'email': Icons.email,
      'phone': Icons.phone,
      'message': Icons.message,
      'notifications': Icons.notifications,
      'alarm': Icons.alarm,
      'event': Icons.event,
      'access_time': Icons.access_time,
      'timer': Icons.timer,
      'dashboard': Icons.dashboard,
      'menu': Icons.menu,
      'more_vert': Icons.more_vert,
      'expand': Icons.expand,
      'expand_more': Icons.expand_more,
      'arrow_back': Icons.arrow_back,
      'arrow_forward': Icons.arrow_forward,
      'upload': Icons.upload,
      'download': Icons.download,
      'share': Icons.share,
      'link': Icons.link,
      'content_copy': Icons.content_copy,
      'content_cut': Icons.content_cut,
      'content_paste': Icons.content_paste,
      'undo': Icons.undo,
      'redo': Icons.redo,
      'zoom_in': Icons.zoom_in,
      'zoom_out': Icons.zoom_out,
      'fullscreen': Icons.fullscreen,
      'fullscreen_exit': Icons.fullscreen_exit,
      'close': Icons.close,
      'check': Icons.check,
      'cancel': Icons.cancel,
      'error': Icons.error,
      'warning': Icons.warning,
      'info': Icons.info,
      'help': Icons.help,
      'lightbulb': Icons.lightbulb,
      'build': Icons.build,
      'code': Icons.code,
      'terminal': Icons.terminal,
      'extension': Icons.extension,
      'widgets': Icons.widgets,
      'apps': Icons.apps,
      'grid_on': Icons.grid_on,
      'list': Icons.list,
      'view_module': Icons.view_module,
      'view_list': Icons.view_list,
    };

    return iconMap[iconName] ?? Icons.extension;
  }
}
