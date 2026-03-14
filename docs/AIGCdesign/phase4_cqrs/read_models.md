# 读模型 (Read Models) 设计文档

## 概述

### 职责

读模型是 CQRS 架构中专门为读取操作优化的数据模型，负责：

- **数据投影**：将写模型数据转换为适合读取的格式
- **数据聚合**：聚合多个写模型数据到单个读模型
- **性能优化**：为常见查询场景优化数据结构
- **数据去重**：避免重复计算和数据冗余
- **视图维护**：保持读模型与写模型的最终一致性

### 目标

1. **读取性能**：最大化查询性能，避免复杂的 JOIN 和计算
2. **解耦**：读模型与写模型完全解耦，可独立演进
3. **灵活性**：支持不同场景的多种读模型视图
4. **可维护性**：简化读模型的数据同步和更新逻辑
5. **可测试性**：易于测试和验证数据一致性

### 关键挑战

1. **数据同步**：如何在写模型更新时保持读模型的一致性
2. **投影策略**：如何设计高效的投影逻辑
3. **数据一致性**：如何处理最终一致性和数据延迟
4. **性能权衡**：如何在存储成本和查询性能之间权衡
5. **模型演化**：如何在保持向后兼容的同时演进读模型

## 架构设计

### 组件结构

```
ReadModel
├── ReadModelProjection            # 读模型投影器
├── ReadModelSynchronizer          # 读模型同步器
├── ReadModelValidator             # 读模型验证器
└── ReadModelRepository            # 读模型仓储

ReadModelProjectionStrategy        # 投影策略
├── RealTimeProjection             # 实时投影
├── EventSourcedProjection         # 事件溯源投影
└── ScheduledProjection            # 定时投影

NodeReadModel                      # 节点读模型
├── basicInfo                      # 基本信息
├── contentPreview                 # 内容预览
├── metadata                       # 元数据
└── relationships                  # 关系信息

GraphReadModel                     # 图读模型
├── nodes                          # 节点列表
├── connections                    # 连接列表
├── layoutInfo                     # 布局信息
└── statistics                     # 统计信息

SearchReadModel                    # 搜索读模型
├── indexedContent                 # 索引内容
├── tags                           # 标签索引
├── fullTextIndex                  # 全文索引
└── searchMetadata                 # 搜索元数据
```

### 接口定义

```dart
/// 读模型基类
abstract class ReadModel {
  /// 读模型唯一标识
  String get id;

  /// 最后更新时间
  DateTime get lastUpdated;

  /// 读模型版本（用于冲突检测）
  int get version;

  /// 读模型状态
  ReadModelStatus get status;

  /// 验证读模型数据一致性
  ValidationResult validate();
}

/// 读模型状态
enum ReadModelStatus {
  /// 同步中
  syncing,

  /// 已同步
  synced,

  /// 同步失败
  syncFailed,

  /// 需要重建
  needsRebuild,
}

/// 读模型投影器
abstract class ReadModelProjection<W, R extends ReadModel> {
  /// 从写模型投影到读模型
  Future<R> project(W writeModel);

  /// 批量投影
  Future<List<R>> projectBatch(List<W> writeModels);

  /// 增量投影（只更新变化的部分）
  Future<R> projectIncremental(
    R currentReadModel,
    W updatedWriteModel,
  );

  /// 获取投影策略
  ProjectionStrategy get strategy;
}

/// 投影策略
enum ProjectionStrategy {
  /// 实时投影（每次写操作都立即投影）
  realTime,

  /// 事件驱动投影（通过事件异步投影）
  eventSourced,

  /// 定时投影（按计划批量投影）
  scheduled,

  /// 按需投影（查询时才投影）
  onDemand,
}

/// 读模型同步器
abstract class ReadModelSyncronizer<R extends ReadModel> {
  /// 同步读模型
  Future<void> sync(R readModel);

  /// 批量同步
  Future<void> syncBatch(List<R> readModels);

  /// 重建读模型（完全重新投影）
  Future<void> rebuild(R readModel);

  /// 获取同步状态
  SyncStatus getSyncStatus(String readModelId);

  /// 监听写模型变化
  Stream<WriteModelChangeEvent> get writeModelChanges;
}

/// 同步状态
class SyncStatus {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? error;
  final int pendingUpdates;

  const SyncStatus({
    required this.isSyncing,
    this.lastSyncTime,
    this.error,
    this.pendingUpdates = 0,
  });
}

/// 读模型仓储
abstract class ReadModelRepository<R extends ReadModel> {
  /// 保存读模型
  Future<void> save(R readModel);

  /// 获取读模型
  Future<R?> getById(String id);

  /// 批量获取
  Future<List<R>> getByIds(List<String> ids);

  /// 删除读模型
  Future<void> delete(String id);

  /// 查询读模型
  Future<List<R>> query(ReadModelQuery query);

  /// 获取过期或需要更新的读模型
  Future<List<R>> getStaleModels(Duration maxAge);
}

/// 读模型查询
class ReadModelQuery {
  final Map<String, dynamic> filters;
  final int? limit;
  final int? offset;
  final String? orderBy;

  const ReadModelQuery({
    this.filters = const {},
    this.limit,
    this.offset,
    this.orderBy,
  });
}

/// 验证结果
class ValidationResult {
  final bool isValid;
  final List<String> errors;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
  });
}
```

