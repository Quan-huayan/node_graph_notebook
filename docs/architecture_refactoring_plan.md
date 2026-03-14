# Node Graph Notebook - 创新插件化架构重构计划

## 背景

当前 Node Graph Notebook 采用传统的 Clean Architecture，虽然架构清晰，但存在以下限制：
- 插件系统仅限于 GraphBloc，扩展性差
- Repository 层无并发控制，性能瓶颈明显
- 缺乏统一的数据抽象层
- 文件系统存储方式限制了数据关系的高效查询

## 核心创新

本方案将应用程序重构为**以 Command 为核心的高性能图数据库系统**，结合：
1. **自定义图数据库** - 基于节点/图的原生存储引擎
2. **混合并发模型** - I/O 异步 + CPU Isolate + GPU/NPU 加速
3. **CQRS 架构** - 命令查询分离，读写优化
4. **中间件插件系统** - Command 管道 + UI Hook 封装

---

## 架构设计

### 整体架构图

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│                   (BLoC + UI Widgets)                        │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Command Bus (CQRS)                        │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Middleware Pipeline (Plugin Hooks)           │  │
│  │  Validation → Auth → Transform → Execute → Effects  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                Execution Engine (Hybrid)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ I/O Executor │  │CPU Executor  │  │GPU Executor  │     │
│  │(async/await) │  │  (Isolate)   │  │(WebGPU/OpenCL)│     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              Graph Database Engine (Custom)                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │ Node Storage │  │Edge Storage  │  │Index Manager │     │
│  │  (B+ Tree)   │  │(Adjacency)   │  │(Multi-level)│     │
│  └──────────────┘  └──────────────┘  └──────────────┘     │
│  ┌──────────────┐  ┌──────────────┐                       │
│  │  Cache Layer │  │ Versioning   │                       │
│  │   (LRU)      │  │  (MVCC)      │                       │
│  └──────────────┘  └──────────────┘                       │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Query Bus (CQRS)                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         Materialized Views (Read Models)             │  │
│  │  - GraphView  - IndexView  - CacheView               │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## 核心组件设计

### 1. Command Bus (命令总线)

**职责**：所有写操作的统一入口，通过中间件管道实现插件扩展

**核心接口**：
```dart
abstract class Command {
  String get id;
  CommandType get type;
  CommandPriority get priority;
  CommandMetadata get metadata;

  Future<CommandResult> execute(CommandContext context);
  Future<void> undo(CommandContext context);
  Command? merge(Command other); // 批量优化
}

class CommandResult {
  final bool success;
  final dynamic data;
  final List<DomainEvent> events; // 驱动 Read Model 更新
  final Duration executionTime;
  final String? error;
}
```

**中间件管道**：
```dart
abstract class CommandMiddleware {
  MiddlewarePhase get phase;  // 阶段
  int get priority;           // 优先级

  Future<CommandContext> process(
    Command command,
    CommandContext context,
    NextMiddleware next,
  );
}

enum MiddlewarePhase {
  validation,      // 插件：数据验证规则
  authorization,   // 插件：权限控制
  transformation,  // 插件：命令转换
  execution,       // 核心执行逻辑
  postProcessing,  // 插件：副作用处理
}
```

**关键文件**：
- `lib/core/commands/command_bus.dart`
- `lib/core/commands/command_middleware.dart`
- `lib/core/commands/command_context.dart`

---

### 2. 图数据库引擎

**核心设计哲学**：引用驱动的可见性系统（类似文件系统 + Git）

**关键特性**：
- **存储分离**：节点内容在文件系统（Markdown），元数据在数据库
- **引用驱动**：数据流通过节点引用传播，可见性 = 传递闭包
- **极高读写**：Hash 索引优化，无需复杂查询
- **千万级规模**：图分区 + 矩阵压缩

