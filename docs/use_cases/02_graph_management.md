# 用例 02: 图管理工作流程

## 概述

本文档描述图（Graph）的创建、加载、节点连接、布局、渲染等操作的完整调用链和数据流。

## 用户角色

| 角色 | 描述 |
|------|------|
| 知识工作者 | 创建知识图谱，连接相关概念 |
| 可视化用户 | 调整图布局和节点位置 |
| 分析用户 | 查看图结构、节点关系、路径分析 |
| 自动化用户 | 通过脚本批量操作图结构 |

## 用例列表

| 用例ID | 用例名称 | 优先级 | 触发者 |
|--------|----------|--------|--------|
| UC-GRAPH-01 | 创建图 | P0 | 用户 |
| UC-GRAPH-02 | 加载图 | P0 | 用户/系统 |
| UC-GRAPH-03 | 连接节点 | P0 | 用户/AI/Lua |
| UC-GRAPH-04 | 断开连接 | P1 | 用户/Lua |
| UC-GRAPH-05 | 应用布局算法 | P1 | 用户 |
| UC-GRAPH-06 | 图渲染与交互 | P0 | 系统 |
| UC-GRAPH-07 | 添加/移除节点到图 | P1 | 用户 |

---

## UC-GRAPH-01: 创建图

### 场景描述

用户创建一个新的图工作区。

### 调用链

```
┌─────────────────────────────────────────────────────────────────┐
│ 用户操作流程                                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. 用户点击"新建图"按钮                                           │
│    位置: GraphPlugin UI 工具栏                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 显示创建图对话框                                               │
│    组件: 图创建对话框                                              │
│    输入: 图名称、描述、初始设置                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. 用户填写并确认                                                 │
│    触发: CreateGraphCommand                                      │
│    文件: lib/plugins/graph/command/graph_commands.dart          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. GraphBloc 分发命令到 CommandBus                                │
│    文件: lib/plugins/graph/bloc/graph_bloc.dart                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. CommandBus → 中间件管道 → CreateGraphHandler                   │
│    文件: lib/plugins/graph/handler/create_graph_handler.dart    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. GraphService.createGraph()                                    │
│    文件: lib/plugins/graph/service/graph_service.dart           │
│    职责:                                                          │
│    - 生成唯一图ID                                                 │
│    - 创建图元数据                                                 │
│    - 初始化空节点列表和连接列表                                    │
│    - 调用 GraphRepository.save()                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. FileSystemGraphRepository.save()                              │
│    文件: lib/core/repositories/graph_repository.dart            │
│    职责:                                                          │
│    - 序列化为 JSON                                                │
│    - 写入文件 (graphs/{graphId}.json)                            │
│    - 更新内存索引                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. CommandResult → GraphCreatedEvent                              │
│    GraphBloc 更新 State → UI 切换到新图                            │
└─────────────────────────────────────────────────────────────────┘
```

### 数据流

| 阶段 | 数据格式 | 存储位置 |
|------|----------|----------|
| 用户输入 | Map<String, dynamic> | UI 表单 |
| Command | CreateGraphCommand | CommandBus |
| 图模型 | Graph 对象 | 内存 |
| 持久化 | JSON 文件 | graphs/{graphId}.json |
| 事件通知 | GraphCreatedEvent | Stream |

---

## UC-GRAPH-02: 加载图

### 场景描述

用户打开已有图或系统加载最近使用的图。

### 调用链

```
用户选择图 / 系统自动加载
    │
    ▼
GraphBloc 发送 LoadGraphCommand
    │
    ▼
CommandBus → LoadGraphHandler
    │
    ▼
GraphService.loadGraph()
    │
    ├── GraphRepository.findById()
    │   ├── 从文件系统读取 JSON
    │   └── 反序列化为 Graph 对象
    │
    ├── 加载图中的所有节点
    │   └── NodeRepository.findByIds()
    │
    └── 构建邻接表 (AdjacencyList)
        └── 从节点连接关系构建图结构
    │
    ▼
GraphLoadedEvent → GraphBloc 更新 State
    │
    ▼
GraphWidget 渲染图
```

### 邻接表构建流程

```
LoadGraphCommand
    │
    ▼
AdjacencyList.buildFromNodes(allNodes)
    │
    ├── 遍历所有节点
    ├── 对于每个节点的 connections
    │   ├── 添加出边: adjacencyList[source].add(target)
    │   └── 添加入边: reverseAdjacencyList[target].add(source)
    │
    └── 构建完成，支持图查询和路径计算
```

