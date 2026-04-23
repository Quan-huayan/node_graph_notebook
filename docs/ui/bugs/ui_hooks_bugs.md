# UI Hooks 模块 Bug 报告

**审查日期**: 2026-04-21  
**审查范围**: `lib/core/plugin/ui_hooks` 文件夹

---

## Bug 1: SidebarHookBase 和 StatusBarHookBase 缺少 hookPointId 覆写

**严重程度**: 高 (功能失效)

**位置**: [hook_base.dart:307](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_base.dart#L307) / [hook_base.dart:348](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_base.dart#L348)

**问题描述**:  
`SidebarHookBase` 和 `StatusBarHookBase` 没有覆写 `hookPointId`，而 `UIHookBase` 中的 `hookPointId` 是抽象 getter（必须由子类实现）。其他所有专用 Hook 基类（如 `MainToolbarHookBase`、`SidebarBottomHookBase`、`SettingsHookBase` 等）都正确覆写了 `hookPointId`。这意味着：

1. `SidebarHookBase` 和 `StatusBarHookBase` 的子类必须自行覆写 `hookPointId`，否则编译错误
2. 这与设计意图不符——专用基类应该提供默认的 `hookPointId`，让子类无需关心挂载点
3. 如果子类忘记覆写或覆写了错误的 `hookPointId`，Hook 会注册到错误的挂载点

**问题代码**:
```dart
// SidebarHookBase - 缺少 hookPointId 覆写！
abstract class SidebarHookBase extends UIHookBase {
  @override
  Widget render(HookContext context) {
    final sidebarContext = SidebarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderSidebar(sidebarContext);
  }

  Widget renderSidebar(SidebarHookContext context);
}

// 对比：SidebarBottomHookBase - 正确覆写了 hookPointId
abstract class SidebarBottomHookBase extends UIHookBase {
  @override
  String get hookPointId => 'sidebar.bottom';  // ✅ 正确
  // ...
}

// StatusBarHookBase - 同样缺少 hookPointId 覆写！
abstract class StatusBarHookBase extends UIHookBase {
  @override
  Widget render(HookContext context) {
    final statusContext = StatusBarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderStatusBar(statusContext);
  }

  Widget renderStatusBar(StatusBarHookContext context);
}
```

**影响**:  
- 子类必须自行指定 `hookPointId`，增加出错概率
- 与其他专用基类的设计模式不一致
- 如果子类指定了错误的 `hookPointId`，Hook 会注册到错误的挂载点，导致 UI 不显示

**修复建议**:  
为两个基类添加 `hookPointId` 覆写：
```dart
abstract class SidebarHookBase extends UIHookBase {
  @override
  String get hookPointId => 'sidebar.top';  // 或 'sidebar'，取决于设计意图

  // ...
}

abstract class StatusBarHookBase extends UIHookBase {
  @override
  String get hookPointId => 'statusbar';

  // ...
}
```

---

## Bug 2: HookWrapperFactory.wrapNewHook() 异步状态转换竞态条件

**严重程度**: 高 (状态不一致/运行时错误)

**位置**: [hook_lifecycle.dart:241-257](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_lifecycle.dart#L241-L257)

**问题描述**:  
`wrapNewHook` 方法调用 `lifecycle.transitionTo()` 进行状态转换，但没有使用 `await` 等待转换完成。`transitionTo` 是异步方法，状态在 `await action()` 之后才更新。由于 `wrapNewHook` 是同步方法，返回 `HookWrapper` 时，`lifecycle._state` 仍然是 `HookState.uninitialized`，而不是预期的 `HookState.initialized`。

**问题代码**:
```dart
static HookWrapper wrapNewHook(
  UIHookBase hook, {
  PluginWrapper? parentPlugin,
}) {
  final lifecycle = HookLifecycleManager(hook.metadata.id);
  final order = _registrationCounter++;

  // 自动转换到 initialized 状态，使 Hook 可用
  lifecycle.transitionTo(HookState.initialized, () async {});  // 没有 await！

  return HookWrapper(
    hook,
    lifecycle,
    order,
    parentPlugin: parentPlugin,
  );
}
```

**执行流程分析**:
1. `lifecycle._state` 初始为 `HookState.uninitialized`
2. `transitionTo()` 被调用，开始同步执行
3. `canTransitionTo(HookState.initialized)` 检查通过
4. `await action()` 遇到第一个 await，执行权返回给调用者
5. `wrapNewHook` 返回 `HookWrapper`，此时 `lifecycle._state` 仍为 `uninitialized`
6. 微任务队列执行后，`_state` 才被设为 `initialized`

**影响**:  
- 返回的 `HookWrapper` 的 `lifecycle.isInitialized` 为 `false`
- `HookRegistry.registerHook()` 注册的 Hook 可能被认为未初始化
- 后续的 `onEnable()` 调用可能因状态检查失败而抛出 `StateError`（`uninitialized` 不能直接转到 `enabled`）
- 如果 `transitionTo` 中 `action` 抛出异常，异常不会被捕获

**修复建议**:  
方案1：将方法改为异步（影响调用链）
```dart
static Future<HookWrapper> wrapNewHook(
  UIHookBase hook, {
  PluginWrapper? parentPlugin,
}) async {
  final lifecycle = HookLifecycleManager(hook.metadata.id);
  final order = _registrationCounter++;

  await lifecycle.transitionTo(HookState.initialized, () async {});

  return HookWrapper(hook, lifecycle, order, parentPlugin: parentPlugin);
}
```

方案2：直接同步设置状态（推荐，因为 action 为空）
```dart
static HookWrapper wrapNewHook(
  UIHookBase hook, {
  PluginWrapper? parentPlugin,
}) {
  final lifecycle = HookLifecycleManager(hook.metadata.id);
  final order = _registrationCounter++;

  // 直接设置状态，避免异步竞态
  lifecycle._state = HookState.initialized;

  return HookWrapper(hook, lifecycle, order, parentPlugin: parentPlugin);
}
```

---

## Bug 3: HookRegistry.unregisterHook() 未调用 Hook 生命周期销毁方法

**严重程度**: 高 (资源泄漏)

**位置**: [hook_registry.dart:133-147](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_registry.dart#L133-L147)

**问题描述**:  
`unregisterHook` 方法只是简单地将 Hook 从列表中移除，没有调用 Hook 的 `onDisable()` 和 `onDispose()` 生命周期方法。根据 `UIHookBase` 的生命周期设计，如果 Hook 当前是启用状态，应该先调用 `onDisable()`，然后调用 `onDispose()` 来释放资源。

**问题代码**:
```dart
void unregisterHook(UIHookBase hook) {
  final hookPointId = hook.hookPointId;
  if (_hooks.containsKey(hookPointId)) {
    _hooks[hookPointId]!
        .removeWhere((wrapper) => wrapper.hook == hook);

    if (_hooks[hookPointId]!.isEmpty) {
      _hooks.remove(hookPointId);
    }
  }

  // 注销 Hook 的 API
  _apiRegistry.unregisterHookAPIs(hook.metadata.id);
  // ❌ 缺少：没有调用 onDisable() 和 onDispose()
  // ❌ 缺少：没有调用 notifyListeners()
}
```

**影响**:  
- Hook 持有的资源（如流订阅、定时器、控制器等）不会被释放
- 可能导致内存泄漏
- Hook 的 `onDisable()` 和 `onDispose()` 中的清理逻辑永远不会执行
- 与 Plugin 的卸载流程不一致（Plugin 卸载时会调用完整的生命周期）

**修复建议**:  
在注销 Hook 时正确调用生命周期方法：
```dart
void unregisterHook(UIHookBase hook) {
  final hookPointId = hook.hookPointId;
  if (_hooks.containsKey(hookPointId)) {
    final wrappers = _hooks[hookPointId]!;
    final targetWrapper = wrappers.cast<HookWrapper?>().firstWhere(
      (w) => w?.hook == hook,
      orElse: () => null,
    );

    if (targetWrapper != null) {
      // 按生命周期顺序调用销毁方法
      if (targetWrapper.isEnabled) {
        hook.onDisable();
        targetWrapper.lifecycle.transitionTo(HookState.disabled, () async {});
      }
      hook.onDispose();
      targetWrapper.lifecycle.transitionTo(HookState.disposed, () async {});

      wrappers.remove(targetWrapper);
    }

    if (wrappers.isEmpty) {
      _hooks.remove(hookPointId);
    }
  }

  _apiRegistry.unregisterHookAPIs(hook.metadata.id);
  notifyListeners();
}
```

---

## Bug 4: HookRegistry.unregisterHook() 和 unregisterPluginHooks() 未通知 UI 更新

**严重程度**: 中 (UI 不更新)

**位置**: [hook_registry.dart:133-147](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_registry.dart#L133-L147) / [hook_registry.dart:154-178](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_registry.dart#L154-L178)

**问题描述**:  
`HookRegistry` 继承了 `ChangeNotifier`，`registerHook()` 方法在注册后调用了 `notifyListeners()` 来通知 UI 更新。但是 `unregisterHook()` 和 `unregisterPluginHooks()` 方法在注销 Hook 后没有调用 `notifyListeners()`，导致 UI 不会响应 Hook 的注销。

**问题代码**:
```dart
// registerHook - ✅ 调用了 notifyListeners
void registerHook(UIHookBase hook, {PluginWrapper? parentPlugin}) {
  // ...
  notifyListeners();
}

// unregisterHook - ❌ 没有调用 notifyListeners
void unregisterHook(UIHookBase hook) {
  // ...
  _apiRegistry.unregisterHookAPIs(hook.metadata.id);
  // 缺少 notifyListeners()
}

// unregisterPluginHooks - ❌ 没有调用 notifyListeners
void unregisterPluginHooks(String pluginId) {
  // ...
  _log.info('Unregistered all hooks for plugin: $pluginId');
  // 缺少 notifyListeners()
}
```

**影响**:  
- Hook 注销后 UI 不会更新，已注销的 Hook 仍然显示在界面上
- Plugin 卸载后其 Hook 仍然可见，用户可能点击已失效的 UI 元素
- 与注册行为不一致，违反了最小惊讶原则

**修复建议**:  
在两个方法末尾添加 `notifyListeners()`：
```dart
void unregisterHook(UIHookBase hook) {
  // ...existing code...
  _apiRegistry.unregisterHookAPIs(hook.metadata.id);
  notifyListeners();
}

void unregisterPluginHooks(String pluginId) {
  // ...existing code...
  _log.info('Unregistered all hooks for plugin: $pluginId');
  notifyListeners();
}
```

---

## Bug 5: HookPriority.fromValue() 映射范围与实际枚举值严重不一致

**严重程度**: 中 (逻辑错误)

**位置**: [hook_priority.dart:128-134](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_priority.dart#L128-L134)

**问题描述**:  
`fromValue` 方法声称将整数值转换为对应的 `HookPriority` 枚举，但其范围判断与实际枚举值严重不一致，且完全忽略了所有自定义优先级（custom50、custom60、custom70、custom80、custom90、custom100、custom150、custom200、custom250、custom300）。

**问题代码**:
```dart
static HookPriority fromValue(int value) {
  if (value <= 0) return HookPriority.critical;     // critical.value = 0 ✅
  if (value <= 300) return HookPriority.high;        // high.value = 100 ❌ 301-700 映射到 medium
  if (value <= 700) return HookPriority.medium;      // medium.value = 800 ❌ 301-700 没有对应枚举
  if (value <= 900) return HookPriority.low;         // low.value = 900 ✅
  return HookPriority.decorative;                     // decorative.value = 1000 ✅
}
```

**不一致分析**:
| 输入值范围 | fromValue 返回 | 返回值的 .value | 差异 |
|-----------|---------------|----------------|------|
| 1-300 | high | 100 | 50→high(100), 200→high(100) 等，丢失精度 |
| 301-700 | medium | 800 | 301 映射到 800，差距巨大 |
| 701-900 | low | 900 | 701 映射到 900 |

**具体问题**:
1. `fromValue(50)` 返回 `high`（值100），但实际存在 `custom50`（值50）
2. `fromValue(300)` 返回 `high`（值100），但实际存在 `custom300`（值300）
3. `fromValue(500)` 返回 `medium`（值800），但没有任何枚举值在 301-700 范围内
4. 该方法完全无法还原任何自定义优先级

**影响**:  
- 旧系统迁移时优先级信息丢失
- `fromValue` 返回的枚举值与输入值不匹配
- 自定义优先级 Hook 的优先级可能被错误降级或升级

**修复建议**:  
方案1：精确匹配所有枚举值
```dart
static HookPriority fromValue(int value) {
  return HookPriority.values.firstWhere(
    (p) => p.value == value,
    orElse: () => _findClosest(value),
  );
}

static HookPriority _findClosest(int value) {
  if (value <= 0) return HookPriority.critical;
  if (value <= 50) return HookPriority.custom50;
  if (value <= 60) return HookPriority.custom60;
  if (value <= 70) return HookPriority.custom70;
  if (value <= 80) return HookPriority.custom80;
  if (value <= 90) return HookPriority.custom90;
  if (value <= 100) return HookPriority.high;
  if (value <= 150) return HookPriority.custom150;
  if (value <= 200) return HookPriority.custom200;
  if (value <= 250) return HookPriority.custom250;
  if (value <= 300) return HookPriority.custom300;
  if (value <= 800) return HookPriority.medium;
  if (value <= 900) return HookPriority.low;
  return HookPriority.decorative;
}
```

方案2：如果 fromValue 只是用于向后兼容，考虑废弃该方法并添加文档说明

---

## Bug 6: HookContext.get<T>() 对泛型集合类型的类型检查不可靠

**严重程度**: 中 (运行时类型错误)

**位置**: [hook_context.dart:128-131](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_context.dart#L128-L131)

**问题描述**:  
`get<T>()` 方法使用 `value is T` 进行类型检查，但 Dart 存在泛型类型擦除问题。对于泛型集合类型（如 `List<String>`、`Map<String, dynamic>`），`is` 检查在运行时不可靠。这导致多个上下文子类中的类型安全访问器可能返回错误类型的值。

**问题代码**:
```dart
T? get<T>(String key) {
  final value = data[key];
  return value is T ? value : null;  // 对泛型类型不可靠！
}
```

**受影响的代码位置**:
- [hook_context.dart:441](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_context.dart#L441): `List<String> get importFormats => get<List<String>>('importFormats') ?? [];`
- [hook_context.dart:444](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_context.dart#L444): `List<String> get exportFormats => get<List<String>>('exportFormats') ?? [];`
- [hook_context.dart:471](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_context.dart#L471): `Map<String, dynamic> get currentSettings => get<Map<String, dynamic>>('currentSettings') ?? {};`
- [hook_context.dart:499](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_context.dart#L499): `List<HelpItem> get helpItems => get<List<HelpItem>>('helpItems') ?? [];`

**复现场景**:
```dart
final context = ImportExportHookContext(
  importFormats: ['markdown', 'json'],  // 实际类型: List<String>
);

// data 中存储的是 List<String>，但 get<List<String>> 可能返回 null
// 因为 Dart 运行时中 ['markdown', 'json'] is List<String> 可能返回 false
// 实际类型可能是 List<dynamic>，导致类型检查失败
final formats = context.importFormats;  // 可能返回 [] 而非 ['markdown', 'json']
```

**影响**:  
- 泛型集合类型的 getter 可能返回默认值而非实际值
- 数据丢失但不会抛出异常，难以发现
- 影响导入导出功能、设置功能、帮助系统等

**修复建议**:  
对泛型集合类型使用更宽松的检查：
```dart
T? get<T>(String key) {
  final value = data[key];
  if (value == null) return null;

  // 对泛型集合类型使用宽松检查
  if (T == List<String> && value is List) {
    return List<String>.from(value) as T;
  }
  if (T == Map<String, dynamic> && value is Map) {
    return Map<String, dynamic>.from(value) as T;
  }
  if (T == List<HelpItem> && value is List) {
    return value as T;
  }

  return value is T ? value : null;
}
```

或者更通用的方案：
```dart
T? get<T>(String key) {
  final value = data[key];
  if (value == null) return null;
  if (value is T) return value;

  // 尝试通过 runtimeType 进行宽松匹配
  try {
    return value as T;
  } catch (_) {
    return null;
  }
}
```

---

## Bug 7: HookRegistry.unregisterPluginHooks() 中 removeWhere 谓词包含副作用

**严重程度**: 中 (异常安全性)

**位置**: [hook_registry.dart:160-168](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_registry.dart#L160-L168)

**问题描述**:  
`unregisterPluginHooks` 方法在 `removeWhere` 的谓词函数中调用了 `_apiRegistry.unregisterHookAPIs()`，这是一个有副作用的操作。`removeWhere` 的谓词应该只负责判断是否移除，不应包含副作用。如果 `unregisterHookAPIs` 抛出异常，会导致 `_hooks` 映射处于不一致状态（部分 Hook 已移除 API 但仍在列表中）。

**问题代码**:
```dart
void unregisterPluginHooks(String pluginId) {
  final hooksToRemove = <String>[];

  for (final entry in _hooks.entries) {
    final hookPointId = entry.key;
    final wrappers = entry.value
    ..removeWhere((wrapper) {
      if (wrapper.parentPlugin?.plugin.metadata.id == pluginId) {
        // ❌ 副作用在谓词中！
        _apiRegistry.unregisterHookAPIs(wrapper.hook.metadata.id);
        return true;
      }
      return false;
    });

    if (wrappers.isEmpty) {
      hooksToRemove.add(hookPointId);
    }
  }

  hooksToRemove.forEach(_hooks.remove);
  _log.info('Unregistered all hooks for plugin: $pluginId');
}
```

**影响**:  
- 如果 `unregisterHookAPIs` 抛出异常，`removeWhere` 会中断，导致部分 Hook 已注销 API 但仍保留在列表中
- 数据不一致：Hook 的 API 已注销但 Hook 本身仍在注册表中
- 违反了关注点分离原则

**修复建议**:  
将副作用移出谓词函数：
```dart
void unregisterPluginHooks(String pluginId) {
  final hooksToRemove = <String>[];
  final apisToUnregister = <String>[];

  for (final entry in _hooks.entries) {
    final hookPointId = entry.key;
    final wrappersToRemove = entry.value
        .where((wrapper) =>
            wrapper.parentPlugin?.plugin.metadata.id == pluginId)
        .toList();

    // 收集需要注销的 API
    for (final wrapper in wrappersToRemove) {
      apisToUnregister.add(wrapper.hook.metadata.id);
    }

    // 移除 Hook
    entry.value.removeWhere(
        (wrapper) => wrapper.parentPlugin?.plugin.metadata.id == pluginId);

    if (entry.value.isEmpty) {
      hooksToRemove.add(hookPointId);
    }
  }

  // 安全地注销 API
  for (final hookId in apisToUnregister) {
    _apiRegistry.unregisterHookAPIs(hookId);
  }

  // 移除空的 Hook 点
  hooksToRemove.forEach(_hooks.remove);

  _log.info('Unregistered all hooks for plugin: $pluginId');
  notifyListeners();
}
```

---

## Bug 8: HookDataSchema.validate() 类型检查对子类不兼容

**严重程度**: 中 (功能缺陷)

**位置**: [hook_context.dart:40-60](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_context.dart#L40-L60)

**问题描述**:  
`HookDataSchema.validate()` 方法使用 `value.runtimeType != type` 进行严格类型检查，这会导致子类实例无法通过验证。例如，如果 Schema 声明类型为 `HookContext`，传入 `MainToolbarHookContext`（子类）实例会验证失败。

**问题代码**:
```dart
String? validate(dynamic value) {
  if (required && value == null) {
    return 'Required value is missing';
  }

  if (value == null) {
    return null;
  }

  final valueType = value.runtimeType;

  if (valueType != type) {
    return 'Expected type $type, got $valueType';  // 子类实例会验证失败！
  }

  return null;
}
```

**复现场景**:
```dart
final schema = HookDataSchema(type: HookContext, required: true);
final context = MainToolbarHookContext();  // MainToolbarHookContext extends HookContext

final error = schema.validate(context);
// error = 'Expected type HookContext, got MainToolbarHookContext'
// ❌ 子类实例无法通过验证
```

**影响**:  
- 所有 HookContext 子类实例无法通过类型为 `HookContext` 的 Schema 验证
- 其他继承关系同样受影响（如 `Node` 的子类、`UIHookBase` 的子类等）
- 类型验证功能在实际使用中几乎不可用

**修复建议**:  
使用 `is` 检查替代 `runtimeType` 比较：
```dart
String? validate(dynamic value) {
  if (required && value == null) {
    return 'Required value is missing';
  }

  if (value == null) {
    return null;
  }

  // 使用 is 检查，支持子类
  // 注意：Dart 不支持 value is type（type 是变量），
  // 需要换一种方式
  // 方案：接受运行时限制，改为宽松检查
  return null;  // 暂时跳过类型检查，或使用其他验证策略
}
```

更实际的方案——提供严格模式和宽松模式：
```dart
String? validate(dynamic value, {bool strict = false}) {
  if (required && value == null) {
    return 'Required value is missing';
  }

  if (value == null) {
    return null;
  }

  if (strict) {
    if (value.runtimeType != type) {
      return 'Expected type $type, got $value.runtimeType';
    }
  }
  // 宽松模式：不检查类型（因为 Dart 的运行时类型检查限制）

  return null;
}
```

---

## Bug 9: GraphToolbarHookBase 使用了错误的上下文类型

**严重程度**: 低 (设计不一致)

**位置**: [hook_base.dart:392-411](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_base.dart#L392-L411)

**问题描述**:  
`GraphToolbarHookBase` 的 `hookPointId` 为 `'graph.toolbar'`，但在 `render()` 方法中创建的是 `MainToolbarHookContext` 而非图相关的上下文。其他专用基类都使用了与 `hookPointId` 匹配的上下文类型（如 `NodeContextMenuHookBase` 使用 `NodeContextMenuHookContext`）。

**问题代码**:
```dart
abstract class GraphToolbarHookBase extends UIHookBase {
  @override
  String get hookPointId => 'graph.toolbar';

  @override
  Widget render(HookContext context) {
    // ❌ 使用了 MainToolbarHookContext 而非图相关的上下文
    final toolbarContext = MainToolbarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderToolbar(toolbarContext);
  }

  Widget renderToolbar(MainToolbarHookContext context);
}
```

**影响**:  
- 上下文类型与 Hook 点不匹配，违反了类型安全设计
- `renderToolbar` 接收的是 `MainToolbarHookContext`，但实际是图工具栏场景
- 如果 `MainToolbarHookContext` 的特有属性（如 `showTitle`、`showSearch`）在图工具栏场景中不适用，可能导致逻辑错误

**修复建议**:  
创建专用的 `GraphToolbarHookContext`，或至少在文档中说明为何复用 `MainToolbarHookContext`：
```dart
// 方案1: 创建专用上下文
class GraphToolbarHookContext extends HookContext {
  GraphToolbarHookContext({
    Map<String, dynamic>? data,
    PluginContext? pluginContext,
    HookAPIRegistry? hookAPIRegistry,
    bool enableTypeValidation = false,
  }) : super(
         data ?? {},
         pluginContext: pluginContext,
         hookAPIRegistry: hookAPIRegistry,
         enableTypeValidation: enableTypeValidation,
       );

  // 图工具栏特有的属性
  bool get showZoomControls => get<bool>('showZoomControls') ?? true;
  bool get showLayoutButtons => get<bool>('showLayoutButtons') ?? true;
}

abstract class GraphToolbarHookBase extends UIHookBase {
  @override
  String get hookPointId => 'graph.toolbar';

  @override
  Widget render(HookContext context) {
    final toolbarContext = GraphToolbarHookContext(
      data: context.data,
      pluginContext: context.pluginContext,
      hookAPIRegistry: context.hookAPIRegistry,
    );
    return renderToolbar(toolbarContext);
  }

  Widget renderToolbar(GraphToolbarHookContext context);
}
```

---

## Bug 10: HookPointDefinition.validateContext() 对 null 值的验证逻辑有缺陷

**严重程度**: 低 (验证逻辑不完整)

**位置**: [hook_point_registry.dart:93-114](file:///d:/Projects/node_graph_notebook/lib/core/plugin/ui_hooks/hook_point_registry.dart#L93-L114)

**问题描述**:  
`validateContext` 方法在检查 `contextSchema` 时，如果值为 `null` 则跳过类型检查（只检查 key 是否存在）。但这意味着 `contextSchema` 无法声明"必需且类型必须匹配"的字段——null 值总是能通过验证（只要 key 存在）。

**问题代码**:
```dart
bool validateContext(Map<String, dynamic> contextData) {
  if (contextSchema == null) return true;

  for (final entry in contextSchema!.entries) {
    final key = entry.key;
    final expectedType = entry.value;

    if (!contextData.containsKey(key)) {
      _log.info('Missing required context key: $key');
      return false;
    }

    final value = contextData[key];
    if (value != null && value.runtimeType != expectedType) {
      // ❌ null 值总是跳过类型检查
      _log.warning('...');
      return false;
    }
  }

  return true;
}
```

**影响**:  
- `contextSchema` 无法验证必需字段的非空性
- 传入 `{ 'node': null }` 会通过验证，但后续使用 `node` 时会出错
- 与 `HookDataSchema` 的 `required` 字段设计不一致

**修复建议**:  
添加必需字段验证：
```dart
bool validateContext(Map<String, dynamic> contextData) {
  if (contextSchema == null) return true;

  for (final entry in contextSchema!.entries) {
    final key = entry.key;
    final expectedType = entry.value;

    if (!contextData.containsKey(key)) {
      _log.info('Missing required context key: $key');
      return false;
    }

    final value = contextData[key];
    // null 值也应进行类型检查（null 不是任何非 Nullable 类型的有效值）
    if (value == null) {
      _log.warning('Context key $key is null');
      return false;
    }

    if (value.runtimeType != expectedType) {
      _log.warning('Context key $key has wrong type: '
          'expected $expectedType, got ${value.runtimeType}');
      return false;
    }
  }

  return true;
}
```

---

## 总结

| Bug ID | 严重程度 | 文件 | 问题类型 |
|--------|----------|------|----------|
| Bug 1 | 高 | hook_base.dart | 功能失效/设计不一致 |
| Bug 2 | 高 | hook_lifecycle.dart | 状态不一致/竞态条件 |
| Bug 3 | 高 | hook_registry.dart | 资源泄漏 |
| Bug 4 | 中 | hook_registry.dart | UI 不更新 |
| Bug 5 | 中 | hook_priority.dart | 逻辑错误/映射不一致 |
| Bug 6 | 中 | hook_context.dart | 运行时类型错误 |
| Bug 7 | 中 | hook_registry.dart | 异常安全性 |
| Bug 8 | 中 | hook_context.dart | 功能缺陷 |
| Bug 9 | 低 | hook_base.dart | 设计不一致 |
| Bug 10 | 低 | hook_point_registry.dart | 验证逻辑不完整 |

**建议优先级**:  
1. **Bug 1、2、3** 应立即修复——它们会导致功能失效、状态不一致和资源泄漏
2. **Bug 4、5、6、7、8** 应尽快修复——它们可能导致 UI 不更新、逻辑错误和运行时异常
3. **Bug 9、10** 可以在代码清理时一并处理