**存储架构**：
```
┌─────────────────────────────────────────────────────────┐
│  文件系统层（节点内容）                                    │
│  data/nodes/{id}.md  ← 人类可读，版本控制友好              │
└─────────────────────────────────────────────────────────┘
                          ↑
                          │ 元数据引用
                          ↓
┌─────────────────────────────────────────────────────────┐
│  图数据库层（单文件 database.db）                          │
│  ┌───────────────────────────────────────────────────┐  │
│  │  WAL 日志（Write-Ahead Log）                       │  │
│  │  - 写操作持久化                                      │  │
│  │  - 崩溃恢复                                          │  │
│  │  - 异步刷新到主存储                                  │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  MemTable（内存表）                                 │  │
│  │  - Hash 索引（O(1) 查找）                           │  │
│  │  - 前向引用（outgoing edges）                       │  │
│  │  - 反向引用索引（incoming edges）                  │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  SSTable（排序字符串表）                            │  │
│  │  - 持久化存储                                       │  │
│  │  - Append-only（追加写）                            │  │
│  │  - 版本历史                                         │  │
│  └───────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────┐  │
│  │  图分区索引                                         │  │
│  │  - 分区内的可达性矩阵（压缩）                        │  │
│  │  - 完全图压缩（clique detection）                  │  │
│  │  - 跨分区边界索引                                   │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

#### 2.1 存储引擎（LSM Tree 架构）

```dart
class GraphStorageEngine {
  // WAL 日志（Write-Ahead Log）
  final WriteAheadLog _wal;

  // MemTable（内存表，Hash 索引）
  final MemTable _memTable;

  // SSTable（磁盘表，Immutable）
  final List<SSTable> _sstables;

  // 写操作流程
  Future<void> write(WriteCommand cmd) async {
    // 1. 先写 WAL（持久化）
    await _wal.append(cmd);

    // 2. 更新 MemTable（Hash 索引，O(1)）
    _memTable.apply(cmd);

    // 3. 异步刷新到磁盘
    if (_memTable.size > _flushThreshold) {
      await _flushMemTable();
    }
  }

  // 读操作流程
  Future<NodeMetadata> read(String nodeId) async {
    // 1. 先查 MemTable（最新数据）
    final memResult = _memTable.get(nodeId);
    if (memResult != null) return memResult;

    // 2. 查 SSTable（布隆过滤器优化）
    for (final sstable in _sstables) {
      if (await sstable.mayContain(nodeId)) {
        final result = await sstable.get(nodeId);
        if (result != null) return result;
      }
    }

    throw NodeNotFoundException(nodeId);
  }

  // 后台刷新
  Future<void> _flushMemTable() async {
    final snapshot = _memTable.snapshot();
    final sstable = await SSTable.create(snapshot);
    _sstables.insert(0, sstable); // 最新的在前
    _memTable.clear();
    await _wal.advanceCheckpoint();
  }
}
```

#### 2.2 引用存储（前向 + 反向分离）

```dart
class ReferenceStorage {
  // 前向引用（节点直接引用的节点）
  final Map<String, Set<String>> _outgoingEdges;

  // 反向引用索引（引用当前节点的节点）
  final Map<String, Set<String>> _incomingEdges;

  // 添加引用
  Future<void> addReference(String from, String to) async {
    // 原子性更新
    await _storage.write(UpdateReferencesCommand(
      from: from,
      to: to,
      action: ReferenceAction.add,
    ));
  }

  // 获取前向引用
  Set<String> getOutgoing(String nodeId) {
    return _outgoingEdges[nodeId] ?? {};
  }

  // 获取反向引用
  Set<String> getIncoming(String nodeId) {
    return _incomingEdges[nodeId] ?? {};
  }

