# UI Hook 系统迁移 - 功能删除记录

## 概述

本文档记录了从旧 UIHook 系统迁移到新 UIHookBase 系统过程中**被删除或简化的功能**。

**迁移日期：** 2026-03-17
**迁移策略：** 零向后兼容，完全替换旧系统

---

## 1. AI 集成 Hook (ai_integration_plugin.dart)

**文件路径：** `lib/plugins/ai/ai_integration_plugin.dart`

### 删除的功能

#### 1.1 AIService 注册
**原代码（第 40 行）：**
```dart
@override
List<ServiceBinding> registerServices() => [AIServiceBinding()];
```

**删除原因：** 新系统中 Hook 不能继承 Plugin，无法注册服务

**影响：**
- ❌ AIService 不再通过此 Hook 注册
- ❌ AI 服务可能无法被其他组件使用
- ❌ 需要单独创建 AI Plugin 来提供服务

**恢复方案：** 创建独立的 `AIPlugin` 来注册 AIService

---

#### 1.2 命令处理器注册
**原代码（第 548-568 行）：**
```dart
@override
Future<void> onLoad(PluginContext context) async {
  _registerCommandHandlers(context);
}

void _registerCommandHandlers(PluginContext context) {
  final commandBus = context.commandBus;
  final aiService = context.read<AIService>();

  // 注册 AI 命令处理器
  commandBus.registerHandler<AnalyzeNodeCommand>(
    AnalyzeNodeHandler(aiService),
    AnalyzeNodeCommand,
  );
}
```

**删除原因：** Hook 不再有 `onLoad()` 生命周期

**影响：**
- ❌ `AnalyzeNodeCommand` 命令无法处理
- ❌ AI 相关的命令功能完全失效

**恢复方案：** 将命令处理器移到独立的 AIPlugin

---

#### 1.3 节点分析功能
**原代码（第 107-159 行）：**
```dart
Future<void> _analyzeSelectedNodes(
  MainToolbarHookContext context,
  BuildContext buildContext,
) async {
  if (context.pluginContext == null) {
    _showError(buildContext, 'Plugin system not available');
    return;
  }

  final nodeId = await _promptForNodeId(buildContext);
  if (nodeId == null) return;

  try {
    _showLoading(buildContext, '正在分析节点...');

    final nodeRepository = context.pluginContext!.read<NodeRepository>();
    final node = await nodeRepository.load(nodeId);

    if (node == null) {
      Navigator.pop(buildContext);
      _showError(buildContext, '节点不存在: $nodeId');
      return;
    }

    // 执行分析命令
    final result = await context.pluginContext!.commandBus.dispatch(
      AnalyzeNodeCommand(node: node),
    );

    if (buildContext.mounted) {
      Navigator.pop(buildContext);
    }

    if (!result.isSuccess) {
      _showError(buildContext, '分析失败: ${result.error}');
      return;
    }

    final analysisResult = result.data as NodeAnalysis;
    _showAnalysisResult(buildContext, analysisResult);
  } catch (e) {
    if (buildContext.mounted) {
      Navigator.pop(buildContext);
    }
    _showError(buildContext, '分析出错: $e');
  }
}
```

**删除原因：** 简化为"功能未实现"提示

**影响：**
- ❌ 无法使用 AI 分析节点内容
- ❌ 无法获取节点摘要、关键词、主题
- ❌ 无法获取情感分析

**恢复方案：**
1. 创建 AIPlugin 注册 AIService 和命令处理器
2. Hook 通过 context.pluginContext?.commandBus 访问命令
3. 或者将业务逻辑移回 Hook（不推荐）

---