### 节点读模型

```dart
/// 节点读模型
class NodeReadModel extends ReadModel {
  @override
  final String id;

  @override
  final DateTime lastUpdated;

  @override
  final int version;

  @override
  final ReadModelStatus status;

  /// 基本信息
  final NodeBasicInfo basicInfo;

  /// 内容预览（前200字符）
  final String contentPreview;

  /// 元数据
  final NodeReadMetadata metadata;

  /// 关系信息（子节点、父节点、引用）
  final NodeRelationships relationships;

  /// 统计信息
  final NodeStatistics statistics;

  const NodeReadModel({
    required this.id,
    required this.lastUpdated,
    required this.version,
    required this.status,
    required this.basicInfo,
    required this.contentPreview,
    required this.metadata,
    required this.relationships,
    required this.statistics,
  });

  @override
  ValidationResult validate() {
    final errors = <String>[];

    if (basicInfo.title.isEmpty) {
      errors.add('Title cannot be empty');
    }

    if (version < 0) {
      errors.add('Version must be non-negative');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }

  /// 创建空的节点读模型
  factory NodeReadModel.empty() {
    return NodeReadModel(
      id: '',
      lastUpdated: DateTime.now(),
      version: 0,
      status: ReadModelStatus.needsRebuild,
      basicInfo: NodeBasicInfo.empty(),
      contentPreview: '',
      metadata: NodeReadMetadata.empty(),
      relationships: NodeRelationships.empty(),
      statistics: NodeStatistics.empty(),
    );
  }

  /// 复制并更新部分字段
  NodeReadModel copyWith({
    String? id,
    DateTime? lastUpdated,
    int? version,
    ReadModelStatus? status,
    NodeBasicInfo? basicInfo,
    String? contentPreview,
    NodeReadMetadata? metadata,
    NodeRelationships? relationships,
    NodeStatistics? statistics,
  }) {
    return NodeReadModel(
      id: id ?? this.id,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      version: version ?? this.version,
      status: status ?? this.status,
      basicInfo: basicInfo ?? this.basicInfo,
      contentPreview: contentPreview ?? this.contentPreview,
      metadata: metadata ?? this.metadata,
      relationships: relationships ?? this.relationships,
      statistics: statistics ?? this.statistics,
    );
  }
}

/// 节点基本信息
class NodeBasicInfo {
  final String id;
  final String title;
  final NodeType type;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const NodeBasicInfo({
    required this.id,
    required this.title,
    required this.type,
    required this.createdAt,
    required this.modifiedAt,
  });

  factory NodeBasicInfo.empty() {
    return NodeBasicInfo(
      id: '',
      title: '',
      type: NodeType.content,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );
  }
}

/// 节点读元数据
class NodeReadMetadata {
  final List<String> tags;
  final int contentLength;
  final bool hasChildren;
  final int childCount;
  final bool isReferenced;
  final int referenceCount;

  const NodeReadMetadata({
    required this.tags,
    required this.contentLength,
    required this.hasChildren,
    required this.childCount,
    required this.isReferenced,
    required this.referenceCount,
  });

  factory NodeReadMetadata.empty() {
    return NodeReadMetadata(
      tags: [],
      contentLength: 0,
      hasChildren: false,
      childCount: 0,
      isReferenced: false,
      referenceCount: 0,
    );
  }
}

/// 节点关系信息
class NodeRelationships {
  final List<String> childIds;
  final List<String> parentIds;
  final List<String> referenceIds;
  final List<String> referencedByIds;

  const NodeRelationships({
    required this.childIds,
    required this.parentIds,
    required this.referenceIds,
    required this.referencedByIds,
  });

  factory NodeRelationships.empty() {
    return NodeRelationships(
      childIds: [],
      parentIds: [],
      referenceIds: [],
      referencedByIds: [],
    );
  }
}

/// 节点统计信息
class NodeStatistics {
  final int totalViews;
  final int totalEdits;
  final DateTime? lastViewedAt;
  final DateTime? lastEditedAt;

  const NodeStatistics({
    required this.totalViews,
    required this.totalEdits,
    this.lastViewedAt,
    this.lastEditedAt,
  });

  factory NodeStatistics.empty() {
    return NodeStatistics(
      totalViews: 0,
      totalEdits: 0,
    );
  }
}
```

