# 用例 01: 节点管理流程

## 概述

本文档描述节点创建、读取、更新、删除（CRUD）操作的完整调用链和数据流。

## 用户角色

| 角色 | 描述 |
|------|------|
| 普通用户 | 创建、编辑、删除节点，查看节点关系 |
| 高级用户 | 使用批量操作、元数据管理、节点模板 |
| AI用户 | 通过AI辅助创建和分析节点 |
| 开发者 | 通过Lua脚本自动化节点操作 |

## 用例列表

| 用例ID | 用例名称 | 优先级 | 触发者 |
|--------|----------|--------|--------|
| UC-NODE-01 | 创建节点 | P0 | 用户/AI/Lua |
| UC-NODE-02 | 更新节点 | P0 | 用户/AI/Lua |
| UC-NODE-03 | 删除节点 | P0 | 用户/AI/Lua |
| UC-NODE-04 | 查询节点 | P0 | 系统/用户 |
| UC-NODE-05 | 移动节点 | P1 | 用户 |
| UC-NODE-06 | 调整节点大小 | P1 | 用户 |
| UC-NODE-07 | 批量操作节点 | P2 | 用户/Lua |

---

## UC-NODE-01: 创建节点

### 场景描述

用户通过UI界面、AI功能或Lua脚本创建新节点。

### 前置条件

- 应用程序已启动
- 插件系统已加载
- 至少有一个图或工作区已打开

### 调用链

```
┌─────────────────────────────────────────────────────────────────┐
│ 用户操作流程                                                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. 用户点击"创建节点"按钮                                         │
│    位置: GraphPlugin → GraphNodesToolbarHook                    │
│    文件: lib/plugins/graph/ui/graph_nodes_dialog.dart           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 显示创建节点对话框                                             │
│    组件: CreateNodeDialog                                       │
│    输入: 节点名称、描述、图标、元数据                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. 用户填写表单并点击"确认"                                       │
│    触发: CreateNodeCommand                                       │
│    文件: lib/plugins/graph/command/node_commands.dart           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. NodeBloc 接收命令并分发到 CommandBus                          │
│    文件: lib/plugins/graph/bloc/node_bloc.dart                  │
│    代码: await commandBus.dispatch(createNodeCommand)           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. CommandBus 执行中间件管道                                      │
│    顺序:                                                          │
│    5.1 LoggingMiddleware (记录开始)                               │
│    5.2 TransactionMiddleware (开始事务)                           │
│    5.3 ValidationMiddleware (验证命令参数)                        │
│    5.4 UndoMiddleware (保存撤销点)                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. CommandHandler: CreateNodeHandler                             │
│    文件: lib/plugins/graph/handler/create_node_handler.dart     │
│    职责:                                                          │
│    - 从命令中提取节点数据                                          │
│    - 委托给 NodeService 处理                                      │
│    - 发布 NodeCreatedEvent                                       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. NodeService.createNode()                                      │
│    文件: lib/plugins/graph/service/node_service.dart            │
│    职责:                                                          │
│    - 生成唯一节点ID (UUID)                                        │
│    - 设置默认属性 (创建时间、更新时间)                              │
│    - 调用 NodeRepository.save()                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 8. FileSystemNodeRepository.save()                               │
│    文件: lib/core/repositories/node_repository.dart             │
│    职责:                                                          │
│    - 将节点序列化为 JSON                                          │
│    - 写入文件系统 (nodes/{nodeId}.json)                          │
│    - 更新内存索引                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 9. CommandResult 返回，CommandBus 发布事件                        │
│    事件: NodeCreatedEvent → CommandBus.eventStream              │
│    订阅者: NodeBloc, GraphBloc                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 10. NodeBloc 接收事件，更新 State                                 │
│     事件处理:                                                     │
│     - 将新节点添加到 nodes 列表                                   │
│     - 触发 UI 重建                                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 11. GraphWidget 重新渲染，显示新节点                               │
│     文件: lib/plugins/graph/flame/graph_widget.dart              │
└─────────────────────────────────────────────────────────────────┘
```

