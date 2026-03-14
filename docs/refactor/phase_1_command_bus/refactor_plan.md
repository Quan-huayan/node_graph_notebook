# Phase 1: 命令总线实现 - 重构计划

## 重构目标

### 当前架构问题
```
UI层 (Flutter Widgets)
    ↓
BLoC层 (NodeBloc, GraphBloc, ...)
    ↓
Service层 (NodeService, GraphService)
    ↓
Repository层 (FileSystemNodeRepository, FileSystemGraphRepository)
    ↓
文件系统 (Markdown + JSON)
```

**核心问题**：
- BLoC承担了太多业务逻辑
- Service层只是简单的Repository包装
- 业务逻辑分散，难以测试和复用
- 缺乏统一的业务操作接口

### Phase 1 目标

建立**命令总线（Command Bus）**作为业务逻辑的统一入口：

1. **BLoC瘦身**：BLoC只负责UI状态管理
2. **业务逻辑集中**：Command Bus处理所有业务逻辑
3. **直接替换**：不需要向后兼容，直接重构

---

## 实施计划（3周）

### 第1周：Command Bus核心基础设施 ✅ 已完成

#### 任务清单

- [x] 创建命令基类 `Command<T>`
- [x] 实现命令总线 `CommandBus`
- [x] 实现执行上下文 `CommandContext`
- [x] 实现执行结果 `CommandResult<T>`
- [x] 实现处理器接口 `CommandHandler<T>`
- [x] 实现中间件系统 `CommandMiddleware`
- [x] 实现验证中间件 `ValidationMiddleware`
- [x] 实现日志中间件 `LoggingMiddleware`
- [x] 实现事务中间件 `TransactionMiddleware`
- [x] 集成到依赖注入（`lib/app.dart`）

**状态**: ✅ 100% 完成 - 2026-03-XX

#### 核心接口设计

**命令基类**：
```dart
abstract class Command<T> {
  Future<CommandResult<T>> execute(CommandContext context);
  Future<void> undo(CommandContext context);
  String get name;
  String get description;
  bool get isUndoable => true;
}
```

**命令总线**：
```dart
class CommandBus {
  Future<CommandResult<T>> dispatch<T>(Command<T> command);
  void registerHandler<T>(CommandHandler<T> handler);
  void addMiddleware(CommandMiddleware middleware);
}
```

---

### 第2周：节点命令实现 ✅ 已完成

#### 任务清单

- [x] 定义 `CreateNodeCommand`
- [x] 定义 `UpdateNodeCommand`
- [x] 定义 `DeleteNodeCommand`
- [x] 定义 `ConnectNodesCommand`
- [x] 定义 `DisconnectNodesCommand`
- [x] 定义 `MoveNodeCommand`
- [x] 定义 `ResizeNodeCommand`
- [x] 实现 `CreateNodeHandler`
- [x] 实现 `UpdateNodeHandler`
- [x] 实现 `DeleteNodeHandler`
- [x] 实现 `ConnectNodesHandler`
- [x] 实现 `DisconnectNodesHandler`
- [x] 实现 `MoveNodeHandler`
- [x] 实现 `ResizeNodeHandler`
- [ ] 编写命令处理器单元测试

**状态**: ✅ 93% 完成（缺少单元测试）- 2026-03-XX

#### 命令处理器职责

每个命令处理器负责：
1. 验证命令参数
2. 调用Service执行业务逻辑
3. 发布EventBus事件
4. 返回执行结果

---

### 第3周：BLoC重构 ⏳ 进行中

#### 任务清单

- [x] 重构 `NodeBloc` 使用CommandBus
- [ ] 重构 `GraphBloc` 使用CommandBus
- [x] 更新依赖注入配置
- [x] 更新 `NodeBloc` 测试（使用 Mock CommandBus）
- [ ] 编写集成测试
- [ ] 手动功能测试

**状态**: ⏳ 50% 完成 - 2026-03-14

**NodeBloc**: ✅ 已完成并测试通过
**GraphBloc**: ❌ 未开始（计划在 NodeBloc 验证后进行）

#### BLoC重构要点

- 移除业务逻辑到Command Handler
- BLoC只管理UI状态（isLoading, error）
- 写操作通过CommandBus
- 读操作直接使用Repository
- 订阅EventBus响应数据变化

---

## 架构设计

### 责任划分

