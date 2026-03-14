# 物化视图 (Materialized Views) 设计文档

## 概述

### 职责

物化视图是预先计算并存储的查询结果，用于优化复杂和频繁执行的查询。负责：

- **预计算**：提前执行复杂查询并存储结果
- **视图维护**：保持物化视图与源数据的一致性
- **增量更新**：仅更新变化的部分，避免完全重建
- **查询路由**：自动将查询路由到物化视图（如果可用）
- **生命周期管理**：管理物化视图的创建、更新和删除

### 目标

1. **查询加速**：将复杂查询的响应时间从秒级降低到毫秒级
2. **资源优化**：减少重复计算，节省 CPU 和 I/O 资源
3. **自动维护**：自动检测数据变化并更新相关视图
4. **灵活策略**：支持不同的刷新策略（实时、定时、按需）
5. **空间效率**：在存储成本和查询性能之间找到平衡

### 关键挑战

1. **刷新策略**：何时刷新视图以保持数据新鲜度
2. **增量更新**：如何高效地增量更新视图而不是完全重建
3. **依赖管理**：如何管理视图之间的依赖关系
4. **存储成本**：如何控制物化视图的存储开销
5. **一致性保证**：如何在更新过程中保证数据一致性

## 架构设计

### 组件结构

```
MaterializedView
├── ViewDefinition                  # 视图定义
├── ViewRefresher                   # 视图刷新器
├── ViewValidator                   # 视图验证器
├── ViewDependencyManager           # 依赖管理器
└── ViewRepository                  # 视图仓储

ViewDefinition
├── query                          # 原始查询
├── refreshStrategy                # 刷新策略
├── refreshInterval                # 刷新间隔
├── dependencies                   # 依赖的其他视图
└── storageConfig                  # 存储配置

ViewRefresher
├── FullRefreshStrategy            # 完全刷新策略
├── IncrementalRefreshStrategy     # 增量刷新策略
└── HybridRefreshStrategy          # 混合刷新策略

MaterializedViewRepository
├── getView()                      # 获取视图
├── saveView()                     # 保存视图
├── deleteView()                   # 删除视图
└── findStaleViews()               # 查找过期视图

NodeTreeMaterializedView           # 节点树物化视图
├── treeStructure                  # 树形结构
├── nodeCount                      # 节点计数
├── depth                          # 树深度
└── lastModified                   # 最后修改时间

GraphStatsMaterializedView         # 图统计物化视图
├── nodeStats                      # 节点统计
├── connectionStats                # 连接统计
├── layoutMetrics                  # 布局指标
└── usageStats                     # 使用统计

SearchIndexMaterializedView        # 搜索索引物化视图
├── invertedIndex                  # 倒排索引
├── termFrequency                  # 词频统计
├── documentFrequency              # 文档频率
└── relevanceScores                # 相关性分数
```

### 接口定义

