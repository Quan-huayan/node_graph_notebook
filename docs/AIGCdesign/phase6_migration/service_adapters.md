# 服务适配器设计文档

## 1. 概述

### 1.1 职责
服务适配器负责将现有的服务层迁移到新的 CQRS 架构，实现：
- 现有服务与新 Command/Query Bus 的桥接
- 渐进式迁移策略
- 向后兼容性保证
- 平滑的服务切换

### 1.2 目标
- **兼容性**: 保持现有 API 不变
- **渐进式**: 支持逐步迁移，不破坏现有功能
- **可测试性**: 适配器易于测试
- **性能**: 适配器开销最小化
- **可观测性**: 提供迁移进度监控

### 1.3 关键挑战
- **API 兼容**: 保持现有服务 API 签名不变
- **状态同步**: 旧服务与新系统的状态一致性
- **事务边界**: 跨服务的事务处理
- **错误映射**: 新旧错误格式的转换
- **性能影响**: 适配器层的性能开销

## 2. 架构设计

### 2.1 组件结构

```
ServiceAdapterLayer
    │
    ├── CommandServiceAdapter (Command 服务适配器)
    │   ├── adaptee (旧服务)
    │   ├── executeCommand() (执行 Command)
    │   └── mapResult() (结果映射)
    │
    ├── QueryServiceAdapter (Query 服务适配器)
    │   ├── adaptee (旧服务)
    │   ├── executeQuery() (执行 Query)
    │   └── mapResult() (结果映射)
    │
    ├── ServiceAdapterFactory (适配器工厂)
    │   ├── createNodeServiceAdapter()
    │   ├── createGraphServiceAdapter()
    │   └── createConverterServiceAdapter()
    │
    └── MigrationOrchestrator (迁移编排器)
        ├── migrationPlan (迁移计划)
        ├── migrateService() (迁移服务)
        └── rollback() (回滚)
```

### 2.2 接口定义

#### 服务适配器基类

```dart
/// 服务适配器基类
abstract class ServiceAdapter<TAdaptee> {
  /// 被适配的旧服务
  final TAdaptee adaptee;

  /// Command Bus
  final ICommandBus commandBus;

  /// Query Bus
  final IQueryBus queryBus;

  /// 适配器配置
  final AdapterConfig config;

  ServiceAdapter({
    required this.adaptee,
    required this.commandBus,
    required this.queryBus,
    required this.config,
  });

  /// 初始化适配器
  Future<void> initialize();

  /// 检查适配器是否启用
  bool get isEnabled => config.enabled;

  /// 检查是否应该使用新系统
  bool shouldUseNewSystem(String methodName);

  /// 记录迁移指标
  void recordMigrationMetric(String methodName, bool usedNewSystem);
}

/// 适配器配置
class AdapterConfig {
  /// 是否启用适配器
  final bool enabled;

  /// 迁移模式
  final MigrationMode mode;

  /// 新系统使用率（0-1），用于灰度发布
  final double newSystemUsageRate;

  /// 特定方法的新系统使用率
  final Map<String, double> methodUsageRates;

  /// 是否记录迁移指标
  final bool recordMetrics;

  AdapterConfig({
    this.enabled = true,
    this.mode = MigrationMode.shadow,
    this.newSystemUsageRate = 0.0,
    this.methodUsageRates = const {},
    this.recordMetrics = true,
  });

  /// 检查是否应该使用新系统
  bool shouldUseNewSystem([String? method]) {
    final usageRate = method != null
        ? (methodUsageRates[method] ?? newSystemUsageRate)
        : newSystemUsageRate;

    return Random().nextDouble() < usageRate;
  }
}

/// 迁移模式
enum MigrationMode {
  /// 影子模式：新旧系统都执行，但只返回旧系统结果
  shadow,

  /// 对比模式：新旧系统都执行，对比结果
  compare,

  /// 渐进式：按比例使用新系统
  gradual,

  /// 完全迁移：只使用新系统
  fullyMigrated,
}
```

