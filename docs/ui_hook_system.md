# UI Hook 系统架构

**重构于 2026-03-17**

## 概述

UI Hook 系统允许在不修改核心代码的情况下在特定 hook 点扩展应用 UI。系统已经过重构,以改进关注点分离并简化开发。

## 主要变化

**旧系统(已弃用):**
- `UIHook` 继承 `Plugin`(导致继承混淆)
- 基于枚举的 hook 点(需要代码更改以添加新点)
- 魔术数字优先级(0-1000)
- 6 个插件生命周期方法需要实现

**新系统(当前):**
- `UIHookBase` 独立(更简单的生命周期)
- 基于字符串的 hook 点(支持动态注册)
- 语义优先级(critical、high、medium、low、decorative)
- 4 个 Hook 生命周期方法,全部可选
- Hook 间 API 通信

## 架构优势

**关注点分离:**
- **插件** 处理业务逻辑、服务和命令处理器
- **Hooks** 仅处理 UI 渲染和用户交互
- 不再有继承混淆

**简化的生命周期:**
- 旧: 6 个插件生命周期方法需要实现
- 新: 4 个 Hook 生命周期方法,全部可选

**动态 Hook 点:**
- 旧: 基于枚举的 hook 点(需要代码更改以添加新点)
- 新: 基于字符串的 hook 点(插件可以注册自定义 hook 点)

**语义优先级:**
- 旧: 魔术数字(0-1000),容易导致冲突
- 新: 语义枚举(critical、high、medium、low、decorative)

## Hook 生命周期

| 新系统(UIHookBase) | 目的 |
|-------------------|------|
| `onInit(context)` | 初始化(调用一次) |
| `onEnable()` | 激活(可以多次调用) |
| `onDisable()` | 停用(可以多次调用) |
| `onDispose()` | 清理(调用一次) |

## Hook 点

可用的 hook 点(基于字符串的 ID):

```dart
'main.toolbar'           // 主工具栏
'sidebar.top'            // 侧边栏顶部
'sidebar.bottom'         // 侧边栏底部
'context_menu.node'      // 节点上下文菜单
'context_menu.graph'     // 图上下文菜单
'status.bar'             // 状态栏
'settings'               // 设置页面
```

**动态注册:**
```dart
// 插件可以注册自定义 hook 点
hookRegistry.registerHookPoint(HookPointDefinition(
  id: 'my_custom.point',
  name: 'My Custom Hook Point',
  description: 'Custom extension point',
));
```

## 语义优先级

```dart
// 旧: 魔术数字
@override
int get priority => 100;  // 100 是什么意思?

// 新: 语义枚举
@override
HookPriority get priority => HookPriority.high;  // 意图清晰
```

**优先级级别:**
- `critical (0)` - 系统关键功能(保存、撤销/重做)
- `high (100)` - 重要功能(搜索、创建)
- `medium (500)` - 标准功能(默认)
- `low (800)` - 可选功能
- `decorative (1000)` - 装饰元素

## Hook 间 API 通信

**导出 API:**
```dart
class FormattingHook extends UIHookBase {
  @override
  Map<String, dynamic> exportAPIs() => {
    'formatting_api': TextFormattingAPI(),
    'validation_api': InputValidationAPI(),
  };
}
```

**使用其他 Hooks 的 API:**
```dart
class MyHook extends UIHookBase {
  @override
  Widget render(HookContext context) {
    // 获取另一个 hook 的 API
    final formattingAPI = context.getHookAPI<TextFormattingAPI>(
      'com.example.formatting_hook',
      'formatting_api',
    );

    return TextButton(
      onPressed: () => formattingAPI?.formatText(selectedText),
      child: Text('Format'),
    );
  }
}
```

## 创建 Hooks

### 步骤 1: 创建 Hook 类