```dart
/// 物化视图基类
abstract class MaterializedView {
  /// 视图唯一标识
  String get viewId;

  /// 视图名称
  String get viewName;

  /// 视图定义
  ViewDefinition get definition;

  /// 最后刷新时间
  DateTime get lastRefreshed;

  /// 视图状态
  MaterializedViewStatus get status;

  /// 视图数据
  Map<String, dynamic> get data;

  /// 获取视图大小（字节）
  int get size;

  /// 验证视图数据
  ValidationResult validate();

  /// 检查视图是否过期
  bool isStale();
}

/// 视图状态
enum MaterializedViewStatus {
  /// 活跃（可用）
  active,

  /// 刷新中
  refreshing,

  /// 过期（需要刷新）
  stale,

  /// 错误（刷新失败）
  error,

  /// 禁用（不自动刷新）
  disabled,
}

/// 视图定义
class ViewDefinition {
  /// 视图唯一标识
  final String viewId;

  /// 视图名称
  final String viewName;

  /// 视图描述
  final String description;

  /// 原始查询或计算逻辑
  final String query;

  /// 刷新策略
  final RefreshStrategy refreshStrategy;

  /// 刷新间隔（用于定时刷新）
  final Duration? refreshInterval;

  /// 依赖的其他视图
  final List<String> dependencies;

  /// 存储配置
  final ViewStorageConfig storageConfig;

  /// 视图优先级（用于决定刷新顺序）
  final ViewPriority priority;

  const ViewDefinition({
    required this.viewId,
    required this.viewName,
    required this.description,
    required this.query,
    required this.refreshStrategy,
    this.refreshInterval,
    this.dependencies = const [],
    required this.storageConfig,
    this.priority = ViewPriority.normal,
  });
}

/// 刷新策略
enum RefreshStrategy {
  /// 实时刷新（数据变化时立即刷新）
  realTime,

  /// 定时刷新（按固定间隔刷新）
  scheduled,

  /// 按需刷新（查询时检查是否需要刷新）
  onDemand,

  /// 增量刷新（只更新变化的部分）
  incremental,

  /// 混合刷新（结合多种策略）
  hybrid,
}

/// 视图优先级
enum ViewPriority {
  /// 高优先级（优先刷新）
  high,

  /// 普通优先级
  normal,

  /// 低优先级（延迟刷新）
  low,
}

/// 视图存储配置
class ViewStorageConfig {
  /// 是否持久化到磁盘
  final bool persistToDisk;

  /// 是否压缩存储
  final bool compress;

  /// 最大缓存大小（字节）
  final int? maxCacheSize;

  /// 存储位置
  final String? storagePath;

  const ViewStorageConfig({
    this.persistToDisk = true,
    this.compress = false,
    this.maxCacheSize,
    this.storagePath,
  });
}

/// 物化视图仓储
abstract class MaterializedViewRepository {
  /// 保存视图
  Future<void> saveView(MaterializedView view);

  /// 获取视图
  Future<MaterializedView?> getView(String viewId);

  /// 获取所有视图
  Future<List<MaterializedView>> getAllViews();

  /// 删除视图
  Future<void> deleteView(String viewId);

  /// 查找过期视图
  Future<List<MaterializedView>> findStaleViews();

  /// 查找需要刷新的视图
  Future<List<MaterializedView>> findViewsToRefresh();

  /// 清空所有视图
  Future<void> clearAllViews();
}

/// 视图刷新器
abstract class ViewRefresher {
  /// 刷新视图
  Future<MaterializedView> refresh(MaterializedView view);

  /// 批量刷新
  Future<List<MaterializedView>> refreshBatch(
    List<MaterializedView> views,
  );

  /// 增量刷新
  Future<MaterializedView> refreshIncremental(
    MaterializedView view,
    List<DataChangeEvent> changes,
  );

  /// 取消正在进行的刷新
  Future<void> cancelRefresh(String viewId);

  /// 获取刷新进度
  RefreshProgress? getRefreshProgress(String viewId);
}

/// 刷新进度
class RefreshProgress {
  final String viewId;
  final double progress; // 0.0 到 1.0
  final String? currentStep;
  final DateTime startTime;
  final Duration? estimatedTimeRemaining;

  const RefreshProgress({
    required this.viewId,
    required this.progress,
    this.currentStep,
    required this.startTime,
    this.estimatedTimeRemaining,
  });

  bool get isComplete => progress >= 1.0;
}

/// 视图依赖管理器
abstract class ViewDependencyManager {
  /// 注册视图依赖
  void registerDependency(String viewId, List<String> dependencies);

  /// 获取视图的依赖
  List<String> getDependencies(String viewId);

  /// 获取依赖于此视图的其他视图
  List<String> getDependents(String viewId);

  /// 按依赖顺序排序视图（拓扑排序）
  List<String> sortByDependency(List<String> viewIds);

  /// 检查循环依赖
  bool hasCircularDependency(String viewId);

  /// 当视图更新时，获取需要级联更新的视图
  List<String> getCascadeUpdates(String viewId);
}

/// 视图验证器
abstract class ViewValidator {
  /// 验证视图数据
  ValidationResult validate(MaterializedView view);

  /// 验证视图定义
  ValidationResult validateDefinition(ViewDefinition definition);

  /// 检查视图是否与源数据一致
  Future<bool> isConsistent(MaterializedView view);
}
```

### 节点树物化视图