### 图读模型

```dart
/// 图读模型
class GraphReadModel extends ReadModel {
  @override
  final String id;

  @override
  final DateTime lastUpdated;

  @override
  final int version;

  @override
  final ReadModelStatus status;

  /// 图基本信息
  final GraphBasicInfo basicInfo;

  /// 节点列表（仅包含必要信息）
  final List<GraphNodeInfo> nodes;

  /// 连接列表
  final List<GraphConnectionInfo> connections;

  /// 布局信息
  final GraphLayoutInfo layoutInfo;

  /// 统计信息
  final GraphStatistics statistics;

  const GraphReadModel({
    required this.id,
    required this.lastUpdated,
    required this.version,
    required this.status,
    required this.basicInfo,
    required this.nodes,
    required this.connections,
    required this.layoutInfo,
    required this.statistics,
  });

  @override
  ValidationResult validate() {
    final errors = <String>[];

    if (basicInfo.name.isEmpty) {
      errors.add('Graph name cannot be empty');
    }

    // 验证连接引用的节点是否存在
    final nodeIds = nodes.map((n) => n.id).toSet();
    for (final connection in connections) {
      if (!nodeIds.contains(connection.sourceId)) {
        errors.add('Connection source node not found: ${connection.sourceId}');
      }
      if (!nodeIds.contains(connection.targetId)) {
        errors.add('Connection target node not found: ${connection.targetId}');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

/// 图基本信息
class GraphBasicInfo {
  final String id;
  final String name;
  final String description;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const GraphBasicInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.createdAt,
    required this.modifiedAt,
  });
}

/// 图节点信息（精简版）
class GraphNodeInfo {
  final String id;
  final String title;
  final NodeType type;
  final Offset position;
  final Size size;

  const GraphNodeInfo({
    required this.id,
    required this.title,
    required this.type,
    required this.position,
    required this.size,
  });
}

/// 图连接信息
class GraphConnectionInfo {
  final String id;
  final String sourceId;
  final String targetId;
  final ConnectionType type;
  final String? label;

  const GraphConnectionInfo({
    required this.id,
    required this.sourceId,
    required this.targetId,
    required this.type,
    this.label,
  });
}

/// 图布局信息
class GraphLayoutInfo {
  final Offset offset;
  final double scale;
  final Rect bounds;

  const GraphLayoutInfo({
    required this.offset,
    required this.scale,
    required this.bounds,
  });
}

/// 图统计信息
class GraphStatistics {
  final int nodeCount;
  final int connectionCount;
  final int depth;
  final int leafNodes;

  const GraphStatistics({
    required this.nodeCount,
    required this.connectionCount,
    required this.depth,
    required this.leafNodes,
  });
}
```

