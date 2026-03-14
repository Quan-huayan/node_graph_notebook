# UI 适配设计文档

## 1. 概述

### 1.1 职责
UI 适配层负责将现有的 UI 层平滑迁移到新架构，实现：
- 保持现有 UI 代码不变
- 透明地使用新的 Command/Query 系统
- 渐进式替换 UI 组件
- 提供迁移工具和指导

### 1.2 目标
- **零破坏**: 现有 UI 代码无需修改
- **透明性**: UI 层无感知底层架构变化
- **渐进式**: 逐步迁移 UI 组件
- **类型安全**: 保持编译时类型检查
- **性能**: 最小化适配层开销

### 1.3 关键挑战
- **API 兼容**: 保持现有 Service/BLoC API
- **状态同步**: 确保状态更新的一致性
- **事件处理**: 正确转发 UI 事件
- **生命周期**: 管理 UI 组件的生命周期
- **测试**: 保证 UI 测试的有效性

## 2. 架构设计

### 2.1 组件结构

```
UIAdaptationLayer
    │
    ├── ProviderBridge (Provider 桥接)
    │   ├── watch() (监听状态)
    │   ├── read() (读取服务)
    │   └── select() (选择属性)
    │
    ├── BlocBridge (BLoC 桥接)
    │   ├── watchBloc() (监听 BLoC)
    │   ├── addEvent() (添加事件)
    │   └── getState() (获取状态)
    │
    ├── ServiceProxy (服务代理)
    │   ├── NodeServiceProxy
    │   ├── GraphServiceProxy
    │   └── ConverterServiceProxy
    │
    └── MigrationHelper (迁移辅助工具)
        ├── analyzeDependencies() (分析依赖)
        ├── generateMigrationCode() (生成迁移代码)
        └── verifyMigration() (验证迁移)
```

### 2.2 接口定义

#### Provider 桥接

```dart
/// Provider 桥接器
class ProviderBridge {
  /// Command Bus
  final ICommandBus commandBus;

  /// Query Bus
  final IQueryBus queryBus;

  /// 服务代理映射
  final Map<Type, ServiceProxy> _proxies;

  ProviderBridge({
    required this.commandBus,
    required this.queryBus,
    required Map<Type, ServiceProxy> proxies,
  }) : _proxies = proxies;

  /// 监听状态（替代 context.watch<T>()）
  T watch<T>(BuildContext context) {
    // 检查是否是 BLoC
    if (T is BlocBase) {
      return _watchBloc<T>(context);
    }

    // 检查是否是 Service
    if (_proxies.containsKey(T)) {
      final proxy = _proxies[T] as T;
      return proxy;
    }

    // 使用原有 Provider
    return context.watch<T>();
  }

  /// 读取服务（替代 context.read<T>()）
  T read<T>(BuildContext context) {
    // 检查是否是 BLoC
    if (T is BlocBase) {
      return _readBloc<T>(context);
    }

    // 检查是否是 Service
    if (_proxies.containsKey(T)) {
      final proxy = _proxies[T] as T;
      return proxy;
    }

    // 使用原有 Provider
    return context.read<T>();
  }

  /// 选择属性（替代 context.select<T, R>()）
  R select<T, R>(BuildContext context, R Function(T) selector) {
    final value = watch<T>(context);
    return selector(value);
  }

  T _watchBloc<T>(BuildContext context) {
    // 监听 BLoC 状态
    return context.watch<T>();
  }

  T _readBloc<T>(BuildContext context) {
    // 读取 BLoC（不监听）
    return context.read<T>();
  }
}
```

#### BLoC 桥接

```dart
/// BLoC 桥接器
class BlocBridge {
  final CommandBus commandBus;
  final QueryBus queryBus;
  final Map<Type, BlocAdapter> _adapters;

  BlocBridge({
    required this.commandBus,
    required this.queryBus,
    required Map<Type, BlocAdapter> adapters,
  }) : _adapters = adapters;

  /// 监听 BLoC 状态
  TState watch<TEvent, TState>(BuildContext context) {
    return context.watch<BlocBase<TState>>().state as TState;
  }

  /// 添加事件到 BLoC
  Future<void> addEvent<TEvent>(
    BuildContext context,
    TEvent event,
  ) async {
    final bloc = context.read<BlocBase>();

    // 检查是否有适配器
    final adapter = _adapters[bloc.runtimeType];
    if (adapter != null) {
      // 使用适配器处理
      final currentState = bloc.state;
      final newState = await adapter.handleEvent(event, currentState);
      if (newState != null && bloc is StatefulBloc) {
        (bloc as StatefulBloc).emit(newState);
      }
    } else {
      // 直接添加事件
      bloc.add(event);
    }
  }

  /// 获取 BLoC 状态
  TState getState<TEvent, TState>(BuildContext context) {
    return context.read<BlocBase<TState>>().state;
  }
}

/// 可发射状态的 BLoC 接口
abstract class StatefulBloc<TState> extends BlocBase<TState> {
  void emit(TState state);
}
```