```dart
// 1. 创建 Hook 类(继承 UIHookBase,不是 Plugin)
class MyToolbarHook extends MainToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'com.example.my_toolbar_hook',
    name: 'My Toolbar Hook',
    version: '1.0.0',
    description: 'My custom toolbar hook',
  );

  @override
  HookPriority get priority => HookPriority.high; // 语义优先级

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    // 返回 UI widget
    return IconButton(
      icon: Icon(Icons.my_icon),
      onPressed: () => _handleAction(context),
      tooltip: 'My Action',
    );
  }

  // 可选: 初始化 hook(调用一次)
  @override
  Future<void> onInit(HookContext context) async {
    // 缓存服务以提高性能
    _commandBus = context.pluginContext?.read<CommandBus>();
  }

  // 可选: 启用 hook(可以多次调用)
  @override
  Future<void> onEnable() async {
    // 激活 hook 功能
  }

  // 可选: 停用 hook(可以多次调用)
  @override
  Future<void> onDisable() async {
    // 停用 hook 功能
  }

  // 可选: 导出 API 供其他 hooks 使用
  @override
  Map<String, dynamic> exportAPIs() => {
    'my_api': MyAPI(),
  };

  CommandBus? _commandBus;
}
```

### 步骤 2: 在插件中注册 Hook

```dart
// 2. 创建提供 Hook 的插件类
class MyPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.myPlugin',
    name: 'My Plugin',
    version: '1.0.0',
    dependencies: [],
  );

  @override
  List<HookFactory> registerHooks() => [
    () => MyToolbarHook(), // 在这里注册 hooks
  ];

  @override
  List<ServiceBinding> registerServices() => [
    MyServiceBinding(), // 在这里注册服务
  ];

  @override
  Future<void> onLoad(PluginContext context) async {
    // 初始化插件
  }
}
```

## 可用的 Hook 基类

- `MainToolbarHookBase` - 主工具栏
- `NodeContextMenuHookBase` - 节点上下文菜单
- `GraphContextMenuHookBase` - 图上下文菜单
- `SidebarHookBase` - 侧边栏(所有位置)
- `SidebarBottomHookBase` - 仅侧边栏底部
- `StatusBarHookBase` - 状态栏
- `SettingsHookBase` - 设置页面
- `UIHookBase` - 通用 hook(扩展以用于自定义 hook 点)

## 从旧系统迁移

要从旧 UIHook 迁移到新 UIHookBase:

1. 将父类从 `UIHook` 更改为 `UIHookBase`(或特定的基类)
2. 更新 `metadata` 以使用 `HookMetadata` 而不是 `PluginMetadata`
3. 将 `HookPointId` 枚举替换为字符串 ID(或如果使用基类则删除)
4. 将 `int priority` 替换为 `HookPriority` 枚举
5. 将服务/命令注册从 Hook 移到 Plugin
6. 更新生命周期方法:
   - `onLoad()` → `onInit()`
   - `onUnload()` → `onDispose()`
7. 如果 hook 为其他 hooks 提供 API,则添加 `exportAPIs()`

有关详细的迁移信息,请参阅 `docs/ui_hook_migration_deprecations.md`。

## 关键文件

- `lib/core/plugin/ui_hooks/hook_base.dart` - UIHookBase 接口
- `lib/core/plugin/ui_hooks/hook_registry.dart` - Hook 注册表和生命周期管理
- `lib/core/plugin/ui_hooks/hook_point_registry.dart` - Hook 点定义
- `lib/core/plugin/ui_hooks/hook_api_registry.dart` - Hook 间 API 通信
- `lib/core/plugin/ui_hooks/hook_metadata.dart` - Hook 元数据
- `lib/core/plugin/ui_hooks/hook_priority.dart` - 语义优先级级别
- `lib/core/plugin/ui_hooks/hook_context.dart` - Hook 上下文类
- `lib/core/plugin/ui_hooks/hook_lifecycle.dart` - Hook 生命周期管理
- `lib/plugins/*/` - 示例实现

## 开发指南

- 使用 `UIHookBase` 进行 UI 扩展(不是 Plugin)
- 在 `onInit()` 中缓存服务以提高性能
- 使用语义优先级(`HookPriority.high` 等)而不是魔术数字
- 通过 `exportAPIs()` 导出 API 供其他 hooks 使用
- 通过 `context.getHookAPI<T>(hookId, apiName)` 访问其他 hooks 的 API
- 将业务逻辑排除在 hooks 之外 - 改用 CommandBus
- 对于服务: 通过 `registerServices()` 注册,不在 hooks 中
- 对于业务逻辑: 使用命令处理器,不是 hooks