#### NodeService 适配器

```dart
/// NodeService 适配器
class NodeServiceAdapter extends ServiceAdapter<NodeService> {
  NodeServiceAdapter({
    required super.adaptee,
    required super.commandBus,
    required super.queryBus,
    required super.config,
  });

  @override
  Future<void> initialize() async {
    // 初始化逻辑
  }

  /// 创建节点
  Future<Node> createNode(CreateNodeDto dto) async {
    if (!shouldUseNewSystem('createNode')) {
      // 使用旧服务
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

  /// 获取节点
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

  /// 更新节点
  Future<Node> updateNode(UpdateNodeDto dto) async {
    if (!shouldUseNewSystem('updateNode')) {
      return adaptee.updateNode(dto);
    }

    // 使用新系统
    final command = UpdateNodeCommand(
      id: dto.id,
      content: dto.content,
      position: dto.position,
      size: dto.size,
    );

    final result = await commandBus.execute(command);
    if (!result.isSuccess) {
      throw NodeUpdateException(result.error ?? '更新节点失败');
    }

    return result.data as Node;
  }

  /// 删除节点
  Future<void> deleteNode(String id) async {
    if (!shouldUseNewSystem('deleteNode')) {
      return adaptee.deleteNode(id);
    }

    // 使用新系统
    final command = DeleteNodeCommand(nodeId: id);
    final result = await commandBus.execute(command);

    if (!result.isSuccess) {
      throw NodeDeletionException(result.error ?? '删除节点失败');
    }
  }

  /// 获取多个节点
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

  /// 搜索节点
  Future<List<Node>> searchNodes(SearchCriteria criteria) async {
    if (!shouldUseNewSystem('searchNodes')) {
      return adaptee.searchNodes(criteria);
    }

    // 使用新系统
    final query = SearchNodesQuery(
      keyword: criteria.keyword,
      nodeTypes: criteria.types,
      tags: criteria.tags,
      limit: criteria.limit,
    );

    final result = await queryBus.execute(query);

    if (!result.isSuccess) {
      return [];
    }

    return result.data as List<Node>;
  }
}
```

#### GraphService 适配器

```dart
/// GraphService 适配器
class GraphServiceAdapter extends ServiceAdapter<GraphService> {
  GraphServiceAdapter({
    required super.adaptee,
    required super.commandBus,
    required super.queryBus,
    required super.config,
  });

  @override
  Future<void> initialize() async {
    // 初始化逻辑
  }

  /// 添加节点到图
  Future<void> addNodeToGraph(String graphId, String nodeId) async {
    if (!shouldUseNewSystem('addNodeToGraph')) {
      return adaptee.addNodeToGraph(graphId, nodeId);
    }

    // 使用新系统
    final command = AddNodeToGraphCommand(
      graphId: graphId,
      nodeId: nodeId,
    );

    final result = await commandBus.execute(command);

    if (!result.isSuccess) {
      throw GraphModificationException(result.error ?? '添加节点失败');
    }
  }

  /// 从图移除节点
  Future<void> removeNodeFromGraph(String graphId, String nodeId) async {
    if (!shouldUseNewSystem('removeNodeFromGraph')) {
      return adaptee.removeNodeFromGraph(graphId, nodeId);
    }

    // 使用新系统
    final command = RemoveNodeFromGraphCommand(
      graphId: graphId,
      nodeId: nodeId,
    );

    final result = await commandBus.execute(command);

    if (!result.isSuccess) {
      throw GraphModificationException(result.error ?? '移除节点失败');
    }
  }

  /// 获取图中的所有节点
  Future<List<String>> getGraphNodes(String graphId) async {
    if (!shouldUseNewSystem('getGraphNodes')) {
      return adaptee.getGraphNodes(graphId);
    }

    // 使用新系统
    final query = GetGraphNodesQuery(graphId: graphId);
    final result = await queryBus.execute(query);

    if (!result.isSuccess) {
      return [];
    }

    return result.data as List<String>;
  }

  /// 创建连接
  Future<Connection> createConnection(CreateConnectionDto dto) async {
    if (!shouldUseNewSystem('createConnection')) {
      return adaptee.createConnection(dto);
    }

    // 使用新系统
    final command = CreateConnectionCommand(
      sourceId: dto.sourceId,
      targetId: dto.targetId,
      graphId: dto.graphId,
      type: dto.type,
    );

    final result = await commandBus.execute(command);

    if (!result.isSuccess) {
      throw ConnectionCreationException(result.error ?? '创建连接失败');
    }

    return result.data as Connection;
  }

  /// 删除连接
  Future<void> deleteConnection(String connectionId) async {
    if (!shouldUseNewSystem('deleteConnection')) {
      return adaptee.deleteConnection(connectionId);
    }

    // 使用新系统
    final command = DeleteConnectionCommand(connectionId: connectionId);
    final result = await commandBus.execute(command);

    if (!result.isSuccess) {
      throw ConnectionDeletionException(result.error ?? '删除连接失败');
    }
  }
}
```