#### 服务代理

```dart
/// 服务代理基类
abstract class ServiceProxy<T> {
  /// 被代理的服务
  final T adaptee;

  /// Command Bus
  final ICommandBus commandBus;

  /// Query Bus
  final IQueryBus queryBus;

  ServiceProxy({
    required this.adaptee,
    required this.commandBus,
    required this.queryBus,
  });

  /// 是否使用新系统
  bool shouldUseNewSystem(String methodName);

  /// 代理配置
  static ProxyConfig config = ProxyConfig();
}

/// 代理配置
class ProxyConfig {
  /// 是否启用代理
  bool enabled = true;

  /// 新系统使用率
  double newSystemUsageRate = 0.0;

  /// 特定方法的新系统使用率
  Map<String, double> methodUsageRates = {};

  /// 检查是否应该使用新系统
  bool shouldUseNewSystem([String? method]) {
    final usageRate = method != null
        ? (methodUsageRates[method] ?? newSystemUsageRate)
        : newSystemUsageRate;

    return Random().nextDouble() < usageRate;
  }
}

/// NodeService 代理
class NodeServiceProxy extends ServiceProxy<NodeService> implements NodeService {
  NodeServiceProxy({
    required super.adaptee,
    required super.commandBus,
    required super.queryBus,
  });

  @override
  bool shouldUseNewSystem(String methodName) {
    return ProxyConfig.config.shouldUseNewSystem(methodName);
  }

  @override
  Future<Node> createNode(CreateNodeDto dto) async {
    if (!shouldUseNewSystem('createNode')) {
      return adaptee.createNode(dto);
    }

    // 使用新系统
    final command = CreateNodeCommand(
      id: dto.id,
      type: dto.type,
      content: dto.content,
      parentId: dto.parentId,
    );

    final result = await commandBus.execute(command);
    if (!result.isSuccess) {
      throw NodeCreationException(result.error ?? '创建节点失败');
    }

    return result.data as Node;
  }

  @override
  Future<Node?> getNode(String id) async {
    if (!shouldUseNewSystem('getNode')) {
      return adaptee.getNode(id);
    }

    // 使用新系统
    final query = GetNodeQuery(nodeId: id);
    final result = await queryBus.execute(query);

    if (!result.isSuccess) {
      return null;
    }

    return result.data as Node?;
  }

  @override
  Future<List<Node>> getNodes(List<String> ids) async {
    if (!shouldUseNewSystem('getNodes')) {
      return adaptee.getNodes(ids);
    }

    // 使用新系统
    final query = GetNodesQuery(nodeIds: ids);
    final result = await queryBus.execute(query);

    if (!result.isSuccess) {
      return [];
    }

    return result.data as List<Node>;
  }

  // ... 其他方法
}
```

### 2.3 UI 组件适配

#### Widget 扩展方法

```dart
/// BuildContext 扩展方法
extension BuildContextExtension on BuildContext {
  /// 监听状态（桥接版本）
  T watchBridge<T>() {
    final bridge = read<ProviderBridge>();
    return bridge.watch<T>(this);
  }

  /// 读取服务（桥接版本）
  T readBridge<T>() {
    final bridge = read<ProviderBridge>();
    return bridge.read<T>(this);
  }

  /// 选择属性（桥接版本）
  R selectBridge<T, R>(R Function(T) selector) {
    final bridge = read<ProviderBridge>();
    return bridge.select<T, R>(this, selector);
  }

  /// 监听 BLoC 状态（桥接版本）
  TState watchBloc<TEvent, TState>() {
    final bridge = read<BlocBridge>();
    return bridge.watch<TEvent, TState>(this);
  }

  /// 添加 BLoC 事件（桥接版本）
  Future<void> addBlocEvent<TEvent>(TEvent event) async {
    final bridge = read<BlocBridge>();
    return bridge.addEvent<TEvent>(this, event);
  }
}
```

#### 示例：使用桥接的 UI 组件