```dart
/// 节点树物化视图
class NodeTreeMaterializedView extends MaterializedView {
  @override
  final String viewId;

  @override
  final String viewName;

  @override
  final ViewDefinition definition;

  @override
  final DateTime lastRefreshed;

  @override
  final MaterializedViewStatus status;

  @override
  final Map<String, dynamic> data;

  /// 树形结构
  final NodeTreeNode treeStructure;

  /// 节点计数
  final int nodeCount;

  /// 树深度
  final int depth;

  /// 叶子节点数
  final int leafCount;

  /// 最后修改时间
  final DateTime lastModified;

  const NodeTreeMaterializedView({
    required this.viewId,
    required this.viewName,
    required this.definition,
    required this.lastRefreshed,
    required this.status,
    required this.data,
    required this.treeStructure,
    required this.nodeCount,
    required this.depth,
    required this.leafCount,
    required this.lastModified,
  });

  @override
  int get size {
    return data.toString().length;
  }

  @override
  ValidationResult validate() {
    final errors = <String>[];

    if (nodeCount <= 0) {
      errors.add('Node count must be positive');
    }

    if (depth < 0) {
      errors.add('Depth cannot be negative');
    }

    if (leafCount > nodeCount) {
      errors.add('Leaf count cannot exceed node count');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  @override
  bool isStale() {
    if (status == MaterializedViewStatus.stale) {
      return true;
    }

    // 检查是否超过刷新间隔
    final strategy = definition.refreshStrategy;
    if (strategy == RefreshStrategy.scheduled &&
        definition.refreshInterval != null) {
      final age = DateTime.now().difference(lastRefreshed);
      return age > definition.refreshInterval!;
    }

    return false;
  }

  /// 创建空的节点树视图
  factory NodeTreeMaterializedView.empty() {
    return NodeTreeMaterializedView(
      viewId: 'node_tree',
      viewName: 'Node Tree',
      definition: const ViewDefinition(
        viewId: 'node_tree',
        viewName: 'Node Tree',
        description: 'Hierarchical tree structure of nodes',
        query: 'SELECT * FROM nodes ORDER BY parent_id',
        refreshStrategy: RefreshStrategy.incremental,
        refreshInterval: Duration(minutes: 5),
        storageConfig: ViewStorageConfig(),
      ),
      lastRefreshed: DateTime.now(),
      status: MaterializedViewStatus.active,
      data: const {},
      treeStructure: NodeTreeNode.empty(),
      nodeCount: 0,
      depth: 0,
      leafCount: 0,
      lastModified: DateTime.now(),
    );
  }

  /// 复制并更新
  NodeTreeMaterializedView copyWith({
    String? viewId,
    String? viewName,
    ViewDefinition? definition,
    DateTime? lastRefreshed,
    MaterializedViewStatus? status,
    Map<String, dynamic>? data,
    NodeTreeNode? treeStructure,
    int? nodeCount,
    int? depth,
    int? leafCount,
    DateTime? lastModified,
  }) {
    return NodeTreeMaterializedView(
      viewId: viewId ?? this.viewId,
      viewName: viewName ?? this.viewName,
      definition: definition ?? this.definition,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
      status: status ?? this.status,
      data: data ?? this.data,
      treeStructure: treeStructure ?? this.treeStructure,
      nodeCount: nodeCount ?? this.nodeCount,
      depth: depth ?? this.depth,
      leafCount: leafCount ?? this.leafCount,
      lastModified: lastModified ?? this.lastModified,
    );
  }
}

/// 节点树节点
class NodeTreeNode {
  final String nodeId;
  final String title;
  final NodeType type;
  final List<NodeTreeNode> children;

  const NodeTreeNode({
    required this.nodeId,
    required this.title,
    required this.type,
    this.children = const [],
  });

  factory NodeTreeNode.empty() {
    return const NodeTreeNode(
      nodeId: '',
      title: '',
      type: NodeType.content,
      children: [],
    );
  }

  /// 计算树的深度
  int calculateDepth() {
    if (children.isEmpty) {
      return 1;
    }
    return 1 + children
        .map((child) => child.calculateDepth())
        .reduce((a, b) => a > b ? a : b);
  }

  /// 计算叶子节点数
  int calculateLeafCount() {
    if (children.isEmpty) {
      return 1;
    }
    return children.fold(0, (sum, child) => sum + child.calculateLeafCount());
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'nodeId': nodeId,
      'title': title,
      'type': type.name,
      'children': children.map((child) => child.toJson()).toList(),
    };
  }

  /// 从 JSON 创建
  factory NodeTreeNode.fromJson(Map<String, dynamic> json) {
    return NodeTreeNode(
      nodeId: json['nodeId'] as String,
      title: json['title'] as String,
      type: NodeType.values.firstWhere(
        (e) => e.name == json['type'] as String,
      ),
      children: (json['children'] as List?)
              ?.map((child) => NodeTreeNode.fromJson(child as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
```

### 图统计物化视图

