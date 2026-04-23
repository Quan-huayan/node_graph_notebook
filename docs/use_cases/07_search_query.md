# 用例 07: 搜索和查询工作流程

## 概述

本文档描述节点搜索、高级查询、搜索索引、搜索预设等操作的完整调用链和数据流。

## 用户角色

| 角色 | 描述 |
|------|------|
| 检索用户 | 快速查找节点 |
| 高级用户 | 使用复杂条件搜索和过滤 |
| 分析用户 | 查询节点关系和路径 |
| 频繁用户 | 使用搜索预设快速查询 |

## 用例列表

| 用例ID | 用例名称 | 优先级 | 触发者 |
|--------|----------|--------|--------|
| UC-SEARCH-01 | 快速搜索 | P0 | 用户 |
| UC-SEARCH-02 | 高级搜索 | P1 | 用户 |
| UC-SEARCH-03 | 过滤节点 | P1 | 用户 |
| UC-SEARCH-04 | 搜索索引 (物化视图) | P0 | 系统 |
| UC-SEARCH-05 | 保存搜索预设 | P2 | 用户 |
| UC-SEARCH-06 | 图查询 (邻接/路径) | P1 | 用户/系统 |

---

## UC-SEARCH-01: 快速搜索

### 场景描述

用户输入关键词快速搜索匹配的节点。

### 调用链

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 用户在搜索框输入关键词                                         │
│    位置: SearchPlugin → SearchSidebarPanel                       │
│    文件: lib/plugins/search/ui/search_sidebar_panel.dart        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. SearchBloc 接收输入，防抖处理 (debounce 300ms)                 │
│    文件: lib/plugins/search/bloc/search_bloc.dart               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. SearchBloc 发送 SearchNodesQuery                               │
│    文件: lib/core/cqrs/queries/search_nodes_query.dart          │
│    参数:                                                          │
│    - query: String (搜索关键词)                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. QueryBus.dispatch(SearchNodesQuery)                            │
│    文件: lib/core/cqrs/query/query_bus.dart                     │
│    流程:                                                          │
│    4.1 检查查询缓存 (QueryCache)                                  │
│        ├── 命中 → 直接返回缓存结果                                │
│        └── 未命中 → 继续执行                                      │
│    4.2 查找注册的Handler                                          │
│    4.3 执行 Handler.handle()                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. SearchNodesQueryHandler                                        │
│    文件: lib/core/cqrs/handlers/search_nodes_handler.dart        │
│    流程:                                                          │
│    5.1 NodeRepository.search(query)                              │
│    5.2 匹配逻辑:                                                  │
│        ├── 标题包含关键词                                         │
│        ├── 内容包含关键词                                         │
│        └── 元数据匹配                                             │
│    5.3 返回匹配节点列表 (按相关性排序)                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. QueryResult → QueryBus 缓存结果                                │
│    缓存策略:                                                      │
│    - 最大缓存大小: 1000 条目                                     │
│    - 默认TTL: 5分钟                                              │
│    - LRU淘汰策略                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. SearchBloc 更新 State → UI 显示搜索结果                        │
│    组件: SearchSidebarPanel 显示搜索结果列表                       │
│    每个结果:                                                       │
│    - 节点标题 (高亮匹配部分)                                       │
│    - 节点预览内容                                                  │
│    - 创建时间                                                      │
└─────────────────────────────────────────────────────────────────┘
```

### 数据流

```
用户输入 → SearchSidebarPanel
              │
              ▼ (debounce 300ms)
         SearchBloc
              │
              ▼
         QueryBus (SearchNodesQuery)
              │
              ├── QueryCache (检查缓存)
              │   ├── 命中 → 返回
              │   └── 未命中 ↓
              │
              ▼
         SearchNodesQueryHandler
              │
              ▼
         NodeRepository.search(query)
              │
              ├── 遍历所有节点
              ├── 标题匹配
              ├── 内容匹配
              └── 元数据匹配
              │
              ▼
         List<Node> (排序后)
              │
              ▼
         QueryBus 缓存 → SearchBloc → UI更新
```

---

## UC-SEARCH-02: 高级搜索

### 场景描述

用户使用多条件组合进行高级搜索。

### 调用链

```
用户打开高级搜索 → 设置条件 → 执行搜索
    │
    ▼