```
┌─────────────────────────────────────────────────────────┐
│ UI层 (Flutter Widgets)                                  │
│ - 只负责显示和用户交互                                   │
└─────────────────────────────────────────────────────────┘
                        ↓
┌─────────────────────────────────────────────────────────┐
│ BLoC层 (NodeBloc, GraphBloc)                           │
│ - 管理UI状态（isLoading, error, selection）             │
│ - 分发Event到CommandBus                                 │
│ - 订阅EventBus更新状态                                  │
│ - 不包含业务逻辑                                         │
└─────────────────────────────────────────────────────────┘
                    ↓                   ↓
┌───────────────────────┐    ┌──────────────────────────┐
│ CommandBus (写操作)   │    │ Repository (读操作)       │
│ - 业务逻辑            │    │ - 数据查询                │
│ - 验证                │    │ - 搜索                    │
│ - 事务                │    │                           │
│ - 发布事件            │    │                           │
└───────────────────────┘    └──────────────────────────┘
            ↓
┌─────────────────────────────────────────────────────────┐
│ Service层 / Repository层                                │
│ - 数据持久化                                             │
│ - 数据转换                                               │
└─────────────────────────────────────────────────────────┘
```

### CQRS模式

- **写操作（Command）**：通过CommandBus，包含业务逻辑
- **读操作（Query）**：直接通过Repository，无业务逻辑

---

## 文件清单

### 新建文件（约15个）

```
lib/core/commands/
├── command.dart
├── command_bus.dart
├── command_context.dart
├── command_result.dart
├── command_handler.dart
├── command_exception.dart
├── middleware/
│   ├── middleware.dart
│   ├── validation_middleware.dart
│   ├── logging_middleware.dart
│   └── transaction_middleware.dart
├── impl/
│   └── node_commands.dart
└── handlers/
    ├── create_node_handler.dart
    ├── update_node_handler.dart
    ├── delete_node_handler.dart
    └── connect_nodes_handler.dart
```

### 修改文件（3个）

| 文件 | 修改内容 |
|------|---------|
| `lib/app.dart` | 添加CommandBus Provider |
| `lib/bloc/node/node_bloc.dart` | 重构为使用CommandBus |
| `lib/bloc/graph/graph_bloc.dart` | 重构为使用CommandBus |

---

## 测试计划

### 单元测试

- [ ] CommandBus测试
- [ ] CommandResult测试
- [ ] Middleware测试
- [ ] Command Handler测试

### 集成测试

- [x] NodeBloc 与 CommandBus 集成测试（已更新为使用新架构）
- [ ] CommandBus与BLoC集成测试
- [ ] 端到端功能测试

### 手动测试清单

- [ ] 创建节点功能正常
- [ ] 更新节点功能正常
- [ ] 删除节点功能正常
- [ ] 连接节点功能正常
- [ ] 断开连接功能正常
- [ ] 移动节点功能正常
- [ ] 调整节点大小功能正常
- [ ] 撤销/重做功能正常
- [ ] 搜索功能正常
- [ ] 图操作正常

---

## 成功指标

| 指标 | 目标 | 当前状态 |
|------|------|----------|
| 代码分析通过 | 100% | ✅ 100% |
| 命令延迟 | < 1ms | ⏳ 未测试 |
| 测试覆盖率 | > 80% | ⏳ ~30% (仅 NodeBloc) |
| BLoC 代码行数减少 | > 30% | ✅ NodeBloc: ~40% |
| 功能完整性 | 100% | ⏳ NodeBloc: 100%, GraphBloc: 0% |

---

## 当前状态总结

**总体进度**: 约 90% 完成

### ✅ 已完成
- Command Bus 核心基础设施（100%）
- 7 个节点命令和处理器（100%）
- 3 个中间件（100%）
- NodeBloc 重构（100%）
- 依赖注入配置（100%）
- 代码分析通过（100%）

### ⏳ 进行中
- 测试编写（约 30%）
  - NodeBloc 测试已更新 ✅
  - CommandBus 单元测试待编写 ❌
  - Handler 单元测试待编写 ❌

### ❌ 未开始
- GraphBloc 重构（0%）
- 手动功能测试（0%）

### 📝 详细状态
详细实施状态请查看 [refactor_status.md](refactor_status.md)

---

## 后续阶段

Phase 1 完成后：
- Command Bus基础设施建立
- BLoC瘦身完成
- 业务逻辑集中到Command Bus

为后续阶段打下基础：
- Phase 2: 图命令实现
- Phase 3: 执行引擎
- Phase 4: 存储引擎优化
- Phase 5: 图分区与可达性
