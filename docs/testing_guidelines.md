# 测试指南

本文档为 Node Graph Notebook 项目提供全面的测试指南。

## 测试组织

测试按层次和功能组织在 `test/` 目录中:

```
test/
├── bloc/             # BLoC 单元测试
│   ├── graph/       # GraphBloc 测试
│   ├── node/        # NodeBloc 测试
│   └── ui/          # UIBloc 测试
├── core/            # 核心逻辑测试
│   ├── events/      # 事件总线测试
│   ├── models/      # 模型测试(Node、Graph、Connection 等)
│   ├── repositories/ # 存储库测试
│   └── services/    # 服务测试(NodeService、UndoManager 等)
├── ui/              # UI 交互测试
│   ├── cross_bloc_ui_update_test.dart
│   └── ui_responsive_update_test.dart
├── performance/     # 性能基准测试
│   └── ui_update_performance_test.dart
└── widget/          # Widget 测试
    ├── app_widget_test.dart
    ├── graph_view_ui_update_test.dart
    └── user_interaction_ui_update_test.dart
```

## 运行测试

```bash
# 运行所有测试
flutter test

# 运行特定测试文件
flutter test test/bloc/graph/graph_bloc_test.dart

# 运行测试并生成覆盖率报告
flutter test --coverage
```

## 测试最佳实践

### 避免虚假测试

**什么是虚假测试?**

虚假测试避开测试核心软件问题,而是过度测试不提供真正价值的琐碎边缘情况。它们以高覆盖率但低质量创造虚假的安全感。

#### 常见反模式

**1. 过度测试简单数据模型** ❌

```dart
// ❌ 虚假测试: 测试简单属性访问
test('should return correct id', () {
  expect(user.id, '123');
});

test('should return correct name', () {
  expect(user.name, 'John');
});

// ✅ 好的测试: 测试业务逻辑
test('should validate user age', () {
  expect(() => User(age: -1), throwsException);
});
```

**应避免的示例:**
- 测试简单的 getter/setter 方法
- 测试代码生成的方法(copyWith、toJson、fromJson)
- 测试琐碎的数据结构
- 测试基本属性赋值

**2. 过度测试 UI 边缘情况** ❌

```dart
// ❌ 虚假测试: 测试极端边缘情况
test('should handle null text', () { ... });
test('should handle empty text', () { ... });
test('should handle whitespace text', () { ... });
test('should handle very long text', () { ... });
test('should handle special characters', () { ... });

// ✅ 好的测试: 测试核心用户交互
test('should submit form successfully', () { ... });
test('should show validation error', () { ... });
test('should navigate after successful submission', () { ... });
```

**应避免的示例:**
- 广泛测试 null/空/空白值
- 测试框架提供的功能
- 测试很少发生的极端边缘情况
- 测试 widget 渲染细节

**3. 测试框架功能** ❌

```dart
// ❌ 虚假测试: 测试框架功能
test('should call setState', () {
  widget.setState(() {});
  verify(() {}).called(1);
});

// ✅ 好的测试: 测试业务行为
test('should update state when user clicks button', () {
  widget.find(button).tap();
  expect(widget.state, expectedState);
});
```

### 测试价值评估

**高价值测试:**
- ✅ 测试核心业务逻辑
- ✅ 测试复杂场景
- ✅ 测试错误处理和恢复
- ✅ 测试性能和安全性
- ✅ 测试实际用户工作流

**低价值测试(虚假测试):**
- ❌ 测试简单的 getter/setter 方法
- ❌ 测试代码生成的方法
- ❌ 测试琐碎的数据结构
- ❌ 测试极端边缘情况
- ❌ 测试框架提供的功能

### 虚假测试检测清单

在编写测试之前,问自己:
- [ ] 此测试是否验证核心业务逻辑?
- [ ] 此测试是否验证复杂场景?
- [ ] 此测试是否验证错误处理?
- [ ] 此测试是否验证实际用户工作流?
- [ ] 此测试失败是否会提供有用的调试信息?
- [ ] 此测试是否易于维护?
- [ ] 此测试是否在合理时间内运行?
- [ ] 此测试是否有助于防止回归?

如果大多数答案是"否",这很可能是一个虚假测试 - 不要编写它。

## 核心测试优先级

**优先级 1: 核心功能(必须有)**
- 命令处理器(业务逻辑)
- 存储库操作(数据持久化)
- ExecutionEngine(任务执行)
- Plugin Manager(插件生命周期)

**优先级 2: 集成场景(应该有)**
- 命令总线 + 中间件管道
- 插件依赖和通信
- 事件驱动更新
- 错误恢复流程

**优先级 3: UI 工作流(最好有)**
- 用户交互路径
- 状态转换
- 导航流程
- 表单验证

**优先级 4: 边缘情况(可选)**
- Null/空处理(仅当现实时)
- 错误边界情况(仅当关键时)
- 性能边缘情况(仅当已测量时)

## 好的测试示例

### 命令处理器测试

```dart
test('should create node and publish event', () async {
  // Arrange
  final command = CreateNodeCommand(title: 'Test', content: 'Content');

  // Act
  final result = await handler.execute(command, context);

  // Assert
  expect(result.isSuccess, true);
  expect(result.data.title, 'Test');
  verify(eventBus.publish(any)).called(1);
});
```

### 存储库集成测试

```dart
test('should save and load node with metadata', () async {
  // Arrange
  final node = Node(id: '1', title: 'Test', metadata: {'key': 'value'});

  // Act
  await repository.save(node);
  final loaded = await repository.load('1');

  // Assert
  expect(loaded, isNotNull);
  expect(loaded!.metadata['key'], 'value');
});
```

### 插件生命周期测试

```dart
test('should load plugin with dependencies', () async {
  // Arrange
  final plugin = TestPlugin(dependencies: ['other_plugin']);

  // Act
  await pluginManager.loadPlugin('test_plugin');

  // Assert
  expect(pluginManager.getPlugin('test_plugin'), isNotNull);
  expect(pluginManager.getPlugin('other_plugin'), isNotNull);
});
```

## 已知问题和行动项

**ExecutionEngine 测试:**
- 10 个核心测试中有 5 个由于架构问题被跳过
- 关键功能(任务执行、错误处理)未测试
- **需要采取的行动:** 修复 isolate 通信架构并启用测试

**Handler 层测试:**
- CreateNodeHandler 没有测试
- ConnectNodesHandler 没有测试
- 大多数其他处理器缺乏测试覆盖
- **需要采取的行动:** 为所有命令处理器编写测试

**Plugin Manager 测试:**
- 缺少插件依赖的集成测试
- 缺少插件间通信的测试
- 缺少 API 导出/导入的测试
- **需要采取的行动:** 为插件系统添加集成测试

## 应避免的测试反模式

1. **不要测试琐碎的数据模型** - 专注于业务逻辑
2. **不要广泛测试 UI 边缘情况** - 专注于用户工作流
3. **不要测试框架功能** - 信任框架
4. **不要跳过核心功能测试** - 优先考虑关键路径
5. **不要为代码生成的方法编写测试** - 它们已经被测试了

**记住:** 高测试覆盖率 ≠ 高测试质量。专注于测试重要的内容,而不是容易测试的内容。