  // 可见性计算（引用树的传递闭包）
  Future<Set<String>> getReachableNodes(String startNode, {int maxDepth = 100}) async {
    final reachable = <String>{};
    final queue = Queue<String>.from([startNode]);
    final visited = <String>{startNode};

    while (queue.isNotEmpty && visited.length < maxDepth) {
      final current = queue.removeFirst();
      reachable.add(current);

      // 获取前向引用
      final outgoing = getOutgoing(current);
      for (final next in outgoing) {
        if (!visited.contains(next)) {
          visited.add(next);
          queue.add(next);
        }
      }
    }

    return reachable;
  }
}
```

#### 2.3 图分区与可达性矩阵

```dart
class GraphPartitioner {
  // 图分区（将大图分成社区/子图）
  final Map<String, GraphPartition> _partitions;

  // 节点到分区的映射
  final Map<String, String> _nodeToPartition;

  // 完全图检测器
  final CliqueDetector _cliqueDetector;

  // 获取可达性（分区级预计算）
  Future<bool> canReach(String from, String to) async {
    final fromPartition = _nodeToPartition[from];
    final toPartition = _nodeToPartition[to];

    // 同一分区：使用预计算矩阵
    if (fromPartition == toPartition) {
      return _partitions[fromPartition]!
          .reachabilityMatrix
          .isReachable(from, to);
    }

    // 跨分区：查找边界桥接
    return await _findCrossPartitionPath(from, to);
  }

  // 图分区算法（社区发现）
  Future<void> partitionGraph() async {
    final communities = await _detectCommunities();
    for (final community in communities) {
      final partition = await _createPartition(community);
      _partitions[partition.id] = partition;
    }
  }
}

// 图分区
class GraphPartition {
  final String id;
  final Set<String> nodes;
  final CompressedReachabilityMatrix reachabilityMatrix;
  final Set<Clique> cliques; // 完全图优化

  GraphPartition({
    required this.id,
    required this.nodes,
    required this.reachabilityMatrix,
    required this.cliques,
  });
}

// 压缩的可达性矩阵
class CompressedReachabilityMatrix {
  // 使用 Bitset 压缩存储
  final Map<String, BitSet> _rowMatrix;

  // 完全图优化（所有节点互相可达）
  final Set<Clique> _cliques;

  bool isReachable(String from, String to) {
    // 1. 检查是否在同一个完全图中
    for (final clique in _cliques) {
      if (clique.contains(from) && clique.contains(to)) {
        return true; // O(1)
      }
    }

    // 2. 查询矩阵
    final row = _rowMatrix[from];
    return row?.get(to) ?? false;
  }
}

// 完全图（稠密子图优化）
class Clique {
  final Set<String> nodes;
  final String id;

  Clique(this.nodes) : id = _generateId();

  bool contains(String node) => nodes.contains(node);

  // 完全图中所有节点互相可达
  bool canReach(String from, String to) {
    return nodes.contains(from) && nodes.contains(to);
  }
}
```

#### 2.4 版本控制（Append-only）

```dart
class VersionManager {
  // Append-only 存储
  final List<NodeVersion> _versions;

  // 当前版本指针
  final Map<String, int> _currentVersions;

  // 保存新版本
  Future<void> saveVersion(NodeMetadata node) async {
    final version = NodeVersion(
      id: node.id,
      version: _getNextVersion(node.id),
      data: node,
      timestamp: DateTime.now(),
    );

    _versions.add(version);
    _currentVersions[node.id] = version.version;

    // 可选：清理旧版本
    await _maybeCleanupOldVersions(node.id);
  }

  // 获取当前版本
  Future<NodeMetadata> getCurrent(String nodeId) async {
    final versionIndex = _currentVersions[nodeId];
    if (versionIndex == null) throw NodeNotFoundException(nodeId);

    return _versions[versionIndex].data;
  }

  // 清理旧版本
  Future<void> clearHistory(String nodeId) async {
    final currentIndex = _currentVersions[nodeId];
    if (currentIndex == null) return;

    // 保留当前版本，删除其他
    _versions.removeWhere((v) => v.id == nodeId && v.version != currentIndex);
  }
}
```

#### 2.5 并发控制（简化版 MVCC）

```dart
class ConcurrencyManager {
  // 写操作串行化（单写者）
  final Queue<Future<CommandResult> Function()> _writeQueue = Queue();
  bool _isWriting = false;