AdvancedSearchQuery
    │
    ├── 支持的条件:
    │   ├── title: String (标题包含)
    │   ├── content: String (内容包含)
    │   ├── createdAt: DateTime (创建时间范围)
    │   ├── updatedAt: DateTime (更新时间范围)
    │   ├── tags: List<String> (标签匹配)
    │   ├── metadata: Map<String, dynamic> (元数据条件)
    │   └── hasConnections: bool (是否有连接)
    │
    ▼
QueryBus → AdvancedSearchQueryHandler
    │
    ▼
NodeRepository.advancedSearch(query)
    │
    ├── 应用所有条件过滤
    └── 返回匹配节点
    │
    ▼
UI 显示结果列表
```

### 示例查询

```dart
AdvancedSearchQuery(
  title: 'Flutter',
  content: 'Widget',
  createdAtAfter: DateTime(2024, 1, 1),
  tags: ['tutorial', 'guide'],
  hasConnections: true,
)
```

---

## UC-SEARCH-04: 搜索索引 (物化视图)

### 场景描述

系统维护搜索索引以加速搜索查询。

### 架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    SearchIndexMaterializedView                    │
│  文件: lib/core/cqrs/materialized_views/search_index_view.dart  │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ Token Index     │ │ Node Index      │ │ Popular Tokens  │
│ 词元 → 节点ID   │ │ 节点 → 词元列表  │ │ 热门词元统计    │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

### 索引更新流程

```
节点创建/更新/删除
    │
    ▼
CommandHandler 发布事件
    │
    ├── NodeCreatedEvent
    ├── NodeUpdatedEvent
    └── NodeDeletedEvent
    │
    ▼
SearchIndexMaterializedView 订阅事件
    │
    ├── on(NodeCreatedEvent) → addToIndex(node)
    │   └── 分词 → 添加到索引
    │
    ├── on(NodeUpdatedEvent) → updateIndex(node)
    │   └── 移除旧词 → 添加新词
    │
    └── on(NodeDeletedEvent) → removeFromIndex(nodeId)
        └── 移除所有相关词元
```

### 快速搜索流程

```
FastSearchQuery (token)
    │
    ▼
SearchIndexMaterializedView.lookup(token)
    │
    ├── 词元标准化 (小写、去重)
    ├── 查找 Token Index → 获取节点ID列表
    └── 返回相关节点
    │
    ▼
FastSearchQueryHandler
    │
    ├── 批量加载节点 NodeRepository.findByIds()
    └── 返回 NodeReadModel 列表
```

---

## UC-SEARCH-05: 保存搜索预设

### 场景描述

用户保存常用搜索条件以便快速复用。

### 调用链

```
用户设置搜索条件 → 点击"保存预设"
    │
    ▼
SaveSearchPresetCommand
    │
    ├── name: String (预设名称)
    ├── query: SearchQuery (搜索条件)
    └── description: String? (描述)
    │
    ▼
CommandBus → SaveSearchPresetHandler
    │
    ▼
SearchPresetService.savePreset()
    │
    ├── 生成预设ID
    ├── 序列化搜索条件
    └── 保存到文件
    │
    ▼
SearchPresetSavedEvent → UI 更新
```

### 使用预设

```
用户选择预设 → 加载预设 → 自动执行搜索
    │
    ▼
SearchPresetService.getPreset(presetId)
    │
    └── 反序列化搜索条件
    │
    ▼
SearchBloc 应用预设条件 → 执行搜索
```

---

## UC-SEARCH-06: 图查询 (邻接/路径)

### 场景描述

查询节点的邻接节点、节点间路径、节点度数等图结构信息。

### 查询类型

| 查询类型 | Handler | 描述 |
|----------|---------|------|
| GetNeighborNodesQuery | GetNeighborNodesQueryHandler | 获取直接邻接节点 |
| GetOutgoingReferencesQuery | GetOutgoingReferencesQueryHandler | 获取出边指向的节点 |
| GetIncomingReferencesQuery | GetIncomingReferencesQueryHandler | 获取入边来源的节点 |
| GetNodePathQuery | GetNodePathQueryHandler | 获取两个节点间的路径 |
| GetNodeDegreeQuery | GetNodeDegreeQueryHandler | 获取节点度数 (入度/出度) |

### GetNeighborNodesQuery 流程

```
用户点击节点 → 查看邻接节点
    │
    ▼
GetNeighborNodesQuery(nodeId)
    │
    ▼