### 搜索读模型

```dart
/// 搜索读模型
class SearchReadModel extends ReadModel {
  @override
  final String id;

  @override
  final DateTime lastUpdated;

  @override
  final int version;

  @override
  final ReadModelStatus status;

  /// 索引内容
  final Map<String, SearchIndexEntry> indexedContent;

  /// 标签索引
  final Map<String, Set<String>> tagIndex;

  /// 全文索引
  final FullTextIndex fullTextIndex;

  /// 搜索元数据
  final SearchMetadata searchMetadata;

  const SearchReadModel({
    required this.id,
    required this.lastUpdated,
    required this.version,
    required this.status,
    required this.indexedContent,
    required this.tagIndex,
    required this.fullTextIndex,
    required this.searchMetadata,
  });

  @override
  ValidationResult validate() {
    final errors = <String>[];

    if (indexedContent.isEmpty) {
      errors.add('Indexed content cannot be empty');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}

/// 搜索索引条目
class SearchIndexEntry {
  final String nodeId;
  final String title;
  final String content;
  final List<String> tags;
  final double relevanceScore;

  const SearchIndexEntry({
    required this.nodeId,
    required this.title,
    required this.content,
    required this.tags,
    required this.relevanceScore,
  });
}

/// 全文索引
class FullTextIndex {
  final Map<String, Set<String>> invertedIndex;
  final Map<String, int> termFrequency;

  const FullTextIndex({
    required this.invertedIndex,
    required this.termFrequency,
  });
}

/// 搜索元数据
class SearchMetadata {
  final int totalDocuments;
  final int totalTerms;
  final DateTime lastIndexed;

  const SearchMetadata({
    required this.totalDocuments,
    required this.totalTerms,
    required this.lastIndexed,
  });
}
```

### 读模型投影器实现