```dart
/// 图统计物化视图
class GraphStatsMaterializedView extends MaterializedView {
  @override
  final String viewId;

  @override
  final String viewName;

  @override
  final ViewDefinition definition;

  @override
  final DateTime lastRefreshed;

  @override
  final MaterializedViewStatus status;

  @override
  final Map<String, dynamic> data;

  /// 节点统计
  final NodeStatistics nodeStats;

  /// 连接统计
  final ConnectionStatistics connectionStats;

  /// 布局指标
  final LayoutMetrics layoutMetrics;

  /// 使用统计
  final UsageStatistics usageStats;

  const GraphStatsMaterializedView({
    required this.viewId,
    required this.viewName,
    required this.definition,
    required this.lastRefreshed,
    required this.status,
    required this.data,
    required this.nodeStats,
    required this.connectionStats,
    required this.layoutMetrics,
    required this.usageStats,
  });

  @override
  int get size => data.toString().length;

  @override
  ValidationResult validate() {
    final errors = <String>[];

    if (nodeStats.totalCount < 0) {
      errors.add('Total node count cannot be negative');
    }

    if (connectionStats.totalCount < 0) {
      errors.add('Total connection count cannot be negative');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  @override
  bool isStale() {
    if (status == MaterializedViewStatus.stale) {
      return true;
    }

    final strategy = definition.refreshStrategy;
    if (strategy == RefreshStrategy.scheduled &&
        definition.refreshInterval != null) {
      final age = DateTime.now().difference(lastRefreshed);
      return age > definition.refreshInterval!;
    }

    return false;
  }

  /// 创建空的图统计视图
  factory GraphStatsMaterializedView.empty() {
    return GraphStatsMaterializedView(
      viewId: 'graph_stats',
      viewName: 'Graph Statistics',
      definition: const ViewDefinition(
        viewId: 'graph_stats',
        viewName: 'Graph Statistics',
        description: 'Statistical information about graphs',
        query: 'SELECT COUNT(*) FROM graphs',
        refreshStrategy: RefreshStrategy.scheduled,
        refreshInterval: Duration(minutes: 10),
        storageConfig: ViewStorageConfig(),
      ),
      lastRefreshed: DateTime.now(),
      status: MaterializedViewStatus.active,
      data: const {},
      nodeStats: NodeStatistics.empty(),
      connectionStats: ConnectionStatistics.empty(),
      layoutMetrics: LayoutMetrics.empty(),
      usageStats: UsageStatistics.empty(),
    );
  }
}

/// 节点统计
class NodeStatistics {
  final int totalCount;
  final int conceptCount;
  final int contentCount;
  final int folderCount;
  final Map<NodeType, int> countByType;
  final DateTime lastCreated;

  const NodeStatistics({
    required this.totalCount,
    required this.conceptCount,
    required this.contentCount,
    required this.folderCount,
    required this.countByType,
    required this.lastCreated,
  });

  factory NodeStatistics.empty() {
    return const NodeStatistics(
      totalCount: 0,
      conceptCount: 0,
      contentCount: 0,
      folderCount: 0,
      countByType: {},
      lastCreated: DateTime(1970, 1, 1),
    );
  }
}

/// 连接统计
class ConnectionStatistics {
  final int totalCount;
  final int bidirectionalCount;
  final int unidirectionalCount;
  final Map<ConnectionType, int> countByType;

  const ConnectionStatistics({
    required this.totalCount,
    required this.bidirectionalCount,
    required this.unidirectionalCount,
    required this.countByType,
  });

  factory ConnectionStatistics.empty() {
    return const ConnectionStatistics(
      totalCount: 0,
      bidirectionalCount: 0,
      unidirectionalCount: 0,
      countByType: {},
    );
  }
}

/// 布局指标
class LayoutMetrics {
  final double averageNodeSize;
  final double averageConnectionLength;
  final Rect boundingBox;
  final int layoutConflicts;

  const LayoutMetrics({
    required this.averageNodeSize,
    required this.averageConnectionLength,
    required this.boundingBox,
    required this.layoutConflicts,
  });

  factory LayoutMetrics.empty() {
    return const LayoutMetrics(
      averageNodeSize: 0.0,
      averageConnectionLength: 0.0,
      boundingBox: Rect.zero,
      layoutConflicts: 0,
    );
  }
}

/// 使用统计
class UsageStatistics {
  final int totalViews;
  final int totalEdits;
  final DateTime lastAccessed;
  final List<String> mostAccessedNodes;

  const UsageStatistics({
    required this.totalViews,
    required this.totalEdits,
    required this.lastAccessed,
    required this.mostAccessedNodes,
  });

  factory UsageStatistics.empty() {
    return const UsageStatistics(
      totalViews: 0,
      totalEdits: 0,
      lastAccessed: DateTime(1970, 1, 1),
      mostAccessedNodes: [],
    );
  }
}
```

### 视图刷新器实现

