# 系统架构文档

## 项目概述

**Node Graph Notebook** 是一个基于 Flutter 的概念地图笔记应用，采用可视化节点图来组织知识，支持 Markdown 编辑、AI 辅助生成、插件扩展等高级功能。

### 核心理念

- **一切皆节点**：内容节点、概念节点（关系即节点）统一为 Node 模型
- **数学优雅**：通过 content + references 映射自然形成有向图，无需冗余连接字段
- **可视化组织**：使用 Flame 游戏引擎渲染可交互的节点图
- **AI 增强**：集成 AI 服务进行内容生成和关系分析
- **高度可扩展**：提供类似 Obsidian 的插件系统
- **双向转换**：Markdown 与节点图之间无缝转换

## 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Presentation Layer                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  UI Pages    │  │  UI Widgets  │  │ Flame Render │       │
│  │  (Flutter)   │  │  (Flutter)   │  │   (Flame)    │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
                           ↕
┌─────────────────────────────────────────────────────────────┐
│                    Business Services Layer                   │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐    │
│  │  Node    │  │  Graph   │  │ Concept  │  │  AI      │    │
│  │ Service  │  │ Service  │  │ Service  │  │ Service  │    │
│  ├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤    │
│  │Converter │  │  Layout  │  │Plugin    │  │Reference │    │
│  │ Service  │  │ Service  │  │ Host     │  │ Service  │    │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘    │
└─────────────────────────────────────────────────────────────┘
                           ↕
┌─────────────────────────────────────────────────────────────┐
│                        Data Layer                            │
│  ┌──────────────────┐          ┌──────────────────┐         │
│  │  NodeRepository  │          │ GraphRepository  │         │
│  └──────────────────┘          └──────────────────┘         │
└─────────────────────────────────────────────────────────────┘
                           ↕