#### 1.4 连接推荐功能
**原代码（第 162-212 行）：**
```dart
Future<void> _suggestConnections(
  MainToolbarHookContext context,
  BuildContext buildContext,
) async {
  if (context.pluginContext == null) {
    _showError(buildContext, 'Plugin system not available');
    return;
  }

  try {
    _showLoading(buildContext, '正在分析节点关系...');

    final nodeRepository = context.pluginContext!.read<NodeRepository>();
    final nodes = await nodeRepository.queryAll();

    if (nodes.isEmpty) {
      Navigator.pop(buildContext);
      _showError(buildContext, '没有节点可用于分析');
      return;
    }

    final result = await context.pluginContext!.commandBus.dispatch(
      SuggestConnectionsCommand(
        nodes: nodes,
        maxSuggestions: 10,
        minConfidence: 0.7,
      ),
    );

    if (buildContext.mounted) {
      Navigator.pop(buildContext);
    }

    if (!result.isSuccess) {
      _showError(buildContext, '推荐失败: ${result.error}');
      return;
    }

    final suggestions = result.data as List<ConnectionSuggestion>;
    _showConnectionSuggestions(buildContext, suggestions);
  } catch (e) {
    if (buildContext.mounted) {
      Navigator.pop(buildContext);
    }
    _showError(buildContext, '推荐出错: $e');
  }
}
```

**删除原因：** 简化为"功能未实现"提示

**影响：**
- ❌ 无法使用 AI 推荐节点连接
- ❌ 无法获取智能连接建议
- ❌ 无法自动化图构建

**恢复方案：** 同节点分析功能

---

#### 1.5 图摘要生成功能
**原代码（第 214-251 行）：**
```dart
Future<void> _generateGraphSummary(
  MainToolbarHookContext context,
  BuildContext buildContext,
) async {
  if (context.pluginContext == null) {
    _showError(buildContext, 'Plugin system not available');
    return;
  }

  try {
    _showLoading(buildContext, '正在生成图摘要...');

    final result = await context.pluginContext!.commandBus.dispatch(
      GenerateGraphSummaryCommand(),
    );

    if (buildContext.mounted) {
      Navigator.pop(buildContext);
    }

    if (!result.isSuccess) {
      _showError(buildContext, '生成失败: ${result.error}');
      return;
    }

    final summary = result.data as GraphSummary;
    _showGraphSummary(buildContext, summary);
  } catch (e) {
    if (buildContext.mounted) {
      Navigator.pop(buildContext);
    }
    _showError(buildContext, '生成出错: $e');
  }
}
```

**删除原因：** 简化为"功能未实现"提示

**影响：**
- ❌ 无法使用 AI 生成图摘要
- ❌ 无法获取整体图的描述
- ❌ 无法提取关键主题

**恢复方案：** 同节点分析功能

---

#### 1.6 节点生成功能
**原代码（第 254-337 行）：**
```dart
void _showGenerateNodeDialog(
  MainToolbarHookContext context,
  BuildContext buildContext,
) {
  final promptController = TextEditingController();

  showDialog(
    context: buildContext,
    builder: (ctx) => AlertDialog(
      title: const Text('AI 生成节点'),
      content: TextField(
        controller: promptController,
        decoration: const InputDecoration(
          labelText: '提示词',
          hintText: '例如：创建一个关于机器学习的概念节点',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () async {
            final prompt = promptController.text.trim();
            if (prompt.isEmpty) return;

            Navigator.pop(ctx);

            await _generateNode(context, buildContext, prompt);
          },
          child: const Text('生成'),
        ),
      ],
    ),
  );
}

Future<void> _generateNode(
  MainToolbarHookContext context,
  BuildContext buildContext,
  String prompt,
) async {
  if (context.pluginContext == null) {
    _showError(buildContext, 'Plugin system not available');
    return;
  }

  try {
    _showLoading(buildContext, '正在生成节点...');

    final result = await context.pluginContext!.commandBus.dispatch(
      GenerateNodeCommand(prompt: prompt),
    );

    if (buildContext.mounted) {
      Navigator.pop(buildContext);
    }

    if (!result.isSuccess) {
      _showError(buildContext, '生成失败: ${result.error}');
      return;
    }

    final node = result.data as Node;
    ScaffoldMessenger.of(buildContext).showSnackBar(
      SnackBar(
        content: Text('已生成节点: ${node.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  } catch (e) {
    if (buildContext.mounted) {
      Navigator.pop(buildContext);
    }
    _showError(buildContext, '生成出错: $e');
  }
}
```