```dart
/// 视图刷新器实现
class ViewRefresherImpl implements ViewRefresher {
  final MaterializedViewRepository _repository;
  final ViewDependencyManager _dependencyManager;
  final Map<String, RefreshProgress> _refreshProgress = {};

  ViewRefresherImpl({
    required MaterializedViewRepository repository,
    required ViewDependencyManager dependencyManager,
  })  : _repository = repository,
        _dependencyManager = dependencyManager;

  @override
  Future<MaterializedView> refresh(MaterializedView view) async {
    // 初始化刷新进度
    _refreshProgress[view.viewId] = RefreshProgress(
      viewId: view.viewId,
      progress: 0.0,
      currentStep: 'Initializing',
      startTime: DateTime.now(),
    );

    try {
      // 根据视图类型执行不同的刷新逻辑
      MaterializedView refreshedView;

      if (view is NodeTreeMaterializedView) {
        refreshedView = await _refreshNodeTree(view as NodeTreeMaterializedView);
      } else if (view is GraphStatsMaterializedView) {
        refreshedView =
            await _refreshGraphStats(view as GraphStatsMaterializedView);
      } else {
        refreshedView = await _refreshGenericView(view);
      }

      // 保存刷新后的视图
      await _repository.saveView(refreshedView);

      // 更新进度
      _refreshProgress[view.viewId] = RefreshProgress(
        viewId: view.viewId,
        progress: 1.0,
        currentStep: 'Completed',
        startTime: _refreshProgress[view.viewId]!.startTime,
      );

      return refreshedView;
    } catch (e, stackTrace) {
      // 记录错误
      debugPrint('Failed to refresh view ${view.viewId}: $e');
      debugPrint(stackTrace.toString());

      // 更新状态为错误
      final errorView = _updateViewStatus(view, MaterializedViewStatus.error);
      await _repository.saveView(errorView);

      rethrow;
    } finally {
      // 清理进度
      _refreshProgress.remove(view.viewId);
    }
  }

  @override
  Future<List<MaterializedView>> refreshBatch(
    List<MaterializedView> views,
  ) async {
    // 按依赖关系排序
    final sortedIds = _dependencyManager.sortByDependency(
      views.map((v) => v.viewId).toList(),
    );

    final refreshResults = <MaterializedView>[];

    for (final viewId in sortedIds) {
      final view = views.firstWhere((v) => v.viewId == viewId);
      try {
        final refreshed = await refresh(view);
        refreshResults.add(refreshed);
      } catch (e) {
        // 继续刷新其他视图
        debugPrint('Failed to refresh view $viewId: $e');
      }
    }

    return refreshResults;
  }

  @override
  Future<MaterializedView> refreshIncremental(
    MaterializedView view,
    List<DataChangeEvent> changes,
  ) async {
    // 增量刷新逻辑
    if (view is NodeTreeMaterializedView) {
      return await _incrementalRefreshNodeTree(
        view as NodeTreeMaterializedView,
        changes,
      );
    } else if (view is GraphStatsMaterializedView) {
      return await _incrementalRefreshGraphStats(
        view as GraphStatsMaterializedView,
        changes,
      );
    } else {
      // 不支持增量刷新，回退到完全刷新
      return await refresh(view);
    }
  }

  @override
  Future<void> cancelRefresh(String viewId) async {
    // 实现取消逻辑
    _refreshProgress.remove(viewId);
  }

  @override
  RefreshProgress? getRefreshProgress(String viewId) {
    return _refreshProgress[viewId];
  }

  Future<NodeTreeMaterializedView> _refreshNodeTree(
    NodeTreeMaterializedView view,
  ) async {
    _updateProgress(view.viewId, 0.2, 'Loading nodes');

    // 获取所有节点
    final nodes = await _loadAllNodes();

    _updateProgress(view.viewId, 0.5, 'Building tree structure');

    // 构建树结构
    final treeStructure = await _buildTreeStructure(nodes);

    _updateProgress(view.viewId, 0.8, 'Calculating statistics');

    // 计算统计信息
    final depth = treeStructure.calculateDepth();
    final leafCount = treeStructure.calculateLeafCount();

    _updateProgress(view.viewId, 1.0, 'Completed');

    return view.copyWith(
      lastRefreshed: DateTime.now(),
      status: MaterializedViewStatus.active,
      data: treeStructure.toJson(),
      treeStructure: treeStructure,
      nodeCount: nodes.length,
      depth: depth,
      leafCount: leafCount,
      lastModified: DateTime.now(),
    );
  }

  Future<GraphStatsMaterializedView> _refreshGraphStats(
    GraphStatsMaterializedView view,
  ) async {
    _updateProgress(view.viewId, 0.3, 'Collecting node statistics');

    // 收集节点统计
    final nodeStats = await _collectNodeStatistics();

    _updateProgress(view.viewId, 0.6, 'Collecting connection statistics');

    // 收集连接统计
    final connectionStats = await _collectConnectionStatistics();

    _updateProgress(view.viewId, 0.9, 'Collecting layout metrics');

    // 收集布局指标
    final layoutMetrics = await _collectLayoutMetrics();

    _updateProgress(view.viewId, 1.0, 'Completed');

    return view.copyWith(
      lastRefreshed: DateTime.now(),
      status: MaterializedViewStatus.active,
      data: {},
      nodeStats: nodeStats,
      connectionStats: connectionStats,
      layoutMetrics: layoutMetrics,
    );
  }

  Future<MaterializedView> _refreshGenericView(
    MaterializedView view,
  ) async {
    // 通用刷新逻辑
    // 执行视图定义中的查询
    final result = await _executeQuery(view.definition.query);

    return view.copyWith(
      lastRefreshed: DateTime.now(),
      status: MaterializedViewStatus.active,
      data: result,
    );
  }

  Future<NodeTreeMaterializedView> _incrementalRefreshNodeTree(
    NodeTreeMaterializedView view,
    List<DataChangeEvent> changes,
  ) async {
    // 增量更新树结构
    NodeTreeNode updatedTree = view.treeStructure;

    for (final change in changes) {
      if (change.type == ChangeType.add) {
        updatedTree = _addNodeToTree(updatedTree, change.nodeId);
      } else if (change.type == ChangeType.delete) {
        updatedTree = _removeNodeFromTree(updatedTree, change.nodeId);
      } else if (change.type == ChangeType.update) {
        updatedTree = _updateNodeInTree(updatedTree, change.nodeId);
      }
    }

    return view.copyWith(
      lastRefreshed: DateTime.now(),
      status: MaterializedViewStatus.active,
      data: updatedTree.toJson(),
      treeStructure: updatedTree,
    );
  }

  Future<GraphStatsMaterializedView> _incrementalRefreshGraphStats(
    GraphStatsMaterializedView view,
    List<DataChangeEvent> changes,
  ) async {
    // 增量更新统计信息
    NodeStatistics updatedNodeStats = view.nodeStats;
    ConnectionStatistics updatedConnectionStats = view.connectionStats;

    for (final change in changes) {
      if (change.entityType == EntityType.node) {
        updatedNodeStats = _updateNodeStatistics(
          updatedNodeStats,
          change.type,
        );
      } else if (change.entityType == EntityType.connection) {
        updatedConnectionStats = _updateConnectionStatistics(
          updatedConnectionStats,
          change.type,
        );
      }
    }

    return view.copyWith(
      lastRefreshed: DateTime.now(),
      status: MaterializedViewStatus.active,
      nodeStats: updatedNodeStats,
      connectionStats: updatedConnectionStats,
    );
  }

  void _updateProgress(String viewId, double progress, String step) {
    _refreshProgress[viewId] = RefreshProgress(
      viewId: viewId,
      progress: progress,
      currentStep: step,
      startTime: _refreshProgress[viewId]?.startTime ?? DateTime.now(),
    );
  }

  MaterializedView _updateViewStatus(
    MaterializedView view,
    MaterializedViewStatus status,
  ) {
    // 更新视图状态的辅助方法
    // 具体实现取决于视图类型
    return view;
  }

  // 辅助方法（需要实际实现）
  Future<List<Node>> _loadAllNodes() async => [];
  Future<NodeTreeNode> _buildTreeStructure(List<Node> nodes) async =>
      NodeTreeNode.empty();
  Future<NodeStatistics> _collectNodeStatistics() async =>
      NodeStatistics.empty();
  Future<ConnectionStatistics> _collectConnectionStatistics() async =>
      ConnectionStatistics.empty();
  Future<LayoutMetrics> _collectLayoutMetrics() async =>
      LayoutMetrics.empty();
  Future<Map<String, dynamic>> _executeQuery(String query) async => {};
  NodeTreeNode _addNodeToTree(NodeTreeNode tree, String nodeId) => tree;
  NodeTreeNode _removeNodeFromTree(NodeTreeNode tree, String nodeId) => tree;
  NodeTreeNode _updateNodeInTree(NodeTreeNode tree, String nodeId) => tree;
  NodeStatistics _updateNodeStatistics(
    NodeStatistics stats,
    ChangeType changeType,
  ) =>
      stats;
  ConnectionStatistics _updateConnectionStatistics(
    ConnectionStatistics stats,
    ChangeType changeType,
  ) =>
      stats;
}
```