### 数据流

| 阶段 | 数据格式 | 存储位置 |
|------|----------|----------|
| 用户输入 | Map<String, dynamic> | UI 表单 |
| Command | CreateNodeCommand | CommandBus |
| 节点模型 | Node 对象 | 内存 |
| 持久化 | JSON 文件 | nodes/{nodeId}.json |
| 事件通知 | NodeCreatedEvent | Stream |

### 异常处理

| 异常类型 | 触发条件 | 处理方式 |
|----------|----------|----------|
| ValidationException | 节点名称为空或格式无效 | 返回错误，UI显示验证信息 |
| StorageException | 文件系统写入失败 | 回滚事务，显示错误提示 |
| DuplicateNodeException | 节点ID已存在 | 生成新ID重试 |

---

## UC-NODE-02: 更新节点

### 场景描述

用户修改节点属性（名称、描述、位置、大小、元数据等）。

### 调用链

```
用户编辑节点
    │
    ▼
UI 组件 (NodeEditorPanelHook / NodeMetadataDialog)
    │
    ▼
NodeBloc 发送 UpdateNodeCommand
    │
    ▼
CommandBus
    │
    ├── LoggingMiddleware
    ├── TransactionMiddleware
    ├── ValidationMiddleware
    └── UndoMiddleware (保存旧状态)
    │
    ▼
UpdateNodeHandler
    │
    ▼
NodeService.updateNode()
    │
    ├── 合并新旧数据
    ├── 更新时间戳
    └── 调用 NodeRepository.save()
    │
    ▼
FileSystemNodeRepository.save()
    │
    ├── 序列化节点
    ├── 写入文件
    └── 更新索引
    │
    ▼
CommandResult → NodeUpdatedEvent
    │
    ▼
NodeBloc 更新 State → UI 重建
```

### 关键代码路径

| 组件 | 文件路径 |
|------|----------|
| Command | `lib/plugins/graph/command/node_commands.dart` |
| Handler | `lib/plugins/graph/handler/update_node_handler.dart` |
| Service | `lib/plugins/graph/service/node_service.dart` |
| Repository | `lib/core/repositories/node_repository.dart` |
| BLoC | `lib/plugins/graph/bloc/node_bloc.dart` |

---

## UC-NODE-03: 删除节点

### 场景描述

用户删除一个或多个节点，包括级联删除连接关系。

### 调用链

```
用户选择节点并点击删除
    │
    ▼
DeleteNodeDialog 确认
    │
    ▼
NodeBloc 发送 DeleteNodeCommand
    │
    ▼
CommandBus (中间件管道)
    │
    ▼
DeleteNodeHandler
    │
    ├── 查找节点
    ├── 查找相关连接
    ├── 委托 NodeService.deleteNode()
    └── 发布 NodeDeletedEvent + ConnectionsDeletedEvent
    │
    ▼
NodeService.deleteNode()
    │
    ├── 删除节点文件
    ├── 删除相关连接
    └── 更新索引
    │
    ▼
CommandBus.eventStream → BLoC → UI更新
```

### 级联删除逻辑

```
DeleteNodeCommand
    │
    ├── 1. 删除节点本身
    │
    ├── 2. 删除所有出边连接 (该节点指向其他节点)
    │
    ├── 3. 删除所有入边连接 (其他节点指向该节点)
    │
    └── 4. 更新邻接表 (AdjacencyList)
```

---

## UC-NODE-04: 查询节点

### 场景描述

系统或用户查询节点列表、单个节点详情或节点关系。

### 调用链 (CQRS Query 模式)

```
UI 组件请求节点数据
    │
    ▼
BLoC 发送 Query (LoadNodeQuery / LoadAllNodesQuery)
    │
    ▼
QueryBus
    │
    ├── 检查缓存 (QueryCache)
    │   ├── 命中 → 返回缓存结果
    │   └── 未命中 → 继续
    │
    ▼
QueryHandler (LoadNodeQueryHandler / LoadAllNodesQueryHandler)
    │
    ▼
NodeRepository.query() / queryAll()
    │
    ├── 从文件系统读取
    ├── 反序列化 JSON
    └── 返回 Node 对象列表
    │
    ▼
QueryResult → BLoC State → UI 渲染
```

