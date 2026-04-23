# CQRS 模块 Bug 报告

审查日期: 2026-04-20
审查范围: `lib/core/cqrs` 文件夹

---

## 严重 Bug (Critical)

### 1. FilterNodesQuery 缓存键缺失参数

**文件**: [search_nodes_query.dart:68-72](file:///d:/Projects/node_graph_notebook/lib/core/cqrs/queries/search_nodes_query.dart#L68-L72)

**问题描述**:
`FilterNodesQuery` 的 `cacheKey` 未包含 `updatedAtStart` 和 `updatedAtEnd` 参数，导致不同过滤条件的查询会错误地共享同一缓存条目。

**问题代码**:
```dart
@override
String get cacheKey => 'FilterNodes:'
    '${tags?.join(',') ?? "all"}:'
    '${createdAtStart?.millisecondsSinceEpoch ?? "any"}:'
    '${createdAtEnd?.millisecondsSinceEpoch ?? "any"}:'
    '$limit:$offset';  // 缺少 updatedAtStart 和 updatedAtEnd
```

**影响**:
- 使用不同更新时间过滤条件的查询会返回错误的缓存结果
- 数据一致性问题

**修复建议**:
```dart
@override
String get cacheKey => 'FilterNodes:'
    '${tags?.join(',') ?? "all"}:'
    '${createdAtStart?.millisecondsSinceEpoch ?? "any"}:'
    '${createdAtEnd?.millisecondsSinceEpoch ?? "any"}:'
    '${updatedAtStart?.millisecondsSinceEpoch ?? "any"}:'
    '${updatedAtEnd?.millisecondsSinceEpoch ?? "any"}:'
    '$limit:$offset';
```

---

## 高危 Bug (High)

### 2. CommandContext 递归实例化 CommandBus

**文件**: [command_context.dart:36](file:///d:/Projects/node_graph_notebook/lib/core/cqrs/commands/models/command_context.dart#L36)

**问题描述**:
当 `CommandContext` 未传入 `commandBus` 时，会创建一个新的 `CommandBus()` 实例。这个新实例没有任何处理器注册，且与主应用程序的 `CommandBus` 完全隔离。

**问题代码**:
```dart
this.commandBus = commandBus ?? CommandBus();
```

**影响**:
- 如果 `CommandContext` 在没有传入 `commandBus` 的情况下被使用，任何通过 `context.commandBus` 执行的命令都会失败
- 可能导致难以调试的运行时错误

**修复建议**:
- 移除默认实例化，改为要求必须传入 `commandBus`
- 或添加断言检查，确保 `commandBus` 不为 null

---

### 3. CommandHandler 返回类型不一致

**文件**: [command_handler.dart:15](file:///d:/Projects/node_graph_notebook/lib/core/cqrs/commands/models/command_handler.dart#L15)

**问题描述**:
`CommandHandler<T>` 接口的 `execute` 方法返回 `CommandResult`（无类型参数），但 `Command<T>` 类的 `execute` 方法返回 `Future<CommandResult<T>>`。这种类型不一致可能导致运行时类型转换错误。

**问题代码**:
```dart
// CommandHandler 接口
Future<CommandResult> execute(T command, CommandContext context);

// Command 类
Future<CommandResult<T>> execute(CommandContext context);
```

**影响**:
- 类型安全性降低
- 可能导致运行时 `TypeError`

**修复建议**:
统一返回类型为 `Future<CommandResult<T>>`

---

### 4. QueryBus 缓存类型不安全

**文件**: [query_bus.dart:112-116](file:///d:/Projects/node_graph_notebook/lib/core/cqrs/query/query_bus.dart#L112-L116)

**问题描述**:
从缓存获取的结果被强制转换为 `QueryResult<T>`，但缓存中存储的结果可能有不同的类型参数。

**问题代码**:
```dart
if (query is CacheableQuery) {
  final cachedResult = _cache.get(query);
  if (cachedResult != null) {
    return cachedResult as QueryResult<T>;  // 不安全的类型转换
  }
}
```

**影响**:
- 可能返回类型错误的数据
- 运行时 `TypeError`

**修复建议**:
- 在缓存中存储类型信息
- 或在获取缓存时验证类型

---

## 中危 Bug (Medium)

### 5. EventSubscriptionManager 类型转换不安全

**文件**: [event_subscription_manager.dart:69](file:///d:/Projects/node_graph_notebook/lib/core/cqrs/commands/events/event_subscription_manager.dart#L69)

**问题描述**:
泛型 `StreamSubscription<T>` 被强制转换为原始类型 `StreamSubscription`，丢失了类型安全性。

**问题代码**:
```dart
_subscriptions[key] = subscription as StreamSubscription;
```

**影响**:
- 类型安全性降低
- 可能导致难以追踪的错误

---

### 6. SearchIndexMaterializedView 空值断言风险

**文件**: [search_index_view.dart:87](file:///d:/Projects/node_graph_notebook/lib/core/cqrs/materialized_views/search_index_view.dart#L87)

**问题描述**:
在访问 `_invertedIndex[token]` 后立即使用 `!` 操作符，虽然逻辑上此时值不应为 null，但使用 `!` 是不安全的编码实践。

**问题代码**:
```dart
for (final token in tokens) {
  _invertedIndex[token]?.remove(nodeId);
  if (_invertedIndex[token]!.isEmpty) {  // 危险的空值断言
    _invertedIndex.remove(token);
  }
}
```

**修复建议**:
```dart
for (final token in tokens) {
  _invertedIndex[token]?.remove(nodeId);
  final tokenSet = _invertedIndex[token];
  if (tokenSet != null && tokenSet.isEmpty) {
    _invertedIndex.remove(token);
  }
}
```

---

### 7. GetNodeReadModelsQuery 缓存键潜在问题

**文件**: [list_nodes_query.dart:61](file:///d:/Projects/node_graph_notebook/lib/core/cqrs/queries/list_nodes_query.dart#L61)

**问题描述**:
当 `nodeIds` 列表很长时，缓存键会变得非常大，可能导致内存问题。此外，列表顺序影响缓存键，`[a, b]` 和 `[b, a]` 会产生不同的缓存键。

**问题代码**:
```dart
@override
String get cacheKey => 'GetNodeReadModels:${nodeIds.join(',')}';
```

**修复建议**:
- 对 `nodeIds` 排序后再生成缓存键
- 考虑使用哈希值代替完整列表

---

## 低危 Bug (Low)

### 8. QueryBus Handler 工厂立即执行

**文件**: [query_bus.dart:67](file:///d:/Projects/node_graph_notebook/lib/core/cqrs/query/query_bus.dart#L67)

**问题描述**:
Handler 工厂函数在注册时立即被调用，而不是延迟到需要时才调用，这违背了工厂模式的初衷。

**问题代码**:
```dart
_handlers[queryType] = handlerFactory() as QueryHandler;
```

**影响**:
- 无法实现延迟初始化
- 如果工厂函数有副作用，可能在非预期时机执行

---

### 9. CommandBus dispatch 方法类型转换

**文件**: [command_bus.dart:206-207](file:///d:/Projects/node_graph_notebook/lib/core/cqrs/commands/command_bus.dart#L206-L207)

**问题描述**:
`result` 被强制转换为 `CommandResult<T>`，但中间件管道返回的结果类型可能不匹配。

**问题代码**:
```dart
return allEvents.isNotEmpty
    ? result.withEvents(allEvents) as CommandResult<T>
    : result as CommandResult<T>;
```

**影响**:
- 可能导致运行时类型错误

---

## 总结

| 严重程度 | 数量 |
|---------|------|
| Critical | 1 |
| High | 3 |
| Medium | 3 |
| Low | 2 |
| **总计** | **9** |

建议优先修复 Critical 和 High 级别的 Bug，特别是 `FilterNodesQuery` 的缓存键问题和 `CommandContext` 的实例化问题。