┌─────────────────────────────────────────────────────────────┐
│                   Storage Layer (File System)                │
│  data/nodes/*.md    data/graphs/*.json   data/plugins/       │
└─────────────────────────────────────────────────────────────┘
```

## 核心设计模式

### 1. 统一节点模型

所有元素（内容、关系、概念）都继承自统一的 `Node` 模型：

```dart
class Node {
  final String id;
  final NodeType type;                    // content | concept
  final String title;
  final String? content;                  // Markdown内容
  final Map<String, NodeReference> references;  // 涉及的节点映射
  final Offset position;
  final Size size;
  // ... 其他属性
}

class NodeReference {
  final String nodeId;                    // 被引用的节点ID
  final ReferenceType type;               // 引用类型
  final String? role;                     // 角色/标签
  final Map<String, dynamic>? metadata;
}
```

**核心思想**：
- **content**: 节点自己的内容
- **references**: 节点涉及的其他节点映射
- 通过 references 自然形成有向图，无需冗余的 connections 字段
- 支持高阶关系（关系的关系）

**优势**：
- 数学优雅，单一数据源
- 统一的操作接口（CRUD）
- 灵活的关系类型（通过 ReferenceType 枚举）
- 易于实现"关系即节点"

### 2. 分层架构

- **Presentation Layer**: Flutter UI + Flame 渲染
- **Business Layer**: 业务逻辑和服务
- **Data Layer**: 数据访问抽象
- **Storage Layer**: 文件系统持久化

### 3. 插件系统

采用 **Host-Plugin** 模式：
- 插件通过 `PluginAPI` 访问应用功能
- 事件驱动，支持生命周期钩子
- 沙箱隔离，错误不影响主应用

### 4. MVVM + Provider

使用 Provider 进行状态管理：
- `NodeModel`: 管理节点状态
- `GraphModel`: 管理图状态
- `UIModel`: 管理 UI 状态

**Provider 组织结构**：

```dart
// main.dart - Provider 树
MultiProvider(
  providers: [
    // 1. 数据层 Provider
    Provider<NodeRepository>(
      create: (_) => NodeRepository(),
    ),
    Provider<GraphRepository>(
      create: (_) => GraphRepository(),
    ),

    // 2. 服务层 Provider
    Provider<NodeService>(
      create: (ctx) => NodeService(
        repository: ctx.read<NodeRepository>(),
      ),
    ),
    Provider<GraphService>(
      create: (ctx) => GraphService(
        repository: ctx.read<GraphRepository>(),
      ),
    ),
    ChangeNotifierProvider<AIService>(
      create: (ctx) => AIService(),
    ),

    // 3. 状态 Model Provider
    ChangeNotifierProvider<NodeModel>(
      create: (ctx) => NodeModel(
        service: ctx.read<NodeService>(),
      ),
    ),
    ChangeNotifierProvider<GraphModel>(
      create: (ctx) => GraphModel(
        service: ctx.read<GraphService>(),
      ),
    ),
    ChangeNotifierProvider<UIModel>(
      create: (_) => UIModel(),
    ),
  ],
  child: MyApp(),
)

// 使用示例
class NodeList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<NodeModel>();
    final service = context.read<NodeService>();

    return ListView.builder(
      itemCount: model.nodes.length,
      itemBuilder: (ctx, i) => NodeCard(model.nodes[i]),
    );
  }
}
```

**状态更新流程**：

```
用户操作 → UI Widget
              ↓
          context.read<Service>().method()
              ↓
          Service 执行业务逻辑
              ↓
          Repository.save()
              ↓
          context.read<Model>().updateState()
              ↓
          notifyListeners() → UI 自动重建
```

### 5. 路由管理

使用 **GoRouter** 进行声明式路由：

```dart
// router.dart
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => HomePage(),
    ),
    GoRoute(
      path: '/graph/:graphId',
      builder: (context, state) {
        final graphId = state.pathParameters['graphId']!;
        return GraphPage(graphId: graphId);
      },
    ),
    GoRoute(
      path: '/node/:nodeId',
      builder: (context, state) {
        final nodeId = state.pathParameters['nodeId']!;
        return NodeEditorPage(nodeId: nodeId);
      },
    ),
    GoRoute(
      path: '/converter',
      builder: (context, state) => ConverterPage(),
    ),
    GoRoute(
      path: '/ai-assistant',
      builder: (context, state) => AIAssistantPage(),
    ),
  ],
  errorBuilder: (context, state) => NotFoundPage(),
)

// 使用
MaterialApp.router(
  routerConfig: router,
)
```

## 模块说明

### 核心模块 (core/)

#### models/
- `node.dart`: 统一节点模型
- `node_reference.dart`: 节点引用模型
- `graph.dart`: 图结构模型
- `connection.dart`: 连接关系（计算属性，从 references 得出）
- `view_mode.dart`: 视图模式枚举
- `conversion_rule.dart`: 转换规则模型

#### repositories/
- `node_repository.dart`: 节点数据持久化
- `graph_repository.dart`: 图结构持久化

#### services/
- `node_service.dart`: 节点业务逻辑
- `graph_service.dart`: 图管理服务
- `reference_service.dart`: 引用关系管理
- `concept_service.dart`: 概念节点专用服务
- `converter_service.dart`: Markdown ↔ 节点转换
- `layout_service.dart`: 自动布局算法
- `ai_service.dart`: AI 服务接口
- `plugin_host_service.dart`: 插件宿主

### 转换模块 (converter/)

实现 Markdown 与节点图的双向转换：

#### markdown_parser.dart
- 解析 Markdown 文件
- 根据规则拆分为节点
- 提取标题、标签、链接

#### markdown_generator.dart
- 将节点列表合并为 Markdown
- 支持多种合并策略
- 生成目录和结构

#### parsing_rules/
- `heading_split_rule.dart`: 按标题级别拆分
- `separator_split_rule.dart`: 按分割符拆分
- `ai_smart_split_rule.dart`: AI 智能拆分
- `custom_regex_rule.dart`: 自定义正则规则

#### merging_rules/
- `hierarchy_merge_rule.dart`: 层级合并
- `sequence_merge_rule.dart`: 顺序合并
- `custom_merge_rule.dart`: 自定义合并

### AI 模块 (ai/)

#### ai_client.dart
- AI 服务抽象接口
- 支持多种 AI 提供商

#### ai_providers/
- `openai_provider.dart`: OpenAI GPT
- `anthropic_provider.dart`: Claude
- `ollama_provider.dart`: 本地 Ollama
- `custom_provider.dart`: 自定义 API

#### generators/
- `node_generator.dart`: 生成节点内容
- `connection_generator.dart`: 推荐连接关系
- `concept_generator.dart`: 提取概念节点

#### prompts/
- `node_generation_prompt.dart`: 节点生成提示词
- `connection_prompt.dart`: 关系提取提示词
- `concept_prompt.dart`: 概念分析提示词

### 渲染模块 (flame/)

使用 Flame 游戏引擎渲染交互式节点图：

#### graph_world.dart
- Flame World 根节点
- 管理所有渲染组件
- 处理相机和视口

#### components/
- `node_component.dart`: 统一节点渲染组件
- `connection_renderer.dart`: 连接线渲染
- `background_component.dart`: 背景网格

#### systems/
- `drag_system.dart`: 拖拽交互
- `selection_system.dart`: 节点选择
- `node_creation_system.dart`: 创建节点

#### layout/
- `force_directed_layout.dart`: 力导向布局
- `hierarchical_layout.dart`: 层级布局
- `circular_layout.dart`: 环形布局
- `concept_map_layout.dart`: 概念地图布局

### 插件系统 (plugins/)

#### plugin_api.dart
- 插件 API 定义
- 暴露给插件的功能接口

#### hooks/
- `lifecycle_hooks.dart`: 生命周期钩子
- `event_hooks.dart`: 事件监听钩子
- `data_hooks.dart`: 数据操作钩子
- `ui_hooks.dart`: UI 扩展钩子

#### plugin_loader.dart
- 动态加载插件
- 解析 manifest.json

#### plugin_sandbox.dart
- 插件沙箱隔离
- 权限管理
- 错误捕获

#### builtin_plugins/
- `ai_assistant_plugin.dart`: AI 助手
- `converter_plugin.dart`: 转换工具
- `template_plugin.dart`: 模板系统

### UI 模块 (ui/)

#### pages/
- `notebook_page.dart`: 主笔记页面
- `editor_page.dart`: Markdown 编辑器
- `converter_page.dart`: 转换配置页面
- `ai_assistant_page.dart`: AI 助手页面
- `plugin_market_page.dart`: 插件市场

#### widgets/
- `node_card.dart`: 节点卡片 Widget
- `concept_node_card.dart`: 概念节点样式
- `markdown_viewer.dart`: Markdown 查看器
- `control_panel.dart`: 控制面板
- `view_mode_switcher.dart`: 视图切换器
- `plugin_settings_panel.dart`: 插件设置

## 数据流

### 创建节点流程

```
用户操作 → UI Event → NodeService.createNode()
                      ↓
                  NodeRepository.save()
                      ↓
                  文件系统存储
                      ↓
                  GraphService.addNode()
                      ↓
                  FlameComponent.addNode()
                      ↓
                  UI 更新
```

### Markdown 转换流程

```
选择 MD 文件 → ConverterService.markdownToNodes()
               ↓
           解析规则选择
               ↓
           MarkdownParser.parse()
               ↓
           创建节点列表
               ↓
           建立连接关系
               ↓
           更新图结构
```

### AI 生成流程

```
用户输入提示 → AIService.generateNode()
               ↓
           选择 AI Provider
               ↓
           构建提示词
               ↓
           调用 AI API
               ↓
           解析响应
               ↓
           创建节点
```

## 技术栈

| 层级 | 技术 | 用途 |
|------|------|------|
| **UI 框架** | Flutter | 跨平台应用框架 |
| **Markdown** | flutter_markdown | Markdown 渲染 |
| **游戏引擎** | Flame | 节点图渲染和交互 |
| **状态管理** | Provider | 状态管理 |
| **AI 集成** | openai, anthropic | AI 服务 |
| **文件存储** | path_provider | 文件路径 |
| **序列化** | json_annotation | JSON 序列化 |
| **UUID** | uuid | 唯一标识生成 |

## 目录结构

```
node_graph_notebook/
├── lib/                          # 源代码
│   ├── main.dart                 # 应用入口
│   ├── core/                     # 核心模块
│   ├── converter/                # 转换模块
│   ├── ai/                       # AI 模块
│   ├── flame/                    # 渲染模块
│   ├── plugins/                  # 插件系统
│   ├── ui/                       # UI 模块
│   └── utils/                    # 工具类
├── data/                         # 运行时数据
│   ├── nodes/                    # Markdown 文件
│   ├── graphs/                   # 图结构 JSON
│   ├── plugins/                  # 插件
│   └── settings/                 # 应用设置
├── docs/                         # 文档
│   ├── architecture/             # 架构文档
│   ├── features/                 # 功能文档
│   └── api/                      # API 文档
├── plugins/                      # 示例插件
├── test/                         # 测试
└── pubspec.yaml                  # 依赖配置
```

## 扩展性设计

### 1. 节点类型扩展

添加新的节点类型只需：
1. 在 `NodeType` 枚举中添加新类型
2. 在 `NodeComponent` 中添加渲染逻辑
3. 更新 `ViewMode` 支持

### 2. AI 提供商扩展

实现 `AIClient` 接口：
```dart
class CustomProvider implements AIClient {
  @override
  Future<String> generate(String prompt) {
    // 自定义实现
  }
}
```

### 3. 布局算法扩展

实现布局接口：
```dart
class CustomLayout implements LayoutAlgorithm {
  @override
  void layout(List<Node> nodes) {
    // 自定义布局逻辑
  }
}
```

### 4. 插件开发

插件通过 `PluginAPI` 访问应用功能：
```dart
class MyPlugin extends Plugin {
  @override
  void onLoad(PluginAPI api) {
    api.events.onNodeCreate.listen((node) {
      // 处理节点创建事件
    });
  }
}
```

## 性能优化

### 1. 虚拟化渲染
- 只渲染视口内的节点
- 使用 Flame 的 culling 功能

### 2. 懒加载
- Markdown 内容按需加载
- 图片延迟加载

### 3. 异步操作
- 文件 I/O 使用 Isolate
- AI 请求异步处理

### 4. 缓存策略
- 节点元数据缓存
- 渲染结果缓存

## 安全性

### 1. 插件沙箱
- 使用 Isolate 隔离插件
- 权限白名单机制
- 错误捕获和隔离

### 2. 数据验证
- JSON Schema 验证
- Markdown 清理
- 路径遍历防护

### 3. API 安全
- AI API 密钥加密存储
- 请求速率限制
- 输入验证和清理

## 错误处理和监控

### 全局错误处理

```dart
// main.dart
void main() {
  // 捕获 Flutter 框架错误
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    ErrorLogger.log(details.exception, details.stack);
  };

  // 捕获异步错误
  PlatformDispatcher.instance.onError = (error, stack) {
    ErrorLogger.log(error, stack);
    return true;
  };

  runApp(MyApp());
}

// error_logger.dart
class ErrorLogger {
  static void log(Object error, StackTrace? stack) {
    // 1. 记录到日志文件
    _writeToLogFile(error, stack);

    // 2. 显示用户友好的错误提示
    if (kDebugMode) {
      debugPrint('Error: $error\n$stack');
    }

    // 3. 上报到分析服务（可选）
    // AnalyticsService.reportError(error, stack);
  }

  static void _writeToLogFile(Object error, StackTrace? stack) async {
    final logFile = File('data/logs/errors.log');
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] $error\n$stack\n\n';
    await logFile.writeAsString(logEntry, mode: FileMode.append);
  }
}
```

### Service 层错误处理

```dart
// node_service.dart
class NodeService {
  Future<Node> createNode({
    required String title,
    String? content,
  }) async {
    try {
      // 1. 参数验证
      _validateTitle(title);

      // 2. 业务逻辑
      final node = Node(
        id: uuid.v4(),
        title: title,
        content: content,
      );

      // 3. 持久化
      await repository.save(node);

      return node;
    } on ValidationError catch (e) {
      // 验证错误 - 用户输入问题
      throw UserFriendlyException(e.message);
    } on FileSystemException catch (e) {
      // 文件系统错误 - IO 问题
      throw ServiceException('无法保存节点: ${e.message}');
    } catch (e) {
      // 未知错误
      ErrorLogger.log(e, StackTrace.current);
      throw ServiceException('创建节点时发生未知错误');
    }
  }
}
```

### UI 层错误处理

```dart
// node_creation_dialog.dart
class NodeCreationDialog extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        try {
          final node = await context.read<NodeService>().createNode(
            title: _titleController.text,
            content: _contentController.text,
          );
          Navigator.of(context).pop(node);
        } on UserFriendlyException catch (e) {
          // 显示错误提示
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        } catch (e) {
          // 未知错误
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('创建失败，请稍后重试')),
          );
          ErrorLogger.log(e, StackTrace.current);
        }
      },
      child: Text('创建'),
    );
  }
}
```

### 性能监控

```dart
// performance_monitor.dart
class PerformanceMonitor {
  static final Map<String, Stopwatch> _operations = {};

  static void startOperation(String name) {
    _operations[name] = Stopwatch()..start();
  }

  static void endOperation(String name) {
    final stopwatch = _operations[name];
    if (stopstopwatch != null) {
      stopwatch.stop();
      final duration = stopwatch.elapsedMilliseconds;

      // 记录慢操作
      if (duration > 100) {
        debugPrint('[Performance] $name took ${duration}ms');
      }

      _operations.remove(name);
    }
  }
}

// 使用
Future<List<Node>> getAllNodes() async {
  PerformanceMonitor.startOperation('getAllNodes');
  try {
    final nodes = await repository.getAll();
    return nodes;
  } finally {
    PerformanceMonitor.endOperation('getAllNodes');
  }
}
```

## 测试策略

### 单元测试
- 业务逻辑测试
- 数据模型测试
- 工具函数测试

### Widget 测试
- UI 组件测试
- 用户交互测试

### 集成测试
- 端到端流程测试
- 插件系统集成测试

## 部署

### 平台支持
- Windows
- macOS
- Linux
- Android
- iOS

### 打包
```bash
# Windows
flutter build windows

# macOS
flutter build macos

# Linux
flutter build linux
```

## 版本规划

### v0.1.0 - MVP (Minimum Viable Product)
**目标**: 验证核心概念

**功能**:
- ✅ 基础节点创建和编辑
- ✅ Flame 渲染节点图
- ✅ Markdown 基础支持
- ✅ 简单拖拽交互
- ✅ 节点位置保存/加载

**技术债务**:
- 临时数据存储（内存）
- 无错误处理
- 无测试

### v0.2.0 - 数据持久化
**目标**: 完善数据层

**功能**:
- 📝 节点文件系统存储
- 📝 图结构持久化
- 📝 元数据索引
- 📝 数据迁移机制
- 📝 基本错误处理

**技术改进**:
- 实现 Repository 模式
- 添加数据验证
- 添加日志系统

### v0.3.0 - 交互增强
**目标**: 提升用户体验

**功能**:
- 📝 节点连接和断开
- 📝 多种视图模式
- 📝 缩放和平移
- 📝 节点选择和批量操作
- 📝 撤销/重做

**技术改进**:
- Flame 交互系统优化
- 状态管理完善
- 性能优化

### v0.5.0 - 核心功能
**目标**: 实现差异化功能

**功能**:
- ⏳ Markdown ↔ 节点转换
  - 按标题拆分
  - 按分隔符拆分
  - 自动提取 wiki-links
- ⏳ AI 内容生成
  - 基础节点生成
  - 内容扩展
  - 摘要生成
- ⏳ 概念地图模式
  - 概念节点创建
  - 关系可视化
- ⏳ 自动布局
  - 力导向布局
  - 层级布局

**技术改进**:
- AI 服务集成
- Markdown 解析器
- 布局算法实现

### v0.8.0 - 高级功能
**目标**: 提升效率和可用性

**功能**:
- ⏳ 智能拆分（AI 语义分析）
- ⏳ 关系推荐
- ⏳ 概念自动提取
- ⏳ 全文搜索
- ⏳ 标签系统
- ⏳ 快捷键支持
- ⏳ 主题切换

**技术改进**:
- 搜索索引
- AI 提示词优化
- 键盘事件处理

### v1.0.0 - 完整功能
**目标**: 生产就绪

**功能**:
- ⏳ 插件系统
  - 插件 API
  - 插件加载器
  - 沙箱隔离
  - 示例插件
- ⏳ 导入导出
  - Markdown 批量导入
  - PDF 导出
  - 图片导出
- ⏳ 协作功能（可选）
  - 节点分享
  - 变更历史
- ⏳ 完整测试覆盖
  - 单元测试 >80%
  - 集成测试
  - E2E 测试

**技术改进**:
- 完整错误处理
- 性能优化
- 安全加固
- 完整文档

### v1.x - 未来扩展
- 云同步
- 移动端支持
- 多人实时协作
- AI 模型微调
- 插件市场

## 参考资源

- [Flutter 文档](https://flutter.dev/docs)
- [Flame 引擎](https://flame-engine.org/)
- [flutter_markdown](https://pub.dev/packages/flutter_markdown)
- [Obsidian 插件开发](https://docs.obsidian.md/Plugins/Getting+started/Build+a+plugin)
- [Concept Maps 理论](https://en.wikipedia.org/wiki/Concept_map)