### 查询类型

| 查询类型 | Handler | 描述 |
|----------|---------|------|
| LoadNodeQuery | LoadNodeQueryHandler | 加载单个节点 |
| LoadNodesQuery | LoadNodesQueryHandler | 加载指定节点列表 |
| LoadAllNodesQuery | LoadAllNodesQueryHandler | 加载所有节点 |
| SearchNodesQuery | SearchNodesQueryHandler | 文本搜索节点 |
| AdvancedSearchQuery | AdvancedSearchQueryHandler | 高级条件搜索 |
| GetNeighborNodesQuery | GetNeighborNodesQueryHandler | 获取邻接节点 |
| GetNodeDegreeQuery | GetNodeDegreeQueryHandler | 获取节点度数 |
| GetNodePathQuery | GetNodePathQueryHandler | 获取节点路径 |

---

## UC-NODE-05: 移动节点

### 场景描述

用户在画布上拖拽节点改变位置。

### 调用链

```
用户拖拽节点
    │
    ▼
Flame Drag 事件
    │
    ▼
NodeDragController
    │
    ▼
MoveNodeCommand (包含新坐标)
    │
    ▼
CommandBus → MoveNodeHandler
    │
    ▼
NodeRepository.updatePosition()
    │
    ├── 更新节点位置
    ├── 保存到文件
    └── 发布 NodeMovedEvent
    │
    ▼
GraphBloc 更新节点位置缓存 → 重绘
```

---

## UC-NODE-06: 调整节点大小

### 场景描述

用户调整节点尺寸或系统自动计算节点大小（基于内容）。

### 调用链

```
用户拖拽节点边缘 / 内容变化触发自动计算
    │
    ▼
ResizeNodeCommand
    │
    ▼
CommandBus → ResizeNodeHandler
    │
    ▼
NodeRepository.updateSize()
    │
    ├── 更新节点尺寸
    ├── 保存到文件
    └── 发布 NodeResizedEvent
    │
    ▼
UI 重绘
```

### 自动尺寸计算 (CPU 密集型任务)

```
内容变化
    │
    ▼
ExecutionEngine.executeCPU()
    │
    ├── TextLayoutTask (计算文本布局)
    └── NodeSizingTask (计算节点尺寸)
    │
    ▼
返回尺寸结果 → 自动触发 ResizeNodeCommand
```

---

## 时序图

```
用户            UI组件           NodeBloc      CommandBus      Handler        Service      Repository     文件系统
 │                │                 │              │              │              │              │              │
 │──创建节点──────▶│                 │              │              │              │              │              │
 │                │──CreateNodeCmd─▶│              │              │              │              │              │
 │                │                 │──dispatch()─▶│              │              │              │              │
 │                │                 │              │──中间件─────▶│              │              │              │
 │                │                 │              │              │──execute()──▶│              │              │
 │                │                 │              │              │              │──save()─────▶│              │
 │                │                 │              │              │              │              │──写入JSON───▶│
 │                │                 │              │              │              │◀─────────────│              │
 │                │                 │              │              │◀─────────────│              │              │
 │                │                 │              │◀─────────────│              │              │              │
 │                │                 │◀─────────────│              │              │              │              │
 │                │◀──事件通知──────│              │              │              │              │              │
 │◀──渲染新节点────│                 │              │              │              │              │              │
```

## 扩展点

| 扩展点 | 说明 | 实现方式 |
|--------|------|----------|
| 节点创建前 | 验证或修改节点数据 | CommandMiddleware |
| 节点创建后 | 触发自定义动作 | AppEvent 订阅 |
| 节点渲染 | 自定义节点外观 | UIHook (graph.node_renderer) |
| 节点验证 | 自定义验证规则 | ValidationMiddleware |
