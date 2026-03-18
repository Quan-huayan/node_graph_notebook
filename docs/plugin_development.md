# 插件开发指南

本指南涵盖了 Node Graph Notebook 项目的详细插件开发。

## 插件类型

1. **服务插件** - 提供业务逻辑服务和命令处理器
2. **UI Hook 插件** - 通过 UIHookBase 在特定 hook 点扩展 UI
3. **中间件插件** - 在命令总线管道中拦截和处理命令

## 插件结构

每个插件都遵循这个一致的结构:

```
{plugin_name}/
├── command/        # 命令定义
├── handler/        # 命令处理器
├── service/        # 业务逻辑服务
├── bloc/           # 状态管理 BLoCs
├── ui/             # UI 组件
└── {plugin_name}_plugin.dart  # 主插件文件
```

## 创建插件

### 基本插件模板

```dart
class MyPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.myPlugin',
    name: 'My Plugin',
    version: '1.0.0',
    dependencies: [],
  );

  @override
  Future<void> onLoad(PluginContext context) async {
    // 初始化插件
    // 通过 context.read<T>() 访问服务
  }

  @override
  List<CommandHandlerBinding> registerCommandHandlers() {
    return [
      // 注册命令处理器
    ];
  }

  @override
  List<ServiceBinding> registerServices() {
    return [
      // 注册服务
    ];
  }

  @override
  List<HookFactory> registerHooks() {
    return [
      // 注册 UI hooks
    ];
  }
}
```

## 命令开发

### 创建命令

1. 在 `lib/plugins/{plugin_name}/command/` 中创建命令类
2. 在 `lib/plugins/{plugin_name}/handler/` 中创建处理器
3. 在插件的 `registerCommandHandlers()` 方法中注册处理器
4. 在 BLoC 中通过 `commandBus.dispatch(command)` 使用

### 命令示例

```dart
// 定义命令
class MyCommand extends Command<Result> {
  final String param;
  MyCommand(this.param);

  @override
  Future<void> execute(CommandContext context) async {
    // 命令验证/设置逻辑(如果需要)
    // 实际业务逻辑在 Handler 中
  }

  @override
  Future<void> undo(CommandContext context) async {
    // 撤销逻辑(可选 - 用于可撤销命令)
  }
}

// 定义处理器
class MyCommandHandler extends CommandHandler<MyCommand> {
  @override
  Future<CommandResult<Result>> execute(
    MyCommand command,
    CommandContext context,
  ) async {
    // 业务逻辑实现
    return CommandResult.success(result);
  }
}

// 在插件中注册
@override
List<CommandHandlerBinding> registerCommandHandlers() {
  return [
    CommandHandlerBinding(MyCommand, () => MyCommandHandler()),
  ];
}

// 在 BLoC 中使用
final result = await _commandBus.dispatch(MyCommand('value'));
```

### 命令执行流程

```
UI → BLoC → CommandBus.dispatch()
              ↓
         [中间件管道]
              ↓
         CommandHandler.execute()
              ↓
         Service/Repository
              ↓
         [发布事件]
              ↓
         CommandResult<T>
```

## 中间件开发

### 创建中间件

1. 创建实现 `CommandMiddleware` 的中间件类
2. 实现 `processBefore()` 和/或 `processAfter()` 方法
3. 在插件的 `registerMiddleware()` 方法中或在 `app.dart` 中注册

### 中间件示例

```dart
class MyMiddleware implements CommandMiddleware {
  @override
  Future<void> processBefore(
    Command command,
    CommandContext context,
  ) async {
    // 预处理逻辑
    // 可以验证、记录、转换命令
  }

  @override
  Future<void> processAfter(
    Command command,
    CommandContext context,
    CommandResult result,
  ) async {
    // 后处理逻辑
    // 可以审计、清理、触发副作用
  }
}
```

## 服务开发

### 服务绑定

```dart
class MyServiceBinding extends ServiceBinding<MyService> {
  @override
  bool get isLazy => true; // 可选: 延迟加载

  @override
  MyService createService(ServiceResolver resolver) {
    return MyServiceImpl(
      settingsService: resolver.get<SettingsService>(),
      nodeRepository: resolver.get<NodeRepository>(),
    );
  }
}
```

### 注册服务

```dart
@override
List<ServiceBinding> registerServices() {
  return [
    MyServiceBinding(),
  ];
}
```

### 在插件中访问服务

```dart
@override
Future<void> onLoad(PluginContext context) async {
  // 访问由此插件注册的服务
  final myService = context.read<MyService>();
  myService.initialize();
}
```

## 插件依赖

### 声明依赖

```dart
@override
PluginMetadata get metadata => const PluginMetadata(
  id: 'com.example.myPlugin',
  name: 'My Plugin',
  version: '1.0.0',
  dependencies: [
    'com.example.otherPlugin',  // 必需插件
  ],
);
```