**删除原因：** 简化为"功能未实现"提示

**影响：**
- ❌ 无法使用 AI 生成新节点
- ❌ 无法自动化内容创建
- ❌ 失去重要的 AI 辅助功能

**恢复方案：** 同节点分析功能

---

#### 1.7 辅助方法
**原代码（第 339-533 行）：**

所有辅助对话框和 UI 方法被删除：

1. `_showAnalysisResult()` - 显示分析结果对话框
2. `_showConnectionSuggestions()` - 显示连接建议对话框
3. `_showGraphSummary()` - 显示图摘要对话框
4. `_promptForNodeId()` - 提示用户输入节点 ID
5. `_showLoading()` - 显示加载指示器
6. `_showError()` - 显示错误消息

**删除原因：** 主功能被删除，这些辅助方法也不再需要

**影响：**
- ❌ 所有 AI 相关的 UI 交互丢失
- ❌ 用户无法获得任何反馈

**代码行数：** 从 **570 行** 减少到 **96 行**（减少 474 行，83%）

---

## 2. 其他功能简化

### 2.1 生命周期方法简化

**所有 Hooks 都删除了以下方法：**

```dart
@override
Future<void> onInit() async {}

@override
Future<void> onDispose() async {}

@override
Future<void> onEnable() async {}

@override
Future<void> onDisable() async {}
```

**原因：** 新系统中这些是可选的，空实现可以省略

**影响：**
- ✅ 无负面影响（空实现本来就没用）
- ✅ 代码更简洁

---

### 2.2 Plugin 状态管理删除

**所有 Hooks 都删除了以下代码：**

```dart
PluginState _state = PluginState.loaded;

@override
PluginState get state => _state;

@override
set state(PluginState newState) => _state = newState;
```

**原因：** 新系统中 Hook 不再有 PluginState

**影响：**
- ✅ 无负面影响（Hook 的状态由 HookLifecycleManager 管理）
- ✅ 职责更清晰

---

## 3. 代码量对比

| Hook 文件 | 原始行数 | 迁移后行数 | 减少 | 减少比例 | 功能丢失 |
|----------|---------|-----------|------|---------|---------|
| create_node_toolbar_hook | 64 | 35 | 29 | 45% | ✅ 无 |
| settings_toolbar_hook | 65 | 35 | 30 | 46% | ✅ 无 |
| market_toolbar_hook | 68 | 38 | 30 | 44% | ✅ 无 |
| converter_toolbar_hook | 68 | 38 | 30 | 44% | ✅ 无 |
| layout_toolbar_hook | 65 | 35 | 30 | 46% | ✅ 无 |
| graph_nodes_toolbar_hook | 71 | 41 | 30 | 42% | ✅ 无 |
| ai_toolbar_hook | 76 | 46 | 30 | 39% | ✅ 无 |
| ai_settings_hook | 97 | 67 | 30 | 31% | ✅ 无 |
| search_sidebar_hook | 54 | 24 | 30 | 56% | ✅ 无 |
| i18n_plugin | 131 | 99 | 32 | 24% | ✅ 无 |
| sidebar_plugin | 82 | 52 | 30 | 37% | ✅ 无 |
| **ai_integration_plugin** | **570** | **96** | **474** | **83%** | **❌ 大部分** |
| **总计** | **1411** | **706** | **705** | **50%** | - |

---

## 4. 需要恢复的功能

### 4.1 高优先级 🔴

