import 'package:flutter/foundation.dart';

import '../plugin_lifecycle.dart';
import 'hook_base.dart';

/// Hook 状态枚举
///
/// 定义 Hook 的生命周期状态
///
/// 架构说明：
/// - Hook 的状态管理与 Plugin 分离，但保持同步
/// - 比 Plugin 状态更简单（没有 enableFailed 等状态）
/// - 支持 Hook 独立于 Plugin 的生命周期管理
enum HookState {
  /// 未初始化状态
  ///
  /// Hook 已创建但尚未初始化
  uninitialized,

  /// 已初始化状态
  ///
  /// Hook 已初始化，可以渲染但功能未激活
  initialized,

  /// 已启用状态
  ///
  /// Hook 功能已激活，可以正常使用
  enabled,

  /// 已禁用状态
  ///
  /// Hook 功能已停用，但可以重新启用
  disabled,

  /// 已销毁状态
  ///
  /// Hook 已销毁，不能再被使用
  disposed,
}

/// Hook 生命周期管理器
///
/// 管理 Hook 的状态转换和生命周期
///
/// 架构说明：
/// - 类似 PluginLifecycleManager，但更简化
/// - 支持与父 Plugin 的状态同步
/// - 提供状态转换验证和错误处理
class HookLifecycleManager {
  /// 创建一个新的 Hook 生命周期管理器实例
  ///
  /// [hookId] Hook 的唯一标识符（用于日志）
  HookLifecycleManager(this.hookId);

  /// Hook 的唯一标识符
  final String hookId;

  /// 当前 Hook 状态
  HookState _state = HookState.uninitialized;

  /// 当前状态
  HookState get state => _state;

  /// 是否已初始化
  bool get isInitialized => _state != HookState.uninitialized;

  /// 是否已启用
  bool get isEnabled => _state == HookState.enabled;

  /// 是否已禁用
  bool get isDisabled => _state == HookState.disabled;

  /// 是否已销毁
  bool get isDisposed => _state == HookState.disposed;

  /// 检查是否可以转换到目标状态
  ///
  /// [targetState] 目标状态
  /// 返回 true 如果可以转换，否则返回 false
  bool canTransitionTo(HookState targetState) {
    switch (_state) {
      case HookState.uninitialized:
        return targetState == HookState.initialized;

      case HookState.initialized:
        return targetState == HookState.enabled ||
            targetState == HookState.disposed;

      case HookState.enabled:
        return targetState == HookState.disabled ||
            targetState == HookState.disposed;

      case HookState.disabled:
        return targetState == HookState.enabled ||
            targetState == HookState.disposed;

      case HookState.disposed:
        // 已销毁的状态不能转换到任何其他状态
        return false;
    }
  }

  /// 转换到目标状态
  ///
  /// [targetState] 目标状态
  /// [action] 状态转换时执行的操作
  ///
  /// 抛出 StateError 如果状态转换无效
  /// 抛出异常 如果 action 执行失败
  Future<void> transitionTo(
    HookState targetState,
    Future<void> Function() action,
  ) async {
    debugPrint('[HookLifecycleManager] transitionTo:');
    debugPrint('  - Hook: $hookId');
    debugPrint('  - From state: $_state');
    debugPrint('  - To state: $targetState');
    debugPrint('  - Can transition: ${canTransitionTo(targetState)}');

    if (!canTransitionTo(targetState)) {
      debugPrint('[HookLifecycleManager] ✗ Cannot transition!');
      throw StateError(
          'Invalid state transition for hook $hookId: $_state → $targetState');
    }

    try {
      debugPrint('[HookLifecycleManager] Executing action...');
      await action();
      _state = targetState;
      debugPrint('[HookLifecycleManager] ✓ State transition successful!');
      debugPrint('  - New state: $_state');
    } catch (e) {
      debugPrint('[HookLifecycleManager] ✗ Action failed: $e');
      // Hook 状态转换失败时，保持原状态
      // 与 Plugin 不同，Hook 不会设置失败状态
      debugPrint('[HookLifecycleManager] State unchanged: $_state');
      rethrow;
    }
  }