  // 读操作无锁
  Future<T> read<T>(Future<T> Function() operation) async {
    // 直接执行，无需加锁
    return await operation();
  }

  // 写操作按序执行
  Future<T> write<T>(Future<T> Function() operation) async {
    final completer = Completer<T>();

    _writeQueue.add(() async {
      final result = await operation();
      completer.complete(result);
      return result;
    });

    await _processWriteQueue();

    return completer.future;
  }

  Future<void> _processWriteQueue() async {
    if (_isWriting || _writeQueue.isEmpty) return;

    _isWriting = true;
    while (_writeQueue.isNotEmpty) {
      final operation = _writeQueue.removeFirst();
      await operation();
    }
    _isWriting = false;
  }
}
```

**关键文件**：
- `lib/core/database/storage_engine.dart`
- `lib/core/database/reference_storage.dart`
- `lib/core/database/partitioner.dart`
- `lib/core/database/version_manager.dart`
- `lib/core/database/concurrency_manager.dart`

---

### 3. 混合执行引擎

**职责**：根据操作类型智能分配执行资源

**执行策略**：
```dart
class ExecutionEngine {
  // I/O 执行器 (async/await)
  final IOExecutor _ioExecutor;

  // CPU 执行器 (Isolate 池)
  final CPUExecutor _cpuExecutor;

  // GPU 执行器 (WebGPU/OpenCL)
  final GPUExecutor _gpuExecutor;

  Future<T> execute<T>(Command command) {
    // 智能路由
    if (_isIOHeavy(command)) {
      return _ioExecutor.execute(command);
    } else if (_isCPUHeavy(command)) {
      return _cpuExecutor.execute(command);
    } else if (_isGPUSuitable(command)) {
      return _gpuExecutor.execute(command);
    }
  }
}
```

**GPU/NPU 加速场景**：
- 图布局算法 (力导向、层次布局)
- 图遍历 (BFS/DFS 并行)
- 社区发现算法
- AI 推理 (节点分类、关系预测)

**关键文件**：
- `lib/core/execution/execution_engine.dart`
- `lib/core/execution/io_executor.dart`
- `lib/core/execution/cpu_executor.dart`
- `lib/core/execution/gpu_executor.dart`

---

### 4. Query Bus (查询总线)

**职责**：CQRS 读侧，物化视图优化查询性能

**核心设计**：
```dart
abstract class Query<T> {
  String get id;
  Type get resultType;
}

abstract class ReadModel {
  void apply(DomainEvent event); // 事件更新
  Map<String, dynamic> get state;
}

// 物化视图示例
class GraphReadModel extends ReadModel {
  final Map<String, Set<String>> _adjacencyView;

  @override
  void apply(DomainEvent event) {
    if (event is NodeCreatedEvent) {
      _updateView(event.node);
    }
  }

  // O(1) 查询
  Set<String> getNeighbors(String nodeId) => _adjacencyView[nodeId] ?? {};
}
```

**关键文件**：
- `lib/core/queries/query_bus.dart`
- `lib/core/queries/read_models/`
- `lib/core/queries/materialized_views.dart`

---

### 5. 插件系统

**职责**：通过中间件和 Hook 实现功能扩展

#### 5.1 核心中间件插件
```dart
abstract class Plugin {
  PluginDescriptor get descriptor;

  // 中间件扩展点
  List<CommandMiddleware> getMiddleware(CommandType type);

  // 生命周期
  Future<void> initialize(PluginContext context);
  Future<void> dispose();
}