```dart
/// 节点列表组件（使用桥接）
class NodeListWidget extends StatelessWidget {
  const NodeListWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用桥接监听 NodeBloc 状态
    final state = context.watchBloc<NodeEvent, NodeState>();

    switch (state.status) {
      case NodeStatus.loading:
        return const CircularProgressIndicator();

      case NodeStatus.loaded:
        return ListView.builder(
          itemCount: state.nodes.length,
          itemBuilder: (context, index) {
            final node = state.nodes.values.elementAt(index);
            return NodeTile(node: node);
          },
        );

      case NodeStatus.error:
        return Text('错误: ${state.error}');

      default:
        return const SizedBox.shrink();
    }
  }
}

/// 节点详情组件（使用服务代理）
class NodeDetailWidget extends StatelessWidget {
  final String nodeId;

  const NodeDetailWidget({
    super.key,
    required this.nodeId,
  });

  @override
  Widget build(BuildContext context) {
    // 使用桥接读取 NodeService
    final nodeService = context.readBridge<NodeService>();

    return FutureBuilder<Node?>(
      future: nodeService.getNode(nodeId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final node = snapshot.data;
        if (node == null) {
          return const Text('节点不存在');
        }

        return Column(
          children: [
            Text(node.type),
            Text(node.content),
            // ... 其他节点信息
          ],
        );
      },
    );
  }
}

/// 创建节点按钮（使用 BLoC 事件）
class CreateNodeButton extends StatelessWidget {
  const CreateNodeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _handleCreateNode(context),
      child: const Text('创建节点'),
    );
  }

  Future<void> _handleCreateNode(BuildContext context) async {
    // 使用桥接添加事件
    await context.addBlocEvent<NodeEvent>(
      CreateNodeEvent(
        id: uuid.v4(),
        type: 'concept',
        content: '新节点',
      ),
    );
  }
}
```

## 3. 迁移策略

### 3.1 渐进式迁移

```dart
/// 迁移阶段
enum UIMigrationPhase {
  /// 阶段 0: 使用原有架构
  legacy,

  /// 阶段 1: 启用代理，但使用率 0%
  proxyEnabled,

  /// 阶段 2: 逐步提高新系统使用率（10% -> 50% -> 100%）
  gradualMigration,

  /// 阶段 3: 完全使用新系统
  fullyMigrated,
}

/// UI 迁移管理器
class UIMigrationManager {
  /// 当前迁移阶段
  UIMigrationPhase currentPhase = UIMigrationPhase.legacy;

  /// 新系统使用率
  double newSystemUsageRate = 0.0;

  /// 进入下一阶段
  void nextPhase() {
    switch (currentPhase) {
      case UIMigrationPhase.legacy:
        currentPhase = UIMigrationPhase.proxyEnabled;
        newSystemUsageRate = 0.0;
        break;

      case UIMigrationPhase.proxyEnabled:
        currentPhase = UIMigrationPhase.gradualMigration;
        newSystemUsageRate = 0.1;
        break;

      case UIMigrationPhase.gradualMigration:
        if (newSystemUsageRate < 1.0) {
          newSystemUsageRate = (newSystemUsageRate + 0.1).clamp(0.0, 1.0);
        } else {
          currentPhase = UIMigrationPhase.fullyMigrated;
        }
        break;

      case UIMigrationPhase.fullyMigrated:
        // 已经完成
        break;
    }

    // 更新代理配置
    _updateProxyConfig();
  }

  /// 更新代理配置
  void _updateProxyConfig() {
    ProxyConfig.config.newSystemUsageRate = newSystemUsageRate;
  }

  /// 是否应该使用新系统
  bool shouldUseNewSystem() {
    return currentPhase != UIMigrationPhase.legacy &&
        ProxyConfig.config.shouldUseNewSystem();
  }
}
```

### 3.2 组件级迁移

```dart
/// 组件迁移标记
class MigrationMarker {
  /// 组件名称
  final String componentName;

  /// 是否已迁移
  final bool isMigrated;

  /// 迁移日期
  final DateTime? migratedDate;

  MigrationMarker({
    required this.componentName,
    this.isMigrated = false,
    this.migratedDate,
  });
}

/// 组件迁移跟踪器
class ComponentMigrationTracker {
  final Map<String, MigrationMarker> _markers = {};

  /// 标记组件已迁移
  void markMigrated(String componentName) {
    _markers[componentName] = MigrationMarker(
      componentName: componentName,
      isMigrated: true,
      migratedDate: DateTime.now(),
    );
  }

  /// 检查组件是否已迁移
  bool isMigrated(String componentName) {
    return _markers[componentName]?.isMigrated ?? false;
  }

  /// 获取迁移进度
  MigrationProgress getProgress() {
    final total = _markers.length;
    final migrated = _markers.values.where((m) => m.isMigrated).length;

    return MigrationProgress(
      total: total,
      migrated: migrated,
      percentage: total > 0 ? migrated / total : 0.0,
    );
  }
}

/// 迁移进度
class MigrationProgress {
  final int total;
  final int migrated;
  final double percentage;

  MigrationProgress({
    required this.total,
    required this.migrated,
    required this.percentage,
  });
}
```

## 4. 迁移辅助工具

### 4.1 依赖分析工具