---

## UC-GRAPH-03: 连接节点

### 场景描述

用户创建两个节点之间的连接关系。

### 调用链

```
用户拖拽节点A到节点B (或选择两个节点后点击连接)
    │
    ▼
GraphWidget 检测到连接操作
    │
    ▼
ConnectNodesCommand (sourceId, targetId, connectionType)
    │
    ▼
CommandBus → ConnectNodesHandler
    │   文件: lib/plugins/graph/handler/connect_nodes_handler.dart
    │
    ├── 验证源节点和目标节点存在
    ├── 检查是否已存在相同连接
    └── 委托 NodeRepository.addConnection()
    │
    ▼
NodeRepository.addConnection()
    │
    ├── 创建 Connection 对象
    ├── 更新源节点的 outgoingConnections
    ├── 更新目标节点的 incomingConnections
    ├── 更新 AdjacencyList
    └── 保存两个节点到文件
    │
    ▼
NodesConnectedEvent → GraphBloc 更新 State
    │
    ▼
GraphWidget 重绘连接线
```

### Connection 数据模型

```dart
Connection {
  String id;              // 连接唯一ID
  String sourceNodeId;    // 源节点ID
  String targetNodeId;    // 目标节点ID
  String? label;          // 连接标签
  ConnectionType type;    // 连接类型
  DateTime createdAt;     // 创建时间
}
```

---

## UC-GRAPH-04: 断开连接

### 场景描述

用户删除两个节点之间的连接。

### 调用链

```
用户选择连接并删除 (右键菜单或Delete键)
    │
    ▼
DisconnectNodesCommand (sourceId, targetId, connectionId)
    │
    ▼
CommandBus → DisconnectNodesHandler
    │   文件: lib/plugins/graph/handler/disconnect_nodes_handler.dart
    │
    ├── 查找连接
    ├── 从源节点移除出边
    ├── 从目标节点移除入边
    ├── 更新 AdjacencyList
    └── 保存节点
    │
    ▼
NodesDisconnectedEvent → UI 重绘
```

---

## UC-GRAPH-05: 应用布局算法

### 场景描述

用户应用自动布局算法重新排列节点。

### 调用链

```
用户选择布局算法 (Force-directed, Tree, Grid等)
    │
    ▼
LayoutPlugin 触发 ApplyLayoutCommand
    │   文件: lib/plugins/layout/command/layout_commands.dart
    │
    ▼
CommandBus → ApplyLayoutHandler
    │   文件: lib/plugins/layout/handler/apply_layout_handler.dart
    │
    ▼
LayoutService.applyLayout()
    │
    ├── 获取当前图的所有节点和连接
    ├── 根据布局算法计算新位置
    │   ├── ForceDirectedLayout: 力导向布局
    │   ├── TreeLayout: 树形布局
    │   ├── GridLayout: 网格布局
    │   └── CircularLayout: 环形布局
    │
    ├── 批量更新节点位置
    │   └── 通过 CommandBus 分发 UpdateNodePositionCommand
    │
    └── 发布 LayoutAppliedEvent
    │
    ▼
GraphBloc 批量更新节点位置 → GraphWidget 重绘
```

### 增量布局引擎

```
LayoutService.incrementalUpdate()
    │
    ├── 仅重新计算受影响节点
    ├── 使用 QuadTree 进行空间索引优化
    └── 支持动画平滑过渡
```

---

## UC-GRAPH-06: 图渲染与交互

### 场景描述

系统在画布上渲染图并处理用户交互。

### 渲染架构

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flame 渲染引擎                                  │
│  文件: lib/plugins/graph/flame/                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ NodeComponent   │ │ConnectionRenderer│ │ LODManager     │
│ 节点渲染组件     │ │ 连接线渲染       │ │ 细节级别管理    │
└─────────────────┘ └─────────────────┘ └─────────────────┘
          │                   │                   │
          ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ BlocConsumer    │ │ FrustumCuller   │ │ SpatialIndex    │