// 示例：验证插件
class ValidationPlugin extends Plugin {
  @override
  List<CommandMiddleware> getMiddleware(CommandType type) {
    if (type == CommandType.createNode) {
      return [
        NodeTitleValidationMiddleware(),
        NodeContentValidationMiddleware(),
      ];
    }
    return [];
  }
}
```

#### 5.2 UI Hook 封装
```dart
// UI 层简化接口
class UIHookRegistry {
  // 插件注册 UI 钩子
  void registerHook(String hookName, UIHook hook);

  // 触发钩子
  Future<dynamic> triggerHook(String hookName, Map<String, dynamic> data);
}

// 示例：节点右键菜单 Hook
class NodeContextMenuHook extends UIHook {
  @override
  List<MenuItem> getMenuItems(Node node) {
    return [
      MenuItem(label: 'AI 分析', action: () => _analyzeWithAI(node)),
      MenuItem(label: '导出 Markdown', action: () => _export(node)),
    ];
  }
}
```

**关键文件**：
- `lib/plugins/plugin_registry.dart`
- `lib/plugins/plugin_context.dart`
- `lib/plugins/middleware/`
- `lib/plugins/ui_hooks.dart`

---

## 实现路线图

### 阶段 1: 核心基础设施 (4-5 周)

**目标**：建立 Command Bus 和图数据库存储引擎

**任务**：
1. **Command Bus 实现**
   - 实现命令总线核心逻辑
   - 实现中间件管道
   - 实现 CommandContext
   - 编写中间件测试

2. **图数据库存储引擎**
   - 实现 WAL（Write-Ahead Log）
   - 实现 MemTable（Hash 索引）
   - 实现 SSTable（Immutable 存储）
   - 实现异步刷新机制
   - 实现布隆过滤器优化

3. **引用存储系统**
   - 实现前向引用存储
   - 实现反向引用索引
   - 实现引用树遍历
   - 实现传递闭包计算（基础版）

4. **版本控制**
   - 实现 Append-only 存储
   - 实现版本链管理
   - 实现历史清理功能

5. **并发控制**
   - 实现写操作队列（串行化）
   - 实现读操作无锁机制
   - 并发安全测试

**交付物**：
- `lib/core/commands/` (完整实现)
- `lib/core/database/storage_engine.dart`
- `lib/core/database/reference_storage.dart`
- `lib/core/database/version_manager.dart`
- `lib/core/database/concurrency_manager.dart`
- `test/core/commands/` (测试)
- `test/core/database/` (测试)
- 性能基准测试报告

---

### 阶段 2: 执行引擎和并发 (2-3 周)

**目标**：实现混合执行引擎

**任务**：
1. 实现 IO 执行器 (async/await)
2. 实现 CPU 执行器 (Isolate 池)
3. 实现 GPU 执行器 (WebGPU/OpenCL)
4. 实现智能路由逻辑
5. 性能基准测试
6. 并发压力测试

**交付物**：
- `lib/core/execution/` (完整实现)
- `benchmark/concurrency_test.dart`
- 性能测试报告

---

### 阶段 2: 图分区与可达性优化 (3-4 周)

**目标**：实现图分区和预计算可达性矩阵

**任务**：
1. **图分区算法**
   - 实现社区发现算法（Louvain 方法）
   - 实现图分区策略
   - 实现分区管理器
   - 实现跨分区边界索引

2. **完全图检测与压缩**
   - 实现完全图检测算法（Clique Detection）
   - 实现完全图压缩存储
   - 实现压缩可达性查询

3. **可达性矩阵预计算**
   - 实现分区级可达性矩阵
   - 实现矩阵压缩（Bitset + 完全图优化）
   - 实现矩阵增量更新
   - 实现跨分区路径查找

4. **GPU 加速（可选）**
   - 实现 GPU 图遍历着色器（WebGPU/OpenCL）
   - 实现 GPU 并行 BFS/DFS
   - 实现社区发现的 GPU 加速
   - 性能对比测试

5. **缓存优化**
   - 实现分区级缓存
   - 实现热点节点预取
   - 实现 LRU 缓存淘汰策略

**交付物**：
- `lib/core/database/partitioner.dart`
- `lib/core/database/reachability_matrix.dart`
- `lib/core/database/clique_detector.dart`
- `lib/core/execution/gpu_executor.dart`（可选）
- `lib/core/database/cache_manager.dart`
- 性能测试报告（分区效果、矩阵压缩率）
- GPU 加速效果报告

**成功指标**：
- 分区内可达性查询 < 5ms
- 跨分区查询 < 20ms
- 矩阵压缩率 > 90%
- 完全图识别率 > 80%（理想图结构）

---

### 阶段 3: Query Bus 和 CQRS (2 周)

**目标**：实现查询优化和物化视图

**任务**：
1. 实现 Query Bus
2. 实现核心 Read Model
3. 实现物化视图
4. 实现查询缓存
5. 事件驱动更新机制
6. 查询性能测试

**交付物**：
- `lib/core/queries/` (完整实现)
- `test/core/queries/` (测试)

---

### 阶段 4: 插件系统 (2-3 周)

**目标**：实现中间件和 UI Hook 系统

**任务**：
1. 实现插件注册表
2. 实现插件上下文
3. 实现中间件插件接口
4. 实现 UI Hook 系统
5. 插件生命周期管理
6. 迁移现有插件到新系统

**交付物**：
- `lib/plugins/` (新系统)
- `plugins/example/` (示例插件)
- 插件开发文档

---

### 阶段 5: Service 层迁移 (2-3 周)

**目标**：将现有 Service 层迁移到 Command 完全接管

**任务**：
1. 创建 NodeService 适配器
2. 创建 GraphService 适配器
3. 创建 LayoutService 适配器
4. 更新 BLoC 层使用 Command Bus
5. 更新 UI 层适配
6. 集成测试

**交付物**：
- `lib/core/services/adapters/`
- 更新的 `lib/bloc/`
- 更新的 `lib/ui/`
- `test/integration/` (集成测试)

---

### 阶段 6: 性能优化和测试 (2 周)

**目标**：优化性能，确保稳定性

**任务**：
1. 数据库查询优化
2. 缓存策略优化
3. 并发性能调优
4. 内存优化
5. 压力测试
6. 错误处理完善

**交付物**：
- 性能优化报告
- 压力测试报告
- 错误处理文档

---

### 阶段 7: 文档和发布 (1 周)

**目标**：完善文档，准备发布

**任务**：
1. 编写架构文档
2. 编写 API 参考文档
3. 编写插件开发指南
4. 编写迁移指南
5. 创建示例项目
6. 发布 v2.0.0

**交付物**：
- `docs/architecture.md`
- `docs/api_reference.md`
- `docs/plugin_guide.md`
- `docs/migration_guide.md`
- `plugin_template/`

---

## 关键技术决策

### 1. 数据库设计

**选择**：基于引用驱动的图数据库 + 文件系统混合存储

**核心创新**：
- **引用驱动可见性**：数据流通过节点引用传播（类似 Git + 文件系统）
- **存储分离**：节点内容在文件系统（Markdown），元数据在图数据库
- **图分区优化**：分区级预计算可达性矩阵 + 完全图压缩
- **LSM Tree 架构**：WAL + MemTable + SSTable（极高读写性能）

**关键指标**：
- 目标规模：千万级节点
- 读写性能：Hash 索引 O(1) 查找
- 可达性查询：分区级预计算，接近 O(1)
- 历史版本：Append-only，支持清理

**备选方案**：
- Neo4j (功能强大但依赖外部服务，不适合千万级本地存储)
- SQLite (非图原生，关系查询效率低)
- 纯文件系统 (当前方案，缺少索引和关系优化)

---

### 2. 并发模型

**选择**：混合模式 (async/await + Isolate + GPU/NPU)

**设计理念**：
- **I/O 操作**：async/await（文件读写、网络请求）
- **CPU 密集型**：Isolate 池（图算法、布局计算、AI 推理）
- **图算法加速**：GPU/NPU 计算着色器（并行遍历、社区发现）
- **写操作**：串行化队列（单写者设计，避免冲突）
- **读操作**：无锁（MVCC，多读不冲突）

**关键优势**：
- 真正的并行计算（多核 Isolate + GPU）
- 简化的并发控制（写操作串行化）
- 高性能图算法（GPU 加速）

**备选方案**：
- 纯 async/await（无法利用多核，不适合千万级数据）
- 纯 Isolate（实现复杂，I/O 操作效率低）

---

### 3. 插件扩展方式

**选择**：中间件管道 + UI Hook
**原因**：
- 核心用中间件 (灵活强大)
- UI 用 Hook (简单易用)
- 兼顾灵活性和易用性

**备选方案**：
- 纯中间件 (学习曲线陡)
- 纯 Hook (扩展性受限)

---

### 4. Command 层职责

**选择**：完全接管
**原因**：
- 架构最清晰
- 统一的操作入口
- 易于审计和调试
- 插件扩展最简单

**备选方案**：
- 渐进式迁移 (架构冗余)
- 混合模式 (复杂度高)

---

## 风险与挑战

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 数据库实现复杂度 | 高 | 分阶段实现，先简后繁 |
| GPU 加速兼容性 | 中 | 提供 fallback 到 CPU |
| 并发控制难度 | 高 | 使用成熟的锁机制 |
| 迁移成本 | 高 | 适配器模式，兼容旧接口 |
| 性能不达标 | 中 | 性能测试驱动，持续优化 |

---

## 成功指标

### 技术指标
- **千万级节点支持**：支持 10,000,000+ 节点的存储和查询
- **节点查询延迟**：< 1ms（Hash 索引，内存缓存）
- **可达性查询**：< 10ms（分区级预计算矩阵）
- **图遍历性能**：GPU 加速后 > 100x 提升
- **写入吞吐量**：> 10,000 ops/s（串行化写操作）
- **并发读取**：无锁设计，线性扩展
- **内存占用**：< 1GB（100 万节点，含缓存）
- **启动时间**：< 3s（索引加载）

### 性能基准
- **小规模**（< 10K 节点）：启动 < 1s，查询 < 1ms
- **中规模**（10K-100K 节点）：启动 < 2s，查询 < 5ms
- **大规模**（100K-1M 节点）：启动 < 3s，查询 < 10ms
- **超大规模**（1M-10M 节点）：启动 < 5s，查询 < 20ms

### 开发者指标
- 插件开发时间 < 2 小时
- API 学习曲线 < 1 天
- 示例插件 > 5 个

### 用户指标
- 应用启动时间 < 2s
- 大文件加载时间 < 5s
- 崩溃率 < 0.01%

---

## 关键文件清单

### 新增核心文件
- `lib/core/commands/command_bus.dart`
- `lib/core/commands/command_middleware.dart`
- `lib/core/execution/execution_engine.dart`
- `lib/core/database/storage_engine.dart` (LSM Tree: WAL + MemTable + SSTable)
- `lib/core/database/reference_storage.dart` (前向 + 反向引用)
- `lib/core/database/partitioner.dart` (图分区算法)
- `lib/core/database/reachability_matrix.dart` (可达性矩阵压缩)
- `lib/core/database/clique_detector.dart` (完全图检测)
- `lib/core/database/version_manager.dart` (Append-only 版本控制)
- `lib/core/database/concurrency_manager.dart` (简化版 MVCC)
- `lib/core/database/cache_manager.dart` (分区级缓存)
- `lib/core/queries/query_bus.dart`
- `lib/plugins/plugin_registry.dart`
- `lib/plugins/ui_hooks.dart`

### 修改现有文件
- `lib/app.dart` (依赖注入)
- `lib/bloc/node_bloc.dart` (使用 Command Bus)
- `lib/bloc/graph_bloc.dart` (使用 Command Bus)
- `lib/core/services/node_service.dart` (适配器)
- `lib/core/services/graph_service.dart` (适配器)

### 删除文件
- `lib/plugins/hooks/graph_plugin.dart` (旧插件系统)
- `lib/core/repositories/node_repository.dart` (被图数据库引擎取代)
- `lib/core/repositories/graph_repository.dart` (被图数据库引擎取代)
- `lib/core/repositories/file_system_node_repository.dart` (被图数据库引擎取代)
- `lib/core/repositories/file_system_graph_repository.dart` (被图数据库引擎取代)

---

## 验证计划

### 单元测试
- Command Bus 中间件管道测试
- 数据库 CRUD 操作测试
- 索引性能测试
- 并发安全测试

### 集成测试
- Command → Database 端到端测试
- 插件系统集成测试
- UI → Command 集成测试

### 性能测试
- 查询延迟测试
- 并发吞吐量测试
- 内存占用测试
- GPU 加速效果测试

### 压力测试
- **小规模**：10,000 节点加载和查询测试
- **中规模**：100,000 节点加载和查询测试
- **大规模**：1,000,000 节点加载和查询测试
- **超大规模**：10,000,000 节点加载和查询测试
- 并发写入测试（验证串行化队列）
- 长时间运行稳定性测试（24 小时）
- 内存泄漏测试
- 图分区效果测试（压缩率、查询性能）

---

## 参考资源

- **图数据库**: Neo4j, ArangoDB
- **并发模型**: Actor Model, CSP
- **CQRS**: Domain-Driven Design
- **中间件模式**: Express.js, Redux
- **GPU 加速**: WebGPU, OpenCL

---

## 核心创新总结

本架构的三大核心创新：

### 1. 引用驱动的图数据库

**创新点**：类似 Git + 文件系统的设计哲学
- 节点的可见性由其引用树决定（传递闭包）
- 数据流通过引用关系传播，而非全局查询
- 天然的安全边界和访问控制

**实现**：
- 前向引用 + 反向索引分离存储
- 图分区 + 预计算可达性矩阵
- 完全图压缩优化
- 目标：千万级节点的高效存储和查询

### 2. Command-First 架构

**创新点**：所有操作通过 Command 执行，插件通过中间件注入行为
- 统一的操作入口和审计
- 插件无需修改核心代码
- 中间件管道提供灵活的扩展点

**实现**：
- Command Bus 中间件管道
- Validation → Auth → Transform → Execute → Effects
- UI Hook 封装简化插件开发

### 3. 混合并发执行引擎

**创新点**：智能路由到最合适的执行器
- I/O 操作用 async/await
- CPU 密集型用 Isolate 池
- 图算法用 GPU/NPU 加速
- 写操作串行化避免冲突

**实现**：
- IO/CPU/GPU 三种执行器
- 智能路由决策
- 简化版 MVCC（读无锁，写串行）

---

## 关键挑战与解决方案

| 挑战 | 解决方案 |
|------|----------|
| 千万级节点存储 | 图分区 + 矩阵压缩 + 完全图优化 |
| 传递闭包计算 | 分区级预计算 + 增量更新 |
| 写操作并发 | 串行化队列 + WAL + 异步刷新 |
| 读操作性能 | 无锁 MVCC + 分区缓存 + 预取 |
| 图算法性能 | GPU 加速 + 预计算 + 并行处理 |
| 版本历史 | Append-only + 历史清理 |
| 数据一致性 | WAL + 定期刷新 + 崩溃恢复 |

---

**下一步**：开始阶段 1 实施，创建 Command Bus 和图数据库核心引擎。

**预计总时间**：16-20 周（约 4-5 个月）
