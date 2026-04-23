# Execution 模块 Bug 报告

审查范围: `lib/core/execution/`

审查日期: 2026-04-20

---

## Bug 1: `_taskRegistry` 未在 `shutdown()` 中清理

**文件**: [execution_engine.dart](file:///d:/Projects/node_graph_notebook/lib/core/execution/execution_engine.dart)

**位置**: 第 123-129 行

**严重程度**: 中等

**问题描述**:

`shutdown()` 方法清理了 `_pool` 和 `_taskTypeToFunctionName`，但没有清理 `_taskRegistry`。这会导致以下问题：

1. 如果引擎被关闭后重新初始化，旧的 `_taskRegistry` 引用仍然存在
2. 如果 `initialize()` 再次被调用时不传入 `taskRegistry` 参数，`_taskRegistry` 将保留旧值
3. 这可能导致内存泄漏和状态不一致

**问题代码**:

```dart
Future<void> shutdown() async {
  if (_pool != null) {
    await _pool!.dispose();
    _pool = null;
    _taskTypeToFunctionName.clear();
    // _taskRegistry 未被清理!
  }
}
```

**修复建议**:

```dart
Future<void> shutdown() async {
  if (_pool != null) {
    await _pool!.dispose();
    _pool = null;
    _taskTypeToFunctionName.clear();
    _taskRegistry = null;  // 添加此行
  }
}
```

---

## Bug 2: 方法参数缺少泛型类型

**文件**: [execution_engine.dart](file:///d:/Projects/node_graph_notebook/lib/core/execution/execution_engine.dart)

**位置**: 第 95 行, 第 131 行

**严重程度**: 低

**问题描述**:

`CPUTask` 是泛型类 `CPUTask<T>`，但在以下方法签名中使用了原始类型：

- 第 95 行: `T _convertResult<T>(CPUTask task, dynamic result)`
- 第 131 行: `Map<String, dynamic> _serializeTask(CPUTask task)`

使用原始类型会丢失类型信息，可能导致运行时类型错误。

**问题代码**:

```dart
T _convertResult<T>(CPUTask task, dynamic result) {  // CPUTask 缺少泛型参数
  // ...
}

Map<String, dynamic> _serializeTask(CPUTask task) => task.serialize();  // CPUTask 缺少泛型参数
```

**修复建议**:

```dart
T _convertResult<T>(CPUTask<T> task, dynamic result) {
  // ...
}

Map<String, dynamic> _serializeTask(CPUTask<dynamic> task) => task.serialize();
```

---

## Bug 3: `ResultConverter` 使用原始类型

**文件**: [task_registry.dart](file:///d:/Projects/node_graph_notebook/lib/core/execution/task_registry.dart)

**位置**: 第 54 行, 第 82 行

**严重程度**: 中等

**问题描述**:

`ResultConverter` 定义为泛型类型 `ResultConverter<T>`，但在 `_converters` 映射中使用了原始类型：

```dart
final Map<String, ResultConverter> _converters = {};  // 原始类型
```

这导致：
1. 类型安全丧失
2. 编译器无法检查类型一致性
3. 可能导致运行时 `TypeError`

**问题代码**:

```dart
final Map<String, ResultConverter> _converters = {};  // 应该指定泛型参数
```

**修复建议**:

由于 Dart 的类型系统限制，可以使用 `dynamic` 或保持现状但添加注释说明：

```dart
final Map<String, ResultConverter<dynamic>> _converters = {};
```

---

## Bug 4: `convertResult` 中的不安全类型转换

**文件**: [task_registry.dart](file:///d:/Projects/node_graph_notebook/lib/core/execution/task_registry.dart)

**位置**: 第 163 行

**严重程度**: 高

**问题描述**:

`convertResult<T>` 方法执行了不安全的类型转换：

```dart
return converter(result) as T;
```

由于 `_converters` 存储的是 `ResultConverter<dynamic>`，转换器的返回类型在编译时未知。这个 `as T` 转换在运行时可能失败，导致 `TypeError`。

**问题代码**:

```dart
T convertResult<T>(String taskType, dynamic result) {
  final converter = _converters[taskType];

  if (converter == null) {
    throw UnsupportedError('No result converter for task type: $taskType. '
        'Did you forget to register a converter?');
  }

  return converter(result) as T;  // 不安全的类型转换
}
```

**修复建议**:

添加类型检查和更友好的错误信息：

```dart
T convertResult<T>(String taskType, dynamic result) {
  final converter = _converters[taskType];

  if (converter == null) {
    throw UnsupportedError('No result converter for task type: $taskType. '
        'Did you forget to register a converter?');
  }

  final converted = converter(result);
  if (converted is! T) {
    throw TypeError();
  }
  return converted;
}
```

---

## Bug 5: `registerAll` 方法缺少一致性检查

**文件**: [task_registry.dart](file:///d:/Projects/node_graph_notebook/lib/core/execution/task_registry.dart)

**位置**: 第 88-95 行

**严重程度**: 低

**问题描述**:

`registerAll` 方法分别注册工厂和转换器，但没有验证 `factories` 和 `converters` 的键是否匹配。这可能导致：

1. 某些任务类型只有工厂没有转换器
2. 某些任务类型只有转换器没有工厂
3. 运行时出现 `UnsupportedError`

**问题代码**:

```dart
void registerAll(Map<String, CPUTaskFactory> factories, Map<String, ResultConverter> converters) {
  for (final entry in factories.entries) {
    _factories[entry.key] = entry.value;
  }
  for (final entry in converters.entries) {
    _converters[entry.key] = entry.value;
  }
  // 没有验证键的一致性
}
```

**修复建议**:

添加断言或警告：

```dart
void registerAll(Map<String, CPUTaskFactory> factories, Map<String, ResultConverter> converters) {
  assert(
    factories.keys.toSet().difference(converters.keys.toSet()).isEmpty,
    'Some task types have factories but no converters',
  );
  assert(
    converters.keys.toSet().difference(factories.keys.toSet()).isEmpty,
    'Some task types have converters but no factories',
  );
  
  for (final entry in factories.entries) {
    _factories[entry.key] = entry.value;
  }
  for (final entry in converters.entries) {
    _converters[entry.key] = entry.value;
  }
}
```

---

## 总结

| Bug ID | 文件 | 严重程度 | 状态 |
|--------|------|----------|------|
| Bug 1 | execution_engine.dart | 中等 | 待修复 |
| Bug 2 | execution_engine.dart | 低 | 待修复 |
| Bug 3 | task_registry.dart | 中等 | 待修复 |
| Bug 4 | task_registry.dart | 高 | 待修复 |
| Bug 5 | task_registry.dart | 低 | 待修复 |