### 视图依赖管理器实现

```dart
/// 视图依赖管理器实现
class ViewDependencyManagerImpl implements ViewDependencyManager {
  final Map<String, List<String>> _dependencies = {};
  final Map<String, List<String>> _dependents = {};

  @override
  void registerDependency(String viewId, List<String> dependencies) {
    _dependencies[viewId] = dependencies;

    // 更新反向依赖
    for (final dep in dependencies) {
      _dependents.putIfAbsent(dep, () => []);
      _dependents[dep]!.add(viewId);
    }
  }

  @override
  List<String> getDependencies(String viewId) {
    return _dependencies[viewId] ?? [];
  }

  @override
  List<String> getDependents(String viewId) {
    return _dependents[viewId] ?? [];
  }

  @override
  List<String> sortByDependency(List<String> viewIds) {
    // 拓扑排序
    final sorted = <String>[];
    final visited = <String>{};
    final visiting = <String>{};

    void visit(String viewId) {
      if (visiting.contains(viewId)) {
        throw CircularDependencyException('Circular dependency detected at $viewId');
      }
      if (visited.contains(viewId)) {
        return;
      }

      visiting.add(viewId);

      for (final dep in getDependencies(viewId)) {
        if (viewIds.contains(dep)) {
          visit(dep);
        }
      }

      visiting.remove(viewId);
      visited.add(viewId);
      sorted.add(viewId);
    }

    for (final viewId in viewIds) {
      if (!visited.contains(viewId)) {
        visit(viewId);
      }
    }

    return sorted;
  }

  @override
  bool hasCircularDependency(String viewId) {
    try {
      sortByDependency([viewId]);
      return false;
    } on CircularDependencyException {
      return true;
    }
  }

  @override
  List<String> getCascadeUpdates(String viewId) {
    // 获取所有依赖于此视图的视图
    final cascade = <String>[];
    final toVisit = Queue<String>();
    final visited = <String>{};

    toVisit.add(viewId);

    while (toVisit.isNotEmpty) {
      final current = toVisit.removeFirst();
      if (visited.contains(current)) {
        continue;
      }

      visited.add(current);
      final dependents = getDependents(current);
      cascade.addAll(dependents);

      for (final dependent in dependents) {
        if (!visited.contains(dependent)) {
          toVisit.add(dependent);
        }
      }
    }

    return cascade;
  }
}

class CircularDependencyException implements Exception {
  final String message;
  CircularDependencyException(this.message);
}
```