### 依赖解析

- 插件根据依赖关系加载(拓扑排序)
- 被依赖的插件在依赖它的插件之前加载
- 内置插件在应用启动时通过 `BuiltinPluginLoader` 加载
- 插件加载在应用 UI 显示之前完成

## 插件生命周期

1. **注册** - 插件工厂注册到 PluginDiscoverer
2. **发现** - PluginDiscoverer 实例化插件并读取元数据
3. **依赖解析** - DependencyResolver 确定加载顺序
4. **加载** - PluginManager.loadPlugin() 调用 plugin.onLoad(context)
5. **启用** - PluginManager.enablePlugin() 调用 plugin.onEnable()
6. **禁用** - PluginManager.disablePlugin() 调用 plugin.onDisable()
7. **卸载** - PluginManager.unloadPlugin() 调用 plugin.onUnload()

## API 导出

插件可以导出 API 用于插件间通信:

```dart
@override
Map<String, dynamic> exportAPIs() => {
  'my_api': MyAPI(),
  'another_api': AnotherAPI(),
};
```

访问其他插件的 API:

```dart
final api = context.getPluginAPI<MyAPI>('com.example.otherPlugin', 'my_api');
```

## 最佳实践

1. **始终定义依赖** - 如果你的插件依赖其他插件,在元数据中声明
2. **使用 `PluginContext`** - 访问系统 API (CommandBus、EventBus、Repositories)
3. **实现适当的清理** - 在 `onUnload()` 中避免内存泄漏
4. **导出 API** - 通过 `exportAPIs()` 用于插件间通信
5. **对于 UI 扩展**: 创建 UIHookBase 子类,通过 `registerHooks()` 注册
6. **对于服务**: 通过 `registerServices()` 注册,不在 hooks 中
7. **对于业务逻辑**: 使用命令处理器,不是 hooks

## 关键插件文件

- `lib/core/plugin/plugin.dart` - 基础 Plugin 接口和生命周期
- `lib/core/plugin/plugin_manager.dart` - 插件生命周期管理
- `lib/core/plugin/plugin_discoverer.dart` - 插件发现和实例化
- `lib/core/plugin/dependency_resolver.dart` - 依赖解析
- `lib/core/plugin/builtin_plugin_loader.dart` - 内置插件加载器
- `lib/plugins/` - 内置插件实现

## 统一依赖注入

应用使用 **ServiceRegistry + DynamicProviderWidget** 进行统一依赖注入。

**优点:**
- 所有依赖的单一真实来源
- 插件可以在初始化期间访问自己的服务
- 动态插件加载而不破坏 Provider 树
- 自动内存管理(插件卸载时释放服务)
- 通过延迟加载进行性能优化
- 零破坏性更改(完全向后兼容)

**用法:**

```dart
// 1. 在 app.dart 中创建 ServiceRegistry
_serviceRegistry = ServiceRegistry(
  coreDependencies: {
    NodeRepository: _nodeRepository,
    GraphRepository: _graphRepository,
    CommandBus: _commandBus,
    AppEventBus: _eventBus,
  },
);

// 2. 插件现在可以在 onLoad() 中访问自己的服务
class MyPlugin extends Plugin {
  @override
  List<ServiceBinding> registerServices() {
    return [MyServiceBinding()];
  }

  @override
  Future<void> onLoad(PluginContext context) async {
    // 现在可以工作! PluginContext 可以解析
    // 由同一插件注册的服务
    final myService = context.read<MyService>();
    myService.initialize();
  }
}
```

## 延迟加载支持

```dart
class AIServiceBinding extends ServiceBinding<AIService> {
  @override
  bool get isLazy => true; // 仅在首次请求时实例化

  @override
  AIService createService(ServiceResolver resolver) {
    return AIServiceImpl(
      settingsService: resolver.get<SettingsService>(),
    );
  }
}
```

## 插件示例

### Graph 插件

位于 `lib/plugins/graph/`:
- 核心节点和图管理
- Flame 引擎集成用于可视化
- 节点操作(创建、更新、删除、移动、调整大小)
- 图操作(连接、断开、加载、保存)

### AI 插件

位于 `lib/plugins/ai/`:
- AI 集成功能
- 节点分析能力
- AI 驱动的建议

### Editor 插件

位于 `lib/plugins/editor/`:
- 文本编辑功能
- Markdown 支持
- 富文本编辑

### Search 插件

位于 `lib/plugins/search/`:
- 节点搜索功能
- 搜索预设和过滤器

### Layout 插件

位于 `lib/plugins/layout/`:
- 图布局算法
- 自动定位

### Converter 插件

位于 `lib/plugins/converter/`:
- 导入/导出功能
- 格式转换

### Settings 插件

位于 `lib/plugins/settings/`:
- 应用设置管理
- 主题自定义