```dart
/// 节点读模型投影器
class NodeReadModelProjection
    implements ReadModelProjection<Node, NodeReadModel> {
  final NodeRepository _nodeRepository;
  final GraphRepository _graphRepository;

  NodeReadModelProjection({
    required NodeRepository nodeRepository,
    required GraphRepository graphRepository,
  })  : _nodeRepository = nodeRepository,
        _graphRepository = graphRepository;

  @override
  ProjectionStrategy get strategy => ProjectionStrategy.eventSourced;

  @override
  Future<NodeReadModel> project(Node writeModel) async {
    // 获取关系信息
    final graphs = await _graphRepository.getAll();
    final relationships = await _buildRelationships(writeModel.id, graphs);

    // 构建基本信息
    final basicInfo = NodeBasicInfo(
      id: writeModel.id,
      title: writeModel.title,
      type: writeModel.type,
      createdAt: writeModel.createdAt,
      modifiedAt: writeModel.modifiedAt,
    );

    // 生成内容预览
    final contentPreview = _generateContentPreview(writeModel.content);

    // 构建元数据
    final metadata = NodeReadMetadata(
      tags: writeModel.tags,
      contentLength: writeModel.content.length,
      hasChildren: relationships.childIds.isNotEmpty,
      childCount: relationships.childIds.length,
      isReferenced: relationships.referencedByIds.isNotEmpty,
      referenceCount: relationships.referencedByIds.length,
    );

    // 构建统计信息（从其他服务获取）
    final statistics = const NodeStatistics(
      totalViews: 0,
      totalEdits: 0,
    );

    return NodeReadModel(
      id: writeModel.id,
      lastUpdated: DateTime.now(),
      version: writeModel.version ?? 0,
      status: ReadModelStatus.synced,
      basicInfo: basicInfo,
      contentPreview: contentPreview,
      metadata: metadata,
      relationships: relationships,
      statistics: statistics,
    );
  }

  @override
  Future<List<NodeReadModel>> projectBatch(List<Node> writeModels) async {
    final readModels = <NodeReadModel>[];

    for (final writeModel in writeModels) {
      try {
        final readModel = await project(writeModel);
        readModels.add(readModel);
      } catch (e) {
        // 记录错误但继续处理其他模型
        debugPrint('Failed to project node ${writeModel.id}: $e');
      }
    }

    return readModels;
  }

  @override
  Future<NodeReadModel> projectIncremental(
    NodeReadModel currentReadModel,
    Node updatedWriteModel,
  ) async {
    // 只更新变化的部分
    final relationships = await _buildRelationships(
      updatedWriteModel.id,
      await _graphRepository.getAll(),
    );

    return currentReadModel.copyWith(
      lastUpdated: DateTime.now(),
      version: updatedWriteModel.version ?? 0,
      basicInfo: NodeBasicInfo(
        id: updatedWriteModel.id,
        title: updatedWriteModel.title,
        type: updatedWriteModel.type,
        createdAt: updatedWriteModel.createdAt,
        modifiedAt: updatedWriteModel.modifiedAt,
      ),
      contentPreview: _generateContentPreview(updatedWriteModel.content),
      metadata: NodeReadMetadata(
        tags: updatedWriteModel.tags,
        contentLength: updatedWriteModel.content.length,
        hasChildren: relationships.childIds.isNotEmpty,
        childCount: relationships.childIds.length,
        isReferenced: relationships.referencedByIds.isNotEmpty,
        referenceCount: relationships.referencedByIds.length,
      ),
      relationships: relationships,
    );
  }

  Future<NodeRelationships> _buildRelationships(
    String nodeId,
    List<Graph> graphs,
  ) async {
    final childIds = <String>[];
    final parentIds = <String>[];
    final referenceIds = <String>[];
    final referencedByIds = <String>[];

    for (final graph in graphs) {
      for (final reference in graph.nodeReferences) {
        if (reference.nodeId == nodeId) {
          // 当前节点是父节点
          childIds.add(reference.referenceId);
        } else if (reference.referenceId == nodeId) {
          // 当前节点是子节点
          parentIds.add(reference.nodeId);
        }
      }
    }

    // 获取节点本身的引用
    final node = await _nodeRepository.getById(nodeId);
    if (node != null) {
      // 这里可以解析内容中的引用并添加到 referenceIds
    }

    return NodeRelationships(
      childIds: childIds,
      parentIds: parentIds,
      referenceIds: referenceIds,
      referencedByIds: referencedByIds,
    );
  }

  String _generateContentPreview(String content) {
    if (content.length <= 200) {
      return content;
    }
    return '${content.substring(0, 200)}...';
  }
}
```

### 读模型同步器实现