QueryBus → GetNeighborNodesQueryHandler
    │
    ├── 使用 AdjacencyList.getNeighbors(nodeId)
    │   ├── 获取出边邻接节点
    │   └── 获取入边邻接节点
    │
    ├── NodeRepository.findByIds(neighborIds)
    └── 返回邻接节点列表
    │
    ▼
UI 显示邻接节点
```

### GetNodePathQuery 流程

```
用户选择源节点和目标节点 → 查询路径
    │
    ▼
GetNodePathQuery(sourceId, targetId)
    │
    ▼
QueryBus → GetNodePathQueryHandler
    │
    ├── BFS/DFS 搜索路径
    │   └── 使用 AdjacencyList 进行图遍历
    │
    ├── 如果找到路径:
    │   └── NodeRepository.findByIds(pathNodeIds)
    │
    └── 返回路径节点列表
    │
    ▼
UI 高亮显示路径节点和连接
```

### 节点度数查询

```
GetNodeDegreeQuery(nodeId)
    │
    ▼
QueryBus → GetNodeDegreeQueryHandler
    │
    ├── AdjacencyList.getInDegree(nodeId)
    ├── AdjacencyList.getOutDegree(nodeId)
    └── 返回 NodeDegree {
          inDegree: int,
          outDegree: int,
          totalDegree: int
        }
    │
    ▼
UI 显示节点度数信息
```

---

## 查询缓存系统

### QueryCache

```dart
QueryCache {
  maxSize: int = 1000;         // 最大缓存条目
  defaultTtl: Duration = 5min; // 默认过期时间
  
  // 缓存键: Query的哈希值
  // 缓存值: QueryResult + 时间戳
  
  get(key) → QueryResult?      // 获取缓存
  put(key, result)             // 添加缓存
  invalidate(key)              // 使缓存失效
  clear()                      // 清空缓存
}
```

### 缓存失效策略

```
节点创建/更新/删除事件
    │
    ▼
QueryCache 监听事件
    │
    ├── NodeCreatedEvent → 可能需要缓存更新
    ├── NodeUpdatedEvent → 使相关查询缓存失效
    └── NodeDeletedEvent → 使相关查询缓存失效
    │
    ▼
LRU 淘汰
    └── 缓存满时淘汰最久未使用的条目
```

---

## 读取模型 (Read Model)

### NodeReadModel

```dart
NodeReadModel {
  id: String;
  title: String;
  contentPreview: String;  // 内容预览 (截断)
  createdAt: DateTime;
  updatedAt: DateTime;
  tags: List<String>;
  connectionCount: int;    // 连接数量
  isInCurrentGraph: bool;  // 是否在当前图中
}
```

### 用途

NodeReadModel 用于搜索和列表场景，避免加载完整节点数据，提高查询性能。

---

## 时序图: 搜索流程

```
用户          SearchPanel      SearchBloc      QueryBus      QueryCache    Handler      Repository    AdjacencyList
 │                │                │               │             │             │             │               │
 │──输入搜索词────▶│                │               │             │             │             │               │
 │                │──debounce─────▶│               │             │             │             │               │
 │                │                │──Query────────▶│             │             │             │               │
 │                │                │               │──checkCache─▶│             │             │               │
 │                │                │               │             │             │             │               │
 │                │                │               │  ◀──缓存命中─│             │             │               │
 │                │                │               │             │             │             │               │
 │                │                │               │             │  缓存未命中  │             │               │
 │                │                │               │──────────────────────────▶│             │               │
 │                │                │               │             │             │──search()───▶│               │
 │                │                │               │             │             │             │               │
 │                │                │               │◀──结果────────────────────│             │               │
 │                │                │               │             │             │             │               │
 │                │                │               │──cacheResult─▶│             │             │               │
 │                │                │               │             │             │             │               │
 │                │                │◀──结果────────│             │             │             │               │
 │                │◀──State更新────│               │             │             │             │               │
 │◀──显示结果─────│                │               │             │             │             │               │
```

---

## 扩展点

| 扩展点 | 说明 | 实现方式 |
|--------|------|----------|
| 新查询类型 | 添加新的查询 | Query + QueryHandler |
| 搜索优化 | 改进搜索算法 | NodeRepository.search() |
| 索引优化 | 改进索引策略 | SearchIndexMaterializedView |
| 缓存策略 | 自定义缓存策略 | QueryCache 配置 |