```dart
/// UI 依赖分析器
class UIDependencyAnalyzer {
  /// 分析 UI 组件的依赖
  Future<ComponentDependencies> analyze(String componentPath) async {
    final file = File(componentPath);
    final content = await file.readAsString();

    // 解析依赖
    final services = _extractServices(content);
    final blocs = _extractBlocs(content);
    final providers = _extractProviders(content);

    return ComponentDependencies(
      services: services,
      blocs: blocs,
      providers: providers,
    );
  }

  List<String> _extractServices(String content) {
    // 提取服务依赖
    final regex = RegExp(r'context\.read<(\w+Service)\(\)');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)!).toList();
  }

  List<String> _extractBlocs(String content) {
    // 提取 BLoC 依赖
    final regex = RegExp(r'context\.watch<(\w+Bloc)\(\)');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)!).toList();
  }

  List<String> _extractProviders(String content) {
    // 提取 Provider 依赖
    final regex = RegExp(r'context\.select<(\w+),');
    final matches = regex.allMatches(content);
    return matches.map((m) => m.group(1)!).toList();
  }
}

/// 组件依赖
class ComponentDependencies {
  final List<String> services;
  final List<String> blocs;
  final List<String> providers;

  ComponentDependencies({
    required this.services,
    required this.blocs,
    required this.providers,
  });
}
```

### 4.2 迁移代码生成器

```dart
/// 迁移代码生成器
class MigrationCodeGenerator {
  /// 生成迁移代码
  Future<String> generate(
    String componentPath,
    ComponentDependencies dependencies,
  ) async {
    final file = File(componentPath);
    final content = await file.readAsString();

    // 生成导入语句
    final imports = _generateImports(dependencies);

    // 生成桥接代码
    final bridgeCode = _generateBridgeCode(dependencies);

    // 替换原有调用
    final migratedContent = _replaceCalls(content);

    return '''
$imports

$bridgeCode

$migratedContent
''';
  }

  String _generateImports(ComponentDependencies dependencies) {
    final imports = <String>[];

    imports.add("import 'package:provider/provider.dart';");
    imports.add("import 'package:flutter_bloc/flutter_bloc.dart';");

    if (dependencies.services.isNotEmpty) {
      imports.add("import 'package:app/core/migration/ui/service_proxy.dart';");
    }

    if (dependencies.blocs.isNotEmpty) {
      imports.add("import 'package:app/core/migration/ui/bloc_bridge.dart';");
    }

    return imports.join('\n');
  }

  String _generateBridgeCode(ComponentDependencies dependencies) {
    // 生成桥接初始化代码
    return '''
// 初始化桥接
final providerBridge = ProviderBridge(
  commandBus: context.read<ICommandBus>(),
  queryBus: context.read<IQueryBus>(),
  proxies: {},
);

final blocBridge = BlocBridge(
  commandBus: context.read<ICommandBus>(),
  queryBus: context.read<IQueryBus>(),
  adapters: {},
);
''';
  }

  String _replaceCalls(String content) {
    // 替换 context.read 为 context.readBridge
    var migrated = content.replaceAll(
      RegExp(r'context\.read<(\w+)>'),
      'context.readBridge<\1>',
    );

    // 替换 context.watch 为 context.watchBridge
    migrated = migrated.replaceAll(
      RegExp(r'context\.watch<(\w+)>'),
      'context.watchBridge<\1>',
    );

    // 替换 context.select 为 context.selectBridge
    migrated = migrated.replaceAll(
      RegExp(r'context\.select<(\w+),\s*(\w+)>'),
      'context.selectBridge<\1, \2>',
    );

    return migrated;
  }
}
```

## 5. 性能考虑

### 5.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 桥接开销 | < 0.1ms | 桥接层的平均调用开销 |
| UI 渲染延迟 | 无影响 | 桥接不应影响 UI 渲染 |
| 状态更新延迟 | < 1ms | 状态同步的延迟 |

### 5.2 优化策略

1. **延迟初始化**:
   - 按需初始化桥接组件
   - 避免启动时的性能开销

2. **缓存**:
   - 缓存服务代理实例
   - 缓存 BLoC 适配器

3. **批量更新**:
   - 批量处理状态更新
   - 减少 rebuild 次数

## 6. 关键文件清单

```
lib/core/migration/ui/
├── bridges/
│   ├── provider_bridge.dart       # Provider 桥接器
│   ├── bloc_bridge.dart          # BLoC 桥接器
│   └── service_proxy.dart        # 服务代理
├── extensions/
│   └── context_extension.dart    # BuildContext 扩展
├── managers/
│   ├── migration_manager.dart    # 迁移管理器
│   └── component_tracker.dart    # 组件迁移跟踪器
├── tools/
│   ├── dependency_analyzer.dart  # 依赖分析工具
│   └── code_generator.dart       # 代码生成器
└── guides/
    ├── migration_guide.md        # 迁移指南
    └── best_practices.md         # 最佳实践
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