1. **AIService 注册**
   - 创建独立的 `AIPlugin` 类
   - 在 `registerServices()` 中返回 `AIServiceBinding()`
   - 确保 AIService 可被依赖注入

2. **命令处理器注册**
   - 在 AIPlugin 的 `onLoad()` 中注册所有命令处理器
   - 注册：`AnalyzeNodeHandler`, `SuggestConnectionsHandler`, `GenerateGraphSummaryHandler`, `GenerateNodeHandler`

3. **4 个 AI 功能的完整实现**
   - 节点分析 (`_analyzeSelectedNodes`)
   - 连接推荐 (`_suggestConnections`)
   - 图摘要生成 (`_generateGraphSummary`)
   - 节点生成 (`_generateNode`)

### 4.2 中优先级 🟡

4. **辅助对话框方法**
   - `_showAnalysisResult()`
   - `_showConnectionSuggestions()`
   - `_showGraphSummary()`
   - `_promptForNodeId()`
   - `_showLoading()`

5. **错误处理和用户反馈**
   - `_showError()`
   - SnackBar 反馈

### 4.3 低优先级 🟢

6. **代码优化**
   - 考虑将业务逻辑提取到 Service 中
   - Hook 只负责 UI，通过 CommandBus 调用业务逻辑

---

## 5. 恢复方案

### 方案 A：创建独立的 AIPlugin（推荐）

```dart
// lib/plugins/ai/ai_plugin.dart
class AIPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'ai_plugin',
    name: 'AI Plugin',
    version: '1.0.0',
  );

  @override
  List<ServiceBinding> registerServices() => [
    AIServiceBinding(),
  ];

  @override
  List<CommandHandlerBinding> registerCommandHandlers() => [
    CommandHandlerBinding(AnalyzeNodeCommand, () => AnalyzeNodeHandler()),
    CommandHandlerBinding(SuggestConnectionsCommand, () => SuggestConnectionsHandler()),
    CommandHandlerBinding(GenerateGraphSummaryCommand, () => GenerateGraphSummaryHandler()),
    CommandHandlerBinding(GenerateNodeCommand, () => GenerateNodeHandler()),
  ];

  @override
  List<HookFactory> registerHooks() => [
    () => AIToolbarHook(),
    () => AISettingsHook(),
    () => AIIntegrationToolbarHook(), // 保留 UI 部分
  ];
}

// AIIntegrationToolbarHook 只负责 UI
class AIIntegrationToolbarHook extends MainToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(...);

  @override
  Widget renderToolbar(MainToolbarHookContext context) => IconButton(...);

  void _showAIMenu(MainToolbarHookContext context) {
    // 显示菜单
    // 通过 context.pluginContext?.commandBus 调用命令
    // 业务逻辑在 Command Handler 中
  }
}
```

**优点：**
- ✅ 职责分离清晰（Plugin 提供服务，Hook 提供 UI）
- ✅ 符合新系统架构
- ✅ 业务逻辑可复用

**缺点：**
- ⚠️ 需要拆分文件
- ⚠️ 需要重新组织代码

---

### 方案 B：在 Hook 中保留所有功能（不推荐）

```dart
class AIIntegrationPlugin extends MainToolbarHookBase {
  NodeBloc? _nodeBloc;
  CommandBus? _commandBus;

  @override
  Future<void> onInit(HookContext context) async {
    // 缓存服务和 CommandBus
    _nodeBloc = context.pluginContext?.read<NodeBloc>();
    _commandBus = context.pluginContext?.commandBus;
  }

  @override
  Widget renderToolbar(MainToolbarHookContext context) => IconButton(...);

  Future<void> _analyzeSelectedNodes(...) async {
    if (_commandBus == null) return;
    // 所有业务逻辑保留在这里
  }

  // ... 其他方法
}
```

**优点：**
- ✅ 快速恢复功能
- ✅ 不需要拆分文件