  @override
  String toString() => 'HookLifecycleManager($hookId, state: $_state)';
}

/// Hook 包装器
///
/// 包装 Hook 及其生命周期管理器，并可选地关联父 Plugin
///
/// 架构说明：
/// - 类似 PluginWrapper，但专门用于 Hook
/// - 支持可选的父 Plugin 关联（用于状态同步）
/// - 提供 isEnabled 的复合判断（考虑父 Plugin 状态）
/// - 跟踪注册顺序以支持稳定的排序算法
class HookWrapper {
  /// 创建一个新的 Hook 包装器实例
  ///
  /// [hook] Hook 实例
  /// [lifecycle] Hook 生命周期管理器
  /// [registrationOrder] Hook 注册顺序计数器（用于稳定排序）
  /// [parentPlugin] 可选的父 Plugin 包装器
  HookWrapper(
    this.hook,
    this.lifecycle,
    this.registrationOrder, {
    this.parentPlugin,
  });

  /// Hook 实例
  ///
  /// 使用 UIHookBase 类型（新系统）
  final UIHookBase hook;

  /// Hook 生命周期管理器
  final HookLifecycleManager lifecycle;

  /// Hook 注册顺序
  ///
  /// 用于在优先级相同时保持稳定的排序顺序
  /// 数值越小表示注册越早，应该排在前面
  final int registrationOrder;

  /// 可选的父 Plugin 包装器
  ///
  /// 如果 Hook 由 Plugin 提供，parentPlugin 指向该 Plugin 的包装器
  /// 用于状态同步：Hook 的 isEnabled 应该与父 Plugin 的 isEnabled 同步
  final PluginWrapper? parentPlugin;

  /// 是否已启用
  ///
  /// 复合判断：
  /// - 如果有父 Plugin，则父 Plugin 必须启用，且 Hook 本身也启用
  /// - 如果没有父 Plugin，则只检查 Hook 本身的启用状态
  bool get isEnabled {
    // Hook 本身必须启用
    if (!lifecycle.isEnabled) return false;

    // 如果有父 Plugin，父 Plugin 也必须启用
    if (parentPlugin != null && !parentPlugin!.isEnabled) return false;

    return true;
  }

  /// 是否已初始化
  bool get isInitialized => lifecycle.isInitialized;

  /// 是否已销毁
  bool get isDisposed => lifecycle.isDisposed;

  @override
  String toString() =>
      'HookWrapper(hook: $hook, state: ${lifecycle.state}, isEnabled: $isEnabled)';
}

/// Hook 包装器工厂
///
/// 提供静态方法创建 HookWrapper 实例
///
/// 架构说明：
/// - 封装 HookWrapper 的创建逻辑
/// - 支持新系统的 UIHookBase
/// - 统一的 Hook 包装器创建入口
/// - 维护全局注册顺序计数器以支持稳定排序
class HookWrapperFactory {
  /// 私有构造函数，防止实例化
  HookWrapperFactory._();

  /// 全局 Hook 注册顺序计数器
  ///
  /// 每次创建 HookWrapper 时递增，用于在优先级相同时保持稳定排序
  /// 确保先注册的 Hook 总是在相同优先级的其他 Hook 前面
  static int _registrationCounter = 0;

  /// 包装新的 Hook
  ///
  /// [hook] UIHookBase 实例
  /// [parentPlugin] 可选的父 Plugin 包装器
  /// 返回 HookWrapper 实例
  static HookWrapper wrapNewHook(
    UIHookBase hook, {
    PluginWrapper? parentPlugin,
  }) {
    final lifecycle = HookLifecycleManager(hook.metadata.id);
    final order = _registrationCounter++;

    // 自动转换到 initialized 状态，使 Hook 可用
    lifecycle.transitionTo(HookState.initialized, () async {});

    return HookWrapper(
      hook,
      lifecycle,
      order,
      parentPlugin: parentPlugin,
    );
  }

  /// 重置注册计数器
  ///
  /// 主要用于测试，确保测试之间的隔离性
  static void resetCounter() {
    _registrationCounter = 0;
  }
}