#### ConverterService 适配器

```dart
/// ConverterService 适配器
class ConverterServiceAdapter extends ServiceAdapter<ConverterService> {
  ConverterServiceAdapter({
    required super.adaptee,
    required super.commandBus,
    required super.queryBus,
    required super.config,
  });

  @override
  Future<void> initialize() async {
    // 初始化逻辑
  }

  /// 导出为 Markdown
  Future<String> exportToMarkdown(ExportRequest request) async {
    if (!shouldUseNewSystem('exportToMarkdown')) {
      return adaptee.exportToMarkdown(request);
    }

    // 使用新系统
    final query = ExportToMarkdownQuery(
      graphId: request.graphId,
      includeMetadata: request.includeMetadata,
    );

    final result = await queryBus.execute(query);

    if (!result.isSuccess) {
      throw ExportException(result.error ?? '导出失败');
    }

    return result.data as String;
  }

  /// 从 Markdown 导入
  Future<ImportResult> importFromMarkdown(
    String markdown,
    ImportOptions options,
  ) async {
    if (!shouldUseNewSystem('importFromMarkdown')) {
      return adaptee.importFromMarkdown(markdown, options);
    }

    // 使用新系统
    final command = ImportFromMarkdownCommand(
      markdown: markdown,
      updateExisting: options.updateExisting,
    );

    final result = await commandBus.execute(command);

    if (!result.isSuccess) {
      throw ImportException(result.error ?? '导入失败');
    }

    return result.data as ImportResult;
  }
}
```

### 2.3 适配器工厂

```dart
/// 服务适配器工厂
class ServiceAdapterFactory {
  final ICommandBus commandBus;
  final IQueryBus queryBus;
  final Map<String, AdapterConfig> configs;

  ServiceAdapterFactory({
    required this.commandBus,
    required this.queryBus,
    this.configs = const {},
  });

  /// 创建 NodeService 适配器
  NodeServiceAdapter createNodeServiceAdapter(NodeService service) {
    final config = configs['NodeService'] ??
        AdapterConfig(mode: MigrationMode.shadow);

    return NodeServiceAdapter(
      adaptee: service,
      commandBus: commandBus,
      queryBus: queryBus,
      config: config,
    );
  }

  /// 创建 GraphService 适配器
  GraphServiceAdapter createGraphServiceAdapter(GraphService service) {
    final config = configs['GraphService'] ??
        AdapterConfig(mode: MigrationMode.shadow);

    return GraphServiceAdapter(
      adaptee: service,
      commandBus: commandBus,
      queryBus: queryBus,
      config: config,
    );
  }

  /// 创建 ConverterService 适配器
  ConverterServiceAdapter createConverterServiceAdapter(
    ConverterService service,
  ) {
    final config = configs['ConverterService'] ??
        AdapterConfig(mode: MigrationMode.shadow);

    return ConverterServiceAdapter(
      adaptee: service,
      commandBus: commandBus,
      queryBus: queryBus,
      config: config,
    );
  }

  /// 批量创建适配器
  Map<Type, ServiceAdapter> createAllAdapters({
    required NodeService nodeService,
    required GraphService graphService,
    required ConverterService converterService,
  }) {
    return {
      NodeService: createNodeServiceAdapter(nodeService),
      GraphService: createGraphServiceAdapter(graphService),
      ConverterService: createConverterServiceAdapter(converterService),
    };
  }
}
```