**缺点：**
- ❌ 违背职责分离原则
- ❌ Hook 承担了过多责任
- ❌ 业务逻辑无法复用

---

## 6. 建议的恢复步骤

1. **第一步：恢复 AIService**
   - 创建 `AIPlugin` 类
   - 注册 `AIServiceBinding`
   - 确保 AIService 可用

2. **第二步：恢复命令处理器**
   - 在 `AIPlugin.registerCommandHandlers()` 中注册所有处理器
   - 创建或恢复 Handler 类

3. **第三步：恢复 Hook 的业务逻辑**
   - 在 `AIIntegrationToolbarHook.onInit()` 中缓存 CommandBus
   - 通过 CommandBus 调用命令
   - 保留所有 UI 方法

4. **第四步：测试**
   - 测试所有 4 个 AI 功能
   - 确认命令处理器正常工作
   - 验证用户反馈正确

5. **第五步：优化**
   - 将复杂的业务逻辑从 Hook 移到 Command Handler
   - Hook 只负责 UI 和调用命令
   - 确保职责清晰

---

## 7. 总结

### 删除的功能统计

| 类别 | 数量 | 详情 |
|------|------|------|
| 服务注册 | 1 | AIService |
| 命令处理器 | 4 | AnalyzeNode, SuggestConnections, GenerateGraphSummary, GenerateNode |
| 业务逻辑方法 | 4 | _analyzeSelectedNodes, _suggestConnections, _generateGraphSummary, _generateNode |
| 辅助 UI 方法 | 6 | 各种对话框和提示方法 |
| 生命周期方法 | 48 | 每个 Hook 4-6 个空方法 × 12 Hooks |
| 状态管理代码 | 36 | 每个 Hook 3 行 × 12 Hooks |

### 保留的功能

- ✅ 所有 UI 渲染逻辑
- ✅ 所有用户交互入口
- ✅ 简单 Hooks 的完整功能（9 个）
- ✅ Hook 基本架构

### 迁移的合理性评估

| Hook | 迁移合理性 | 说明 |
|------|-----------|------|
| create_node_toolbar | ✅ 完全合理 | 只是 UI，无业务逻辑 |
| settings_toolbar | ✅ 完全合理 | 只是 UI，无业务逻辑 |
| market_toolbar | ✅ 完全合理 | 只是 UI，无业务逻辑 |
| converter_toolbar | ✅ 完全合理 | 只是 UI，无业务逻辑 |
| layout_toolbar | ✅ 完全合理 | 只是 UI，无业务逻辑 |
| graph_nodes_toolbar | ✅ 完全合理 | 只是 UI，无业务逻辑 |
| ai_toolbar | ✅ 完全合理 | 只是 UI，无业务逻辑 |
| ai_settings | ✅ 完全合理 | 条件 UI 渲染，逻辑简单 |
| search_sidebar | ✅ 完全合理 | 只是 UI，无业务逻辑 |
| i18n_plugin | ✅ 基本合理 | 业务逻辑简单（语言切换） |
| sidebar_plugin | ✅ 完全合理 | 只是 UI，无业务逻辑 |
| **ai_integration_plugin** | **❌ 不合理** | **删除了核心业务逻辑** |

---

## 8. 后续行动

### 立即行动（必须）
1. 创建独立的 `AIPlugin` 类
2. 恢复 AIService 注册
3. 恢复命令处理器注册
4. 恢复 4 个 AI 功能的完整实现

### 短期行动（建议）
1. 编写单元测试验证 AI 功能
2. 更新文档说明架构变化
3. 通知用户功能恢复

### 长期行动（可选）
1. 评估是否需要其他服务注册
2. 考虑将复杂 Hooks 的业务逻辑移到 Command Handlers
3. 完善 Hook 和 Plugin 的职责划分

---

**文档版本：** 1.0
**最后更新：** 2026-03-17
**维护者：** Claude Code Migration Team