```dart
/// 读模型同步器实现
class ReadModelSynchronizerImpl<R extends ReadModel>
    implements ReadModelSyncronizer<R> {
  final ReadModelProjection<dynamic, R> _projection;
  final ReadModelRepository<R> _repository;
  final AppEventBus _eventBus;
  final Map<String, SyncStatus> _syncStatus = {};

  ReadModelSynchronizerImpl({
    required ReadModelProjection<dynamic, R> projection,
    required ReadModelRepository<R> repository,
    required AppEventBus eventBus,
  })  : _projection = projection,
        _repository = repository,
        _eventBus = eventBus {
    _listenToEvents();
  }

  @override
  Future<void> sync(R readModel) async {
    _syncStatus[readModel.id] = SyncStatus(
      isSyncing: true,
      pendingUpdates: 0,
    );

    try {
      // 根据投影策略同步
      switch (_projection.strategy) {
        case ProjectionStrategy.realTime:
          await _syncRealTime(readModel);
          break;
        case ProjectionStrategy.eventSourced:
          await _syncEventSourced(readModel);
          break;
        case ProjectionStrategy.scheduled:
          await _syncScheduled(readModel);
          break;
        case ProjectionStrategy.onDemand:
          // 按需投影在查询时执行
          break;
      }

      _syncStatus[readModel.id] = SyncStatus(
        isSyncing: false,
        lastSyncTime: DateTime.now(),
        pendingUpdates: 0,
      );
    } catch (e) {
      _syncStatus[readModel.id] = SyncStatus(
        isSyncing: false,
        error: e.toString(),
        pendingUpdates: 0,
      );
      rethrow;
    }
  }

  @override
  Future<void> rebuild(R readModel) async {
    // 标记为需要重建
    final updatedModel = readModel.copyWith(
      status: ReadModelStatus.needsRebuild,
    );

    await _repository.save(updatedModel);
    await sync(updatedModel);
  }

  @override
  SyncStatus getSyncStatus(String readModelId) {
    return _syncStatus[readModelId] ??
        const SyncStatus(
          isSyncing: false,
          pendingUpdates: 0,
        );
  }

  @override
  Stream<WriteModelChangeEvent> get writeModelChanges => _eventBus.stream;

  Future<void> _syncRealTime(R readModel) async {
    // 实时投影逻辑
    // 通常在写操作时立即触发
  }

  Future<void> _syncEventSourced(R readModel) async {
    // 事件驱动投影逻辑
    // 监听领域事件并异步更新
  }

  Future<void> _syncScheduled(R readModel) async {
    // 定时投影逻辑
    // 按计划批量更新
  }

  void _listenToEvents() {
    _eventBus.stream.listen((event) async {
      if (event is NodeDataChangedEvent) {
        await _handleNodeChangedEvent(event);
      } else if (event is GraphNodeRelationChangedEvent) {
        await _handleGraphChangedEvent(event);
      }
    });
  }

  Future<void> _handleNodeChangedEvent(NodeDataChangedEvent event) async {
    for (final nodeId in event.changedNodes) {
      final readModel = await _repository.getById(nodeId);
      if (readModel != null) {
        await sync(readModel);
      }
    }
  }

  Future<void> _handleGraphChangedEvent(
    GraphNodeRelationChangedEvent event,
  ) async {
    // 图变化可能影响多个节点的读模型
    // 需要同步相关节点
  }

  @override
  Future<void> syncBatch(List<R> readModels) async {
    for (final readModel in readModels) {
      await sync(readModel);
    }
  }
}
```

## 核心算法

### 1. 增量投影算法

**问题描述**：当写模型更新时，只更新读模型中变化的部分，而不是完全重建读模型。

**算法描述**：
1. 比较写模型和当前读模型的版本号
2. 识别变化的字段（使用字段级版本控制或哈希比较）
3. 只更新变化的字段
4. 重新计算依赖字段（如统计信息、关系信息）

**伪代码**：
```
function projectIncremental(currentReadModel, updatedWriteModel):
    if updatedWriteModel.version <= currentReadModel.version:
        return currentReadModel  // 无需更新

    changedFields = identifyChangedFields(currentReadModel, updatedWriteModel)

    updatedReadModel = currentReadModel.copy()

    for field in changedFields:
        if field is RELATIONSHIP_FIELD:
            updatedReadModel.field = rebuildRelationships(updatedWriteModel)
        else if field is DERIVED_FIELD:
            updatedReadModel.field = recalculateDerivedField(updatedWriteModel)
        else:
            updatedReadModel.field = updatedWriteModel.field

    updatedReadModel.version = updatedWriteModel.version
    updatedReadModel.lastUpdated = now()

    return updatedReadModel
```

**复杂度分析**：
- 时间复杂度：O(n)，其中 n 是字段数量
- 空间复杂度：O(1)

### 2. 关系信息构建算法

**问题描述**：从图数据中构建节点的关系信息（父子关系、引用关系）。

**算法描述**：
1. 遍历所有图
2. 对每个图的每个节点引用进行分析
3. 如果引用的目标节点是当前节点，则记录为父节点
4. 如果引用的源节点是当前节点，则记录为子节点
5. 聚合所有关系并去重