## 核心算法

### 1. 拓扑排序算法

**问题描述**：根据视图之间的依赖关系进行排序，确保依赖的视图先被刷新。

**算法描述**：
1. 构建依赖图
2. 使用深度优先搜索进行拓扑排序
3. 检测循环依赖
4. 返回排序后的视图列表

**伪代码**：
```
function topologicalSort(viewIds):
    sorted = []
    visited = Set()
    visiting = Set()

    function visit(viewId):
        if visiting.contains(viewId):
            throw CircularDependencyException

        if visited.contains(viewId):
            return

        visiting.add(viewId)

        for dep in getDependencies(viewId):
            if viewIds.contains(dep):
                visit(dep)

        visiting.remove(viewId)
        visited.add(viewId)
        sorted.add(viewId)

    for viewId in viewIds:
        if not visited.contains(viewId):
            visit(viewId)

    return sorted
```

**复杂度分析**：
- 时间复杂度：O(V + E)，其中 V 是视图数量，E 是依赖关系数量
- 空间复杂度：O(V)

### 2. 增量刷新算法

**问题描述**：只更新物化视图中变化的部分，而不是完全重建。

**算法描述**：
1. 分析数据变化事件
2. 确定变化对视图的影响范围
3. 只更新受影响的部分
4. 重新计算聚合值

**伪代码**：
```
function incrementalRefresh(view, changes):
    updatedView = view.copy()

    for change in changes:
        if change.type == ADD:
            updatedView = applyAdd(updatedView, change)
        else if change.type == DELETE:
            updatedView = applyDelete(updatedView, change)
        else if change.type == UPDATE:
            updatedView = applyUpdate(updatedView, change)

    // 重新计算聚合值
    updatedView = recalculateAggregates(updatedView)

    updatedView.lastRefreshed = now()
    updatedView.status = ACTIVE

    return updatedView
```

**复杂度分析**：
- 时间复杂度：O(c × d)，其中 c 是变化数量，d 是每个变化的影响范围
- 空间复杂度：O(1)

### 3. 级联更新算法

**问题描述**：当一个视图更新时，确定并更新所有依赖于此视图的其他视图。

**算法描述**：
1. 找到所有依赖于此视图的视图
2. 递归找到所有间接依赖的视图
3. 按依赖顺序更新这些视图
4. 处理更新失败的情况

**伪代码**：
```
function cascadeUpdates(viewId):
    toUpdate = []
    visited = Set()
    queue = Queue()

    queue.enqueue(viewId)

    while not queue.isEmpty():
        current = queue.dequeue()

        if visited.contains(current):
            continue

        visited.add(current)

        dependents = getDependents(current)
        toUpdate.addAll(dependents)

        for dependent in dependents:
            if not visited.contains(dependent):
                queue.enqueue(dependent)

    // 按依赖顺序排序并更新
    sorted = topologicalSort(toUpdate)

    for viewId in sorted:
        try:
            view = getView(viewId)
            refresh(view)
        except e:
            logError(e)
```

**复杂度分析**：
- 时间复杂度：O(V × E)，其中 V 是视图数量，E 是依赖关系数量
- 空间复杂度：O(V)

### 4. 树结构增量更新算法

**问题描述**：当节点添加、删除或更新时，增量更新节点树结构。

**算法描述**：
1. 定位变化节点的父节点
2. 根据变化类型更新树结构
3. 重新计算树的深度和叶子节点数
4. 更新路径上的所有统计信息

**伪代码**：
```
function updateTreeIncremental(tree, change):
    if change.type == ADD:
        parentNode = findNode(tree, change.parentId)
        newChild = createNode(change.node)
        parentNode.children.add(newChild)

    else if change.type == DELETE:
        parentNode = findNode(tree, change.parentId)
        parentNode.children.removeWhere(n => n.id == change.nodeId)

    else if change.type == UPDATE:
        node = findNode(tree, change.nodeId)
        updateNodeData(node, change.data)

    // 重新计算统计信息
    tree.depth = calculateDepth(tree)
    tree.leafCount = calculateLeafCount(tree)

    return tree
```

**复杂度分析**：
- 时间复杂度：O(h)，其中 h 是树的高度
- 空间复杂度：O(1)

## 性能考虑

### 概念性能指标