## 3. 迁移编排

### 3.1 迁移计划

```dart
/// 迁移计划
class MigrationPlan {
  /// 迁移阶段
  final List<MigrationPhase> phases;

  /// 当前阶段索引
  int currentPhaseIndex = 0;

  MigrationPlan({required this.phases});

  /// 获取当前阶段
  MigrationPhase get currentPhase => phases[currentPhaseIndex];

  /// 进入下一阶段
  bool nextPhase() {
    if (currentPhaseIndex < phases.length - 1) {
      currentPhaseIndex++;
      return true;
    }
    return false;
  }

  /// 是否完成所有阶段
  bool get isCompleted => currentPhaseIndex >= phases.length - 1;
}

/// 迁移阶段
class MigrationPhase {
  /// 阶段名称
  final String name;

  /// 阶段描述
  final String description;

  /// 涉及的服务
  final List<Type> services;

  /// 迁移模式
  final MigrationMode mode;

  /// 新系统使用率
  final double newSystemUsageRate;

  /// 预期持续时间
  final Duration estimatedDuration;

  /// 成功标准
  final MigrationSuccessCriteria successCriteria;

  MigrationPhase({
    required this.name,
    required this.description,
    required this.services,
    required this.mode,
    this.newSystemUsageRate = 0.0,
    this.estimatedDuration = const Duration(days: 7),
    required this.successCriteria,
  });
}

/// 迁移成功标准
class MigrationSuccessCriteria {
  /// 最大错误率（0-1）
  final double maxErrorRate;

  /// 最小性能提升比例（0-1）
  final double minPerformanceImprovement;

  /// 最小运行时间
  final Duration minRunTime;

  MigrationSuccessCriteria({
    this.maxErrorRate = 0.01,
    this.minPerformanceImprovement = 0.0,
    this.minRunTime = const Duration(days: 3),
  });

  /// 检查是否满足成功标准
  bool check(MigrationMetrics metrics) {
    if (metrics.errorRate > maxErrorRate) {
      return false;
    }

    if (metrics.performanceImprovement < minPerformanceImprovement) {
      return false;
    }

    if (metrics.runTime < minRunTime) {
      return false;
    }

    return true;
  }
}
```

### 3.2 迁移编排器

```dart
/// 迁移编排器
class MigrationOrchestrator {
  final MigrationPlan plan;
  final ServiceAdapterFactory factory;
  final MigrationMetricsCollector metricsCollector;
  final Logger logger;

  MigrationOrchestrator({
    required this.plan,
    required this.factory,
    required this.metricsCollector,
    Logger? logger,
  }) : logger = logger ?? Logger('MigrationOrchestrator');

  /// 执行迁移
  Future<void> execute() async {
    logger.i('开始执行迁移计划');

    while (!plan.isCompleted) {
      final phase = plan.currentPhase;

      logger.i('执行阶段: ${phase.name}');

      try {
        await _executePhase(phase);

        // 检查是否满足成功标准
        final metrics = await metricsCollector.collectMetrics(phase);
        if (!phase.successCriteria.check(metrics)) {
          logger.w('阶段 ${phase.name} 未满足成功标准，继续当前阶段');
          // 继续当前阶段
          continue;
        }

        logger.i('阶段 ${phase.name} 完成');

        // 进入下一阶段
        if (!plan.nextPhase()) {
          logger.i('所有阶段完成');
          break;
        }
      } catch (e) {
        logger.e('阶段 ${phase.name} 执行失败: $e');
        // 回滚
        await rollback();
        rethrow;
      }
    }
  }

  /// 执行单个阶段
  Future<void> _executePhase(MigrationPhase phase) async {
    // 更新适配器配置
    for (final serviceType in phase.services) {
      final config = AdapterConfig(
        enabled: true,
        mode: phase.mode,
        newSystemUsageRate: phase.newSystemUsageRate,
        recordMetrics: true,
      );

      factory.configs[serviceType.toString()] = config;
    }

    // 等待稳定运行
    await Future.delayed(phase.estimatedDuration);
  }

  /// 回滚迁移
  Future<void> rollback() async {
    logger.w('开始回滚迁移');

    // 将所有适配器切换回旧系统
    for (final key in factory.configs.keys) {
      factory.configs[key] = AdapterConfig(
        enabled: true,
        mode: MigrationMode.shadow,
        newSystemUsageRate: 0.0,
        recordMetrics: true,
      );
    }

    logger.i('回滚完成');
  }
}
```