**伪代码**：
```
function buildRelationships(nodeId, graphs):
    childIds = Set()
    parentIds = Set()
    referenceIds = Set()
    referencedByIds = Set()

    for graph in graphs:
        for reference in graph.nodeReferences:
            if reference.nodeId == nodeId:
                childIds.add(reference.referenceId)
            else if reference.referenceId == nodeId:
                parentIds.add(reference.nodeId)

    // 解析节点内容中的引用
    node = getNode(nodeId)
    references = extractReferences(node.content)
    for ref in references:
        referenceIds.add(ref)
        referencedBy = findNodesThatReference(nodeId)
        referencedByIds.addAll(referencedBy)

    return NodeRelationships(
        childIds: childIds.toList(),
        parentIds: parentIds.toList(),
        referenceIds: referenceIds.toList(),
        referencedByIds: referencedByIds.toList(),
    )
```

**复杂度分析**：
- 时间复杂度：O(g × n)，其中 g 是图数量，n 是每个图的节点引用数量
- 空间复杂度：O(r)，其中 r 是关系数量

### 3. 读模型重建算法

**问题描述**：当读模型损坏或数据不一致时，完全重建读模型。

**算法描述**：
1. 从写模型获取最新数据
2. 清除当前读模型数据
3. 重新执行投影逻辑
4. 验证重建后的读模型
5. 保存并更新状态

**伪代码**：
```
function rebuildReadModel(readModelId):
    // 1. 获取写模型数据
    writeModel = getWriteModel(readModelId)
    if writeModel == null:
        throw ModelNotFoundException

    // 2. 标记为重建中
    currentReadModel = getReadModel(readModelId)
    currentReadModel.status = ReadModelStatus.syncing
    save(currentReadModel)

    // 3. 完全投影
    newReadModel = projection.project(writeModel)
    newReadModel.status = ReadModelStatus.syncing
    save(newReadModel)

    // 4. 验证
    validation = newReadModel.validate()
    if not validation.isValid:
        newReadModel.status = ReadModelStatus.syncFailed
        save(newReadModel)
        throw ValidationException(validation.errors)

    // 5. 完成重建
    newReadModel.status = ReadModelStatus.synced
    save(newReadModel)

    return newReadModel
```

**复杂度分析**：
- 时间复杂度：O(n)，取决于投影逻辑的复杂度
- 空间复杂度：O(n)，需要存储新的读模型

### 4. 多读模型协调算法

**问题描述**：当写模型更新时，协调多个相关读模型的更新，确保一致性。

**算法描述**：
1. 识别受影响的读模型
2. 按依赖关系排序读模型
3. 依次更新每个读模型
4. 处理更新失败的情况
5. 重试失败的更新

**伪代码**：
```
function coordinateReadModels(writeModelChangeEvent):
    // 1. 识别受影响的读模型
    affectedModels = identifyAffectedModels(writeModelChangeEvent)

    // 2. 按依赖关系排序
    sortedModels = topologicalSort(affectedModels)

    // 3. 依次更新
    failedModels = []
    for model in sortedModels:
        try:
            sync(model)
        except e:
            failedModels.add((model, e))

    // 4. 处理失败
    if failedModels.isNotEmpty:
        // 回滚已更新的模型
        for model in reversed(sortedModels):
            if model not in failedModels:
                rollback(model)

        // 重试或报告错误
        throw CoordinationException(failedModels)
```

**复杂度分析**：
- 时间复杂度：O(m × n)，其中 m 是读模型数量，n 是平均同步时间
- 空间复杂度：O(m)

## 性能考虑

### 概念性能指标

1. **投影性能**：
   - 单个节点投影：< 10ms
   - 批量投影（100个节点）：< 500ms
   - 增量投影：< 5ms

2. **同步性能**：
   - 实时同步延迟：< 100ms
   - 事件驱动同步延迟：< 1s
   - 批量同步（1000个模型）：< 5s

3. **存储开销**：
   - 读模型/写模型存储比：1.2-1.5
   - 内存占用（1000个节点）：50-100 MB
   - 磁盘占用：读模型占存储的 20-30%