│ BLoC状态订阅     │ │ 视锥裁剪        │ │ 空间索引管理    │
└─────────────────┘ └─────────────────┘ └─────────────────┘
```

### 渲染流程

```
GraphWorld (游戏世界)
    │
    ├── 1. 视锥裁剪 (FrustumCuller)
    │   └── 只渲染可见区域内的节点
    │
    ├── 2. 空间索引查询 (SpatialIndexManager)
    │   └── 快速定位可见节点
    │
    ├── 3. LOD 管理 (LODManager)
    │   ├── 远距离: 简化渲染 (仅图标)
    │   ├── 中距离: 中等渲染 (图标+标题)
    │   └── 近距离: 完整渲染 (图标+标题+内容+连接点)
    │
    ├── 4. 节点渲染 (NodeComponent)
    │   └── 根据 Node 数据绘制
    │
    └── 5. 连接渲染 (ConnectionRenderer)
        └── 绘制节点间的连接线 (贝塞尔曲线)
```

### 用户交互处理

```
用户输入 (触摸/鼠标)
    │
    ▼
Flame 输入系统
    │
    ├── Drag 事件 → NodeDragController
    │   └── 移动节点 → UpdateNodePositionCommand
    │
    ├── Tap 事件 → 节点选择
    │   └── 高亮节点 → 显示详细信息
    │
    ├── DoubleTap 事件 → 编辑节点
    │   └── 打开编辑器
    │
    └── RightClick 事件 → 上下文菜单
        └── 显示操作选项
```

---

## UC-GRAPH-07: 添加/移除节点到图

### 场景描述

用户向图中添加节点或从图中移除节点（不删除节点本身）。

### 添加节点到图

```
用户选择节点并添加到当前图
    │
    ▼
AddNodeToGraphCommand (graphId, nodeId)
    │
    ▼
CommandBus → AddNodeToGraphHandler
    │   文件: lib/plugins/graph/handler/add_node_to_graph_handler.dart
    │
    ▼
GraphService.addNodeToGraph()
    │
    ├── 验证节点存在
    ├── 将节点ID添加到图的 nodeIds 列表
    └── 保存图
    │
    ▼
NodeAddedToGraphEvent → UI 更新
```

### 从图移除节点

```
用户从图中移除节点 (不删除节点本身)
    │
    ▼
RemoveNodeFromGraphCommand (graphId, nodeId)
    │
    ▼
CommandBus → RemoveNodeFromGraphHandler
    │
    ▼
GraphService.removeNodeFromGraph()
    │
    ├── 从图的 nodeIds 列表移除
    ├── 移除相关连接
    └── 保存图
    │
    ▼
NodeRemovedFromGraphEvent → UI 更新
```

---

## 图管理数据模型

### Graph 模型

```dart
Graph {
  String id;                  // 图唯一ID
  String name;                // 图名称
  String? description;        // 图描述
  List<String> nodeIds;       // 图中包含的节点ID列表
  List<GraphConnection> connections; // 连接列表
  Map<String, dynamic> layoutSettings; // 布局设置
  DateTime createdAt;
  DateTime updatedAt;
}
```

### 图与节点的关系

```
Graph ──包含──▶ Node (通过 nodeIds 引用)
  │
  └── connections ──▶ Connection (sourceId → targetId)
```

---

## 时序图: 节点连接流程

```
用户            GraphWidget      GraphBloc    CommandBus     Handler      Repository    AdjacencyList   文件系统
 │                 │                │             │             │             │               │              │
 │──拖拽连接──────▶│                │             │             │             │               │              │
 │                 │──ConnectNodes─▶│             │             │             │               │              │
 │                 │   Command      │             │             │             │               │              │
 │                 │                │─dispatch()─▶│             │             │               │              │
 │                 │                │             │──中间件────▶│             │               │              │
 │                 │                │             │             │─addConn()──▶│               │              │
 │                 │                │             │             │             │──更新邻接表───▶│              │
 │                 │                │             │             │             │               │──保存节点───▶│
 │                 │                │             │             │◀────────────│               │              │
 │                 │                │             │◀────────────│             │               │              │
 │                 │                │◀────────────│             │             │               │              │
 │                 │◀──重绘连接─────│             │             │             │               │              │
 │◀──显示连接线───│                 │             │             │             │               │              │
```

---

## 扩展点

| 扩展点 | 说明 | 实现方式 |
|--------|------|----------|
| 布局算法 | 添加新的布局算法 | LayoutPlugin 注册新算法 |
| 节点渲染 | 自定义节点外观 | UIHook (graph.node_renderer) |
| 连接样式 | 自定义连接线样式 | ConnectionRenderer 扩展 |
| 图事件 | 监听图操作事件 | AppEvent 订阅 |
| 视锥裁剪 | 优化大规模渲染 | FrustumCuller 自定义策略 |