## 4. 性能考虑

### 4.1 概念性性能指标

| 指标 | 目标值 | 说明 |
|------|--------|------|
| 适配器开销 | < 0.1ms | 单次适配器调用的开销 |
| 迁移性能损失 | < 5% | 影子模式下的性能损失 |
| 完全迁移性能提升 | > 20% | 迁移完成后的性能提升 |

### 4.2 监控指标

```dart
/// 迁移指标收集器
class MigrationMetricsCollector {
  final Map<String, ServiceMigrationMetrics> _metrics = {};

  /// 收集指标
  Future<MigrationMetrics> collectMetrics(MigrationPhase phase) async {
    double totalErrorRate = 0.0;
    double totalPerformanceImprovement = 0.0;
    Duration totalRunTime = Duration.zero;

    for (final serviceType in phase.services) {
      final metrics = _metrics[serviceType.toString()];
      if (metrics != null) {
        totalErrorRate += metrics.errorRate;
        totalPerformanceImprovement += metrics.performanceImprovement;
        totalRunTime += metrics.runTime;
      }
    }

    final count = phase.services.length;

    return MigrationMetrics(
      errorRate: totalErrorRate / count,
      performanceImprovement: totalPerformanceImprovement / count,
      runTime: totalRunTime,
    );
  }

  /// 记录服务指标
  void recordServiceMetrics(
    String serviceName,
    ServiceMigrationMetrics metrics,
  ) {
    _metrics[serviceName] = metrics;
  }
}

/// 服务迁移指标
class ServiceMigrationMetrics {
  /// 错误率
  final double errorRate;

  /// 性能提升比例
  final double performanceImprovement;

  /// 运行时间
  final Duration runTime;

  ServiceMigrationMetrics({
    required this.errorRate,
    required this.performanceImprovement,
    required this.runTime,
  });
}

/// 迁移指标
class MigrationMetrics {
  /// 总体错误率
  final double errorRate;

  /// 总体性能提升
  final double performanceImprovement;

  /// 总运行时间
  final Duration runTime;

  MigrationMetrics({
    required this.errorRate,
    required this.performanceImprovement,
    required this.runTime,
  });
}
```

## 5. 关键文件清单

```
lib/core/migration/
├── adapters/
│   ├── service_adapter.dart        # 适配器基类
│   ├── node_service_adapter.dart   # NodeService 适配器
│   ├── graph_service_adapter.dart  # GraphService 适配器
│   └── converter_service_adapter.dart # ConverterService 适配器
├── factory/
│   └── adapter_factory.dart        # 适配器工厂
├── orchestration/
│   ├── migration_plan.dart         # 迁移计划
│   ├── migration_orchestrator.dart # 迁移编排器
│   └── migration_metrics.dart      # 迁移指标
└── config/
    └── adapter_config.dart         # 适配器配置
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