4. **查询性能**：
   - 基于读模型的查询比直接查询快 5-10 倍
   - 复杂查询（多表 JOIN）：快 10-50 倍

### 性能优化策略

1. **选择性投影**：
   - 只投影查询需要的字段
   - 延迟加载不常用的数据
   - 使用字段级版本控制

2. **批量处理**：
   - 批量投影和同步
   - 使用事务批量更新
   - 并行处理独立的读模型

3. **缓存策略**：
   - 缓存读模型数据
   - 使用内存缓存加速访问
   - 实现智能缓存预热

4. **索引优化**：
   - 为读模型添加专用索引
   - 优化关系数据的查询
   - 使用全文索引加速搜索

5. **增量更新**：
   - 优先使用增量投影
   - 减少全量重建
   - 实现字段级更新

## 关键文件列表

### 核心实现文件

1. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\read_model.dart**
   - ReadModel 基类定义
   - ReadModelStatus 枚举
   - ValidationResult 类

2. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\projection.dart**
   - ReadModelProjection 接口
   - ProjectionStrategy 枚举
   - 投影器基类

3. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\synchronizer.dart**
   - ReadModelSynchronizer 接口
   - SyncStatus 类
   - 同步器实现

4. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\repository.dart**
   - ReadModelRepository 接口
   - ReadModelQuery 类
   - 仓储实现

### 具体读模型文件

5. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\node_read_model.dart**
   - NodeReadModel 类
   - NodeBasicInfo、NodeReadMetadata 等数据类
   - 节点读模型相关方法

6. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\graph_read_model.dart**
   - GraphReadModel 类
   - GraphNodeInfo、GraphConnectionInfo 等数据类
   - 图读模型相关方法

7. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\search_read_model.dart**
   - SearchReadModel 类
   - SearchIndexEntry、FullTextIndex 等数据类
   - 搜索读模型相关方法

### 投影器文件

8. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\projections\node_projection.dart**
   - NodeReadModelProjection 实现
   - 节点投影逻辑
   - 关系信息构建

9. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\projections\graph_projection.dart**
   - GraphReadModelProjection 实现
   - 图投影逻辑
   - 布局信息计算

10. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\projections\search_projection.dart**
    - SearchReadModelProjection 实现
    - 搜索索引构建
    - 全文索引维护

### 同步器文件

11. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\synchronizers\node_synchronizer.dart**
    - 节点读模型同步器
    - 事件监听和处理
    - 同步状态管理

12. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\synchronizers\graph_synchronizer.dart**
    - 图读模型同步器
    - 批量同步逻辑

13. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\synchronizers\search_synchronizer.dart**
    - 搜索读模型同步器
    - 索引更新逻辑

### 仓储实现文件

14. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\repositories\node_read_model_repository.dart**
    - 节点读模型仓储实现
    - 文件存储或数据库存储

15. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\repositories\graph_read_model_repository.dart**
    - 图读模型仓储实现

16. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\repositories\search_read_model_repository.dart**
    - 搜索读模型仓储实现

### 配置和工具文件

17. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\read_model_config.dart**
    - 读模型配置
    - 投影策略配置
    - 同步策略配置

18. **D:\Projects\node_graph_notebook\lib\core\cqrs\read_models\read_model_validator.dart**
    - 读模型验证器
    - 数据一致性检查

### 测试文件

19. **D:\Projects\node_graph_notebook\test\core\cqrs\read_models\projection_test.dart**
    - 投影器单元测试
    - 增量投影测试

20. **D:\Projects\node_graph_notebook\test\core\cqrs\read_models\synchronizer_test.dart**
    - 同步器单元测试
    - 事件处理测试

21. **D:\Projects\node_graph_notebook\test\core\cqrs\read_models\repository_test.dart**
    - 仓储单元测试
    - 查询性能测试

### 集成文件

22. **D:\Projects\node_graph_notebook\lib\app.dart**
    - 注册读模型组件
    - 配置依赖注入

23. **D:\Projects\node_graph_notebook\lib\core\events\event_integration.dart**
    - 领域事件与读模型同步的集成
    - 事件监听器配置