1. **刷新性能**：
   - 小型视图（< 1000条记录）：< 100ms
   - 中型视图（1000-10000条记录）：< 1s
   - 大型视图（> 10000条记录）：< 10s

2. **增量更新性能**：
   - 单个变化：< 10ms
   - 批量变化（100个）：< 100ms
   - 比完全刷新快 5-20 倍

3. **查询性能**：
   - 物化视图查询比原始查询快 10-100 倍
   - 复杂聚合查询：从秒级降低到毫秒级

4. **存储开销**：
   - 物化视图占存储的 10-50%（取决于视图类型）
   - 压缩后可减少 50-70% 的存储空间

### 性能优化策略

1. **增量刷新**：
   - 优先使用增量刷新而不是完全刷新
   - 只更新变化的部分
   - 使用触发器自动检测变化

2. **并行刷新**：
   - 并行刷新独立的视图
   - 使用后台线程刷新
   - 避免阻塞主线程

3. **智能调度**：
   - 根据优先级调整刷新顺序
   - 在低负载时刷新低优先级视图
   - 避免同时刷新多个大型视图

4. **存储优化**：
   - 使用压缩减少存储空间
   - 分区存储大型视图
   - 定期清理不常用的视图

5. **缓存策略**：
   - 缓存热点的物化视图
   - 使用内存缓存加速访问
   - 实现智能缓存预热

## 关键文件列表

### 核心实现文件

1. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\materialized_view.dart**
   - MaterializedView 基类
   - MaterializedViewStatus 枚举
   - 视图基础功能

2. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\view_definition.dart**
   - ViewDefinition 类
   - RefreshStrategy、ViewPriority 枚举
   - ViewStorageConfig 类

3. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\view_refresher.dart**
   - ViewRefresher 接口
   - ViewRefresherImpl 实现
   - RefreshProgress 类

4. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\view_dependency_manager.dart**
   - ViewDependencyManager 接口
   - ViewDependencyManagerImpl 实现
   - 依赖关系管理

5. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\view_validator.dart**
   - ViewValidator 接口
   - 视图验证逻辑

6. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\view_repository.dart**
   - MaterializedViewRepository 接口
   - 仓储实现
   - 视图持久化

### 具体物化视图文件

7. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\node_tree_view.dart**
   - NodeTreeMaterializedView 类
   - NodeTreeNode 类
   - 树结构相关方法

8. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\graph_stats_view.dart**
   - GraphStatsMaterializedView 类
   - NodeStatistics、ConnectionStatistics 等数据类
   - 统计信息收集

9. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\search_index_view.dart**
   - SearchIndexMaterializedView 类
   - 搜索索引相关方法
   - 全文索引维护

### 刷新策略文件

10. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\strategies\full_refresh_strategy.dart**
    - 完全刷新策略
    - 完全重建视图

11. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\strategies\incremental_refresh_strategy.dart**
    - 增量刷新策略
    - 增量更新逻辑

12. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\strategies\hybrid_refresh_strategy.dart**
    - 混合刷新策略
    - 结合多种策略

### 刷新器实现文件

13. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\refreshers\node_tree_refresher.dart**
    - 节点树视图刷新器
    - 树结构构建和更新

14. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\refreshers\graph_stats_refresher.dart**
    - 图统计视图刷新器
    - 统计信息收集

15. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\refreshers\search_index_refresher.dart**
    - 搜索索引刷新器
    - 索引更新逻辑

### 仓储实现文件

16. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\repositories\materialized_view_repository_impl.dart**
    - 物化视图仓储实现
    - 文件存储或数据库存储

### 配置和工具文件

17. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\view_config.dart**
    - 物化视图配置
    - 刷新策略配置
    - 存储配置

18. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\view_scheduler.dart**
    - 视图刷新调度器
    - 定时刷新逻辑
    - 优先级管理

### 测试文件

19. **D:\Projects\node_graph_notebook\test\core\cqrs\materialized_views\view_refresher_test.dart**
    - 视图刷新器测试
    - 刷新策略测试

20. **D:\Projects\node_graph_notebook\test\core\cqrs\materialized_views\dependency_manager_test.dart**
    - 依赖管理器测试
    - 拓扑排序测试

21. **D:\Projects\node_graph_notebook\test\core\cqrs\materialized_views\incremental_refresh_test.dart**
    - 增量刷新测试
    - 性能测试

### 集成文件

22. **D:\Projects\node_graph_notebook\lib\app.dart**
    - 注册物化视图组件
    - 配置依赖注入

23. **D:\Projects\node_graph_notebook\lib\core\events\event_integration.dart**
    - 数据变化事件与视图刷新的集成
    - 事件监听器配置

24. **D:\Projects\node_graph_notebook\lib\core\cqrs\materialized_views\view_manager.dart**
    - 物化视图管理器
    - 统一管理所有视图的生命周期
    - 视图注册和发现
