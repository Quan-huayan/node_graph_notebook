# 数据模型文档

## 概述

本文档详细说明 Node Graph Notebook 的核心数据模型设计。所有元素统一为 `Node` 模型，实现"一切皆节点"的设计理念。

## 核心模型

## 节点的数学模型

节点通过两个核心属性定义图结构：

1. **content**: 节点自己的内容（Markdown 格式）
2. **references**: 一个映射，记录该节点涉及的其他节点及其关系类型

这种设计自然形成有向图，无需冗余的连接字段。

### 节点类型说明

#### 内容节点（`NodeType.content`）
- 存储具体的笔记内容
- 通过 `references` 提及其他节点，形成引用关系

#### 概念节点（`NodeType.concept`）
- 表示关系、分类或抽象概念
- 通过 `references` 的 `contains` 类型组织子节点
- 可以包含描述性内容
- 支持高阶关系（关系的关系）

### Node（统一节点模型）

```dart
class Node {
  /// 唯一标识符
  final String id;

  /// 节点类型
  final NodeType type;

  /// 节点标题
  final String title;

  /// Markdown 内容（可选）
  final String? content;

  /// 涉及的节点映射（key: 节点ID, value: 引用关系）
  final Map<String, NodeReference> references;

  /// 位置坐标
  final Offset position;

  /// 节点尺寸
  final Size size;

  /// 显示模式
  final NodeViewMode viewMode;

  /// 颜色
  final String? color;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 元数据
  final Map<String, dynamic> metadata;

  /// 便捷方法
  String get typeLabel => type.name;
  bool get isConcept => type == NodeType.concept;
  bool get isContent => type == NodeType.content;

  /// 获取所有引用的节点ID
  List<String> get referencedNodeIds => references.keys.toList();

  /// 获取特定类型的引用
  List<NodeReference> getReferencesByType(ReferenceType type) {
    return references.values.where((r) => r.type == type).toList();
  }

  /// 复制并更新部分字段
  Node copyWith({
    String? id,
    NodeType? type,
    String? title,
    String? content,
    Map<String, NodeReference>? references,
    Offset? position,
    Size? size,
    NodeViewMode? viewMode,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? metadata,
  });
}
```

### NodeReference（节点引用）

```dart
/// 节点引用关系
class NodeReference {
  /// 被引用的节点ID
  final String nodeId;

  /// 引用类型
  final ReferenceType type;

  /// 在当前节点中的角色或标签（可选）
  final String? role;

  /// 额外元数据
  final Map<String, dynamic>? metadata;

  const NodeReference({
    required this.nodeId,
    required this.type,
    this.role,
    this.metadata,
  });

  /// 转换为JSON
  Map<String, dynamic> toJson() => {
    'node_id': nodeId,
    'type': type.name,
    'role': role,
    if (metadata != null) 'metadata': metadata,
  };

  /// 从JSON创建
  factory NodeReference.fromJson(Map<String, dynamic> json) => NodeReference(
    nodeId: json['node_id'] as String,
    type: ReferenceType.values.firstWhere((e) => e.name == json['type']),
    role: json['role'] as String?,
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
}
```

### ReferenceType（引用类型）

```dart
enum ReferenceType {
  /// 提及：在content中提到了该节点
  mentions,

  /// 包含：概念节点包含该节点（一阶关系）
  contains,

  /// 依赖：当前节点依赖于该节点
  dependsOn,

  /// 导致：当前节点导致该节点（因果关系）
  causes,

  /// 属于：当前节点属于该节点（分类关系）
  partOf,

  /// 关联：一般性关联
  relatesTo,

  /// 引用：引用或参考
  references,

  /// 实例化：当前节点是该节点的实例
  instanceOf,
}
```

### 引用类型示例

```dart
// 示例1: 内容节点提及其他节点
final articleNode = Node(
  id: 'article1',
  type: NodeType.content,
  title: 'React 教程',
  content: 'React 是一个前端框架，详见 [[framework]] 文档。',
  references: {
    'framework': NodeReference(
      nodeId: 'framework',
      type: ReferenceType.mentions,
      role: '相关文档',
    ),
  },
);

// 示例2: 概念节点包含子节点
final frameworkNode = Node(
  id: 'framework',
  type: NodeType.concept,
  title: '前端框架',
  content: '主流的前端框架',
  references: {
    'react': NodeReference(
      nodeId: 'react',
      type: ReferenceType.contains,
      role: '实例',
    ),
    'vue': NodeReference(
      nodeId: 'vue',
      type: ReferenceType.contains,
      role: '实例',
    ),
  },
);

// 示例3: 因果关系链
final workNode = Node(
  id: 'work',
  type: NodeType.content,
  title: '过度工作',
  content: '长时间加班',
  references: {
    'stress': NodeReference(
      nodeId: 'stress',
      type: ReferenceType.causes,
      role: '导致',
    ),
  },
);

final stressNode = Node(
  id: 'stress',
  type: NodeType.content,
  title: '健康问题',
  content: '身心压力过大',
  references: {
    'efficiency': NodeReference(
      nodeId: 'efficiency',
      type: ReferenceType.causes,
      role: '进而导致',
    ),
  },
);

// 示例4: 二阶关系（关系的关系）
final causalChainNode = Node(
  id: 'causal_chain',
  type: NodeType.concept,
  title: '因果传递链',
  content: '工作导致压力，压力导致效率下降的因果传递',
  references: {
    'work_stress_relation': NodeReference(
      nodeId: 'work_stress_relation',
      type: ReferenceType.contains,
      role: '一阶关系',
    ),
    'stress_efficiency_relation': NodeReference(
      nodeId: 'stress_efficiency_relation',
      type: ReferenceType.contains,
      role: '一阶关系',
    ),
  },
);
```

### NodeType（节点类型）

```dart
enum NodeType {
  /// 内容节点：存储笔记内容
  content,

  /// 概念节点：代表关系或抽象概念
  concept,
}
```

**使用场景**：

- `content`: 普通笔记、文档、段落
- `concept`: 关系关系、分类、抽象概念、高阶关系

### NodeViewMode（显示模式）

```dart
enum NodeViewMode {
  /// 仅标题
  titleOnly,

  /// 标题+摘要（前几行）
  titleWithPreview,

  /// 完整 Markdown 内容
  fullContent,

  /// 紧凑模式（小图标）
  compact,

  /// 概念地图模式（特殊样式）
  conceptMap,
}
```

**渲染表现**：
| 模式 | 内容节点 | 概念节点 |
|------|----------|----------|
| `titleOnly` | 仅显示标题 | 仅显示概念名称 |
| `titleWithPreview` | 标题 + 2-3行预览 | 概念名称 + 描述 |
| `fullContent` | 完整 Markdown 渲染 | 概念名称 + 完整描述 |
| `compact` | 小图标 + 标题 | 圆形 + 概念名 |
| `conceptMap` | 普通样式 | 虚线框/圆形样式 |

## 复合模型

### Graph（图结构）

```dart
class Graph {
  /// 图ID
  final String id;

  /// 图名称
  final String name;

  /// 节点ID列表
  final List<String> nodeIds;

  /// 视图配置
  final GraphViewConfig viewConfig;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 获取所有节点（需要从 Repository 加载）
  Future<List<Node>> getNodes(NodeRepository repo);

  /// 从 references 计算连接列表
  List<Connection> getConnections(List<Node> nodes);

  /// 获取概念层次结构（基于 contains 引用）
  Map<String, List<String>> getConceptHierarchy(List<Node> nodes);
}
```

### Connection（连接，计算属性）

连接从 Node 的 `references` 动态计算得出：

```dart
class Connection {
  /// 连接ID（自动生成：fromId_toId）
  final String id;

  /// 起始节点ID
  final String fromNodeId;

  /// 目标节点ID
  final String toNodeId;

  /// 引用类型（决定边的语义）
  final ReferenceType referenceType;

  /// 角色标签
  final String? role;

  /// 颜色
  final Color? color;

  /// 线型
  final LineStyle lineStyle;

  /// 线宽
  final double thickness;
}

enum LineStyle {
  solid,      // 实线
  dashed,     // 虚线
  dotted,     // 点线
}
```

**从 references 计算连接**：

```dart
/// 从 Node 的 references 计算连接
List<Connection> calculateConnections(List<Node> nodes) {
  final connections = <Connection>[];
  final nodeMap = {for (var n in nodes) n.id: n};

  for (final node in nodes) {
    for (final ref in node.references.values) {
      if (nodeMap.containsKey(ref.nodeId)) {
        connections.add(Connection(
          id: '${node.id}_${ref.nodeId}',
          fromNodeId: node.id,
          toNodeId: ref.nodeId,
          referenceType: ref.type,
          role: ref.role,
          lineStyle: _getLineStyleForType(ref.type),
        ));
      }
    }
  }

  return connections;
}

LineStyle _getLineStyleForType(ReferenceType type) {
  switch (type) {
    case ReferenceType.contains:
      return LineStyle.dashed;  // 包含关系用虚线
    case ReferenceType.causes:
      return LineStyle.solid;   // 因果关系用实线
    default:
      return LineStyle.solid;
  }
}
```

**注意**：Connection 不是独立存储的实体，而是从 Node 的 `references` 计算得出的。

### GraphViewConfig（视图配置）

```dart
class GraphViewConfig {
  /// 视图模式
  final ViewModeType viewMode;

  /// 相机位置和缩放
  final Camera camera;

  /// 是否启用自动布局
  final bool autoLayoutEnabled;

  /// 布局算法
  final LayoutAlgorithm layoutAlgorithm;

  /// 是否显示概念节点
  final bool showConceptNodes;

  /// 是否显示连接线
  final bool showConnectionLines;

  /// 背景样式
  final BackgroundStyle backgroundStyle;
}

enum ViewModeType {
  normalGraph,    // 普通图示
  conceptMap,     // 概念地图
  mixed,          // 混合模式
}

enum LayoutAlgorithm {
  forceDirected,  // 力导向
  hierarchical,   // 层级
  circular,       // 环形
  conceptMap,     // 概念地图专用
  free,           // 自由布局
}

enum BackgroundStyle {
  grid,           // 网格
  dots,           // 点阵
  none,           // 无
}

class Camera {
  final double x;
  final double y;
  final double zoom;

  Camera({this.x = 0, this.y = 0, this.zoom = 1.0});
}
```

## 转换模型

### ConversionRule（转换规则）

```dart
class ConversionRule {
  /// 拆分策略
  final SplitStrategy splitStrategy;

  /// 合并策略
  final MergeStrategy mergeStrategy;

  /// 标题来源
  final TitleSource titleSource;

  /// 连接提取规则
  final List<ConnectionExtractionRule> connectionRules;

  /// 元数据提取规则
  final MetadataExtractionRule metadataRule;
}

enum SplitStrategy {
  heading,        // 按标题拆分
  separator,      // 按分割符拆分
  aiSmart,        // AI 智能拆分
  customRegex,    // 自定义正则
}

enum MergeStrategy {
  hierarchy,      // 层级合并
  sequence,       // 顺序合并
  custom,         // 自定义合并
}

enum TitleSource {
  firstHeading,   // 第一个标题
  filename,       // 文件名
  frontmatter,    // Frontmatter 字段
  custom,         // 自定义
}
```

### HeadingSplitRule（按标题拆分）

```dart
class HeadingSplitRule {
  /// 标题级别（1-6）
  final int level;

  /// 最小内容长度
  final int minContentLength;

  /// 保留原标题
  final bool keepOriginalHeading;

  /// 自动生成标题（如果没有标题）
  final bool autoGenerateTitle;
}
```

### SeparatorSplitRule（按分割符拆分）

```dart
class SeparatorSplitRule {
  /// 分割符模式
  final String pattern;

  /// 是否保留分割符
  final bool keepSeparator;

  /// 正则标志
  final String regexFlags;
}
```

### AISmartSplitRule（AI 智能拆分）

```dart
class AISmartSplitRule {
  /// 最小段落长度
  final int minSectionLength;

  /// 语义相似度阈值
  final double semanticSimilarityThreshold;

  /// AI 提供商
  final AIProvider provider;

  /// 最大段落数
  final int? maxSections;
}
```

## AI 模型

### AIGenerateRequest（AI 生成请求）

```dart
class AIGenerateRequest {
  /// 提示词
  final String prompt;

  /// 上下文节点
  final List<Node> contextNodes;

  /// 生成选项
  final AIGenerationOptions options;
}

class AIGenerationOptions {
  /// 最大长度
  final int? maxLength;

  /// 温度（0-1）
  final double temperature;

  /// 是否包含示例
  final bool includeExamples;

  /// 输出格式
  final OutputFormat format;
}

enum OutputFormat {
  markdown,
  json,
  plainText,
}
```

### ConnectionSuggestion（连接建议）

```dart
class ConnectionSuggestion {
  /// 起始节点ID
  final String fromNodeId;

  /// 目标节点ID
  final String toNodeId;

  /// 建议的引用类型
  final ReferenceType referenceType;

  /// 建议原因
  final String reason;

  /// 置信度（0-1）
  final double confidence;
}
```

### ConceptExtraction（概念提取结果）

```dart
class ConceptExtraction {
  /// 概念节点
  final Node conceptNode;

  /// 包含的节点ID
  final List<String> containedNodeIds;

  /// 概念类型
  final ConceptType conceptType;

  /// 提取原因
  final String reason;
}

enum ConceptType {
  causalChain,     // 因果链
  classification,  // 分类
  abstraction,     // 抽象概念
  relationship,    // 关系关系
  process,         // 过程
}
```

## 插件模型

### PluginManifest（插件清单）

```dart
class PluginManifest {
  /// 插件ID（唯一）
  final String id;

  /// 插件名称
  final String name;

  /// 版本号
  final String version;

  /// 描述
  final String description;

  /// 作者
  final String author;

  /// 插件类型
  final PluginType type;

  /// 主文件路径
  final String mainFile;

  /// 权限列表
  final List<PluginPermission> permissions;

  /// 插件设置
  final Map<String, dynamic> settings;

  /// 命令列表
  final List<PluginCommand> commands;

  /// 依赖的其他插件
  final List<String> dependencies;
}

enum PluginType {
  data,          // 数据处理
  ui,            // UI 扩展
  ai,            // AI 功能
  integration,   // 外部集成
}

enum PluginPermission {
  readNodes,     // 读取节点
  writeNodes,    // 写入节点
  readGraphs,    // 读取图
  writeGraphs,   // 写入图
  readFile,      // 读取文件
  writeFile,     // 写入文件
  aiAccess,      // 访问 AI
  uiRibbon,      // 添加 UI 按钮
  statusBar,     // 状态栏
  commands,      // 注册命令
}

class PluginCommand {
  final String id;
  final String name;
  final String? hotkey;
  final String? icon;
}
```

### PluginSettings（插件设置）

```dart
class PluginSettings {
  /// 插件ID
  final String pluginId;

  /// 是否启用
  final bool enabled;

  /// 用户自定义设置
  final Map<String, dynamic> userSettings;

  /// API 密钥（如需要）
  final Map<String, String> apiKeys;
}
```

## 存储模型

### NodeFile（节点文件结构）

每个节点存储为一个 Markdown 文件：

```
data/nodes/{node_id}.md
---
title: 节点标题
type: content
created_at: 2026-03-01T10:00:00Z
updated_at: 2026-03-01T11:30:00Z
tags: [tag1, tag2]
color: "#FF5722"
references:
  node_id_2:
    type: mentions
    role: "相关文档"
  node_id_3:
    type: dependsOn
---

# 节点标题

节点内容使用 Markdown 格式...

可以包含：
- 标题
- 列表
- 代码块
- 图片
- 链接

使用 [[node_id]] 创建到其他节点的链接，会自动转换为 references。
```

### GraphFile（图文件结构）

```json
{
  "id": "graph_id",
  "name": "我的知识图谱",
  "node_ids": ["id1", "id2", "id3"],
  "view_config": {
    "view_mode": "normalGraph",
    "camera": {"x": 0, "y": 0, "zoom": 1.0},
    "auto_layout_enabled": false,
    "layout_algorithm": "forceDirected",
    "show_concept_nodes": true,
    "show_connection_lines": true
  },
  "created_at": "2026-03-01T10:00:00Z",
  "updated_at": "2026-03-01T11:30:00Z"
}
```

### MetadataIndex（元数据索引）

```json
{
  "nodes": [
    {
      "id": "node_id",
      "type": "content",
      "title": "标题",
      "position": {"x": 100, "y": 200},
      "size": {"width": 300, "height": 400},
      "file_path": "nodes/node_id.md",
      "referenced_node_ids": ["id2", "id3"]
    }
  ],
  "last_updated": "2026-03-01T11:30:00Z"
}
```

## 数据关系图

```
┌─────────────────────────────────────────────────────────┐
│                       Graph                             │
│  - id                                                   │
│  - name                                                 │
│  - nodeIds: List<String>                                │
│  - viewConfig                                           │
└───────────────┬─────────────────────────────────────────┘
                │ contains
                ↓
┌─────────────────────────────────────────────────────────┐
│                       Node                              │
│  - id                                                   │
│  - type: content | concept                              │
│  - title                                                │
│  - content (Markdown)                                   │
│  - position                                             │
│  - references: Map<String, NodeReference> ──┐           │
└────────────────────────────────────────────┼───────────┘
                                               │
                                               │ references
                                               ↓
                                 ┌───────────────────────┐
                                 │  NodeReference        │
                                 │  - nodeId             │
                                 │  - type (enum)        │
                                 │  - role               │
                                 │  - metadata           │
                                 └───────────────────────┘
```

## 序列化

### json_serializable 使用

使用 `json_serializable` 包自动生成序列化代码：

```dart
// node.dart
import 'package:json_annotation/json_annotation.dart';

part 'node.g.dart';

@JsonSerializable()
class Node {
  final String id;
  final NodeType type;
  final String title;
  final String? content;

  @JsonKey(name: 'ref_ids')  // 自定义 JSON 字段名
  final List<String> referencedNodeIds;

  Node({
    required this.id,
    required this.type,
    required this.title,
    this.content,
    required this.referencedNodeIds,
  });

  factory Node.fromJson(Map<String, dynamic> json) =>
      _$NodeFromJson(json);

  Map<String, dynamic> toJson() => _$NodeToJson(this);
}

// 生成代码
// flutter pub run build_runner build
```

**复杂类型序列化**：

```dart
@JsonSerializable()
class Node {
  final Offset position;

  // 自定义序列化
  @JsonKey(fromJson: _offsetFromJson, toJson: _offsetToJson)
  final Offset position;

  static Offset _offsetFromJson(Map<String, dynamic> json) =>
      Offset(json['x'] as double, json['y'] as double);

  static Map<String, dynamic> _offsetToJson(Offset offset) =>
      {'x': offset.dx, 'y': offset.dy};
}
```

**枚举序列化**：

```dart
@JsonEnum()
enum NodeType {
  @JsonValue('content')
  content,

  @JsonValue('concept')
  concept,
}
```

### 文件序列化

```dart
class NodeSerializer {
  static Future<void> saveToFile(Node node, String path) async {
    final file = File(path);
    final json = jsonEncode(node.toJson());
    await file.writeAsString(json);
  }

  static Future<Node> loadFromFile(String path) async {
    final file = File(path);
    final json = await file.readAsString();
    return Node.fromJson(jsonDecode(json));
  }

  static Future<void> saveAll(List<Node> nodes, String directory) async {
    await Future.wait(
      nodes.map((node) => saveToFile(node, '$directory/${node.id}.json')),
    );
  }
}
```

## 本地存储方案

### 存储层次

```
┌─────────────────────────────────────┐
│  应用设置（SharedPreferences）      │  - 用户偏好
│  - 主题                            │  - API 密钥
│  - API 配置                         │  - 小型配置
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  元数据索引（SQLite/Isar）          │  - 节点索引
│  - 节点 ID 列表                     │  - 快速搜索
│  - 标签索引                         │  - 关系映射
└─────────────────────────────────────┘
              ↓
┌─────────────────────────────────────┐
│  完整数据（文件系统）               │  - 节点 Markdown
│  - 节点文件（.md）                  │  - 图结构（.json）
│  - 图配置（.json）                  │  - 媒体资源
└─────────────────────────────────────┘
```

### SharedPreferences - 应用设置

```dart
class SettingsService {
  static const String _themeKey = 'theme';
  static const String _apiKeyKey = 'api_key';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  // 主题设置
  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.toString());
  }

  ThemeMode getThemeMode() {
    final mode = _prefs.getString(_themeKey);
    return mode == 'ThemeMode.dark' ? ThemeMode.dark : ThemeMode.light;
  }

  // API 密钥（加密存储）
  Future<void> setApiKey(String provider, String key) async {
    final encrypted = _encrypt(key);
    await _prefs.setString('api_key_$provider', encrypted);
  }

  Future<String?> getApiKey(String provider) async {
    final encrypted = _prefs.getString('api_key_$provider');
    if (encrypted == null) return null;
    return _decrypt(encrypted);
  }

  String _encrypt(String data) {
    // 使用 flutter_secure_storage
    return data;
  }

  String _decrypt(String data) {
    return data;
  }
}
```

### Isar - 高性能索引

```dart
// 定义 Isar 模型
@Collection()
class NodeIndex {
  Id id = Isar.autoIncrement;

  @Index()
  late String nodeId;

  @Index()
  late String title;

  @Index(type: IndexType.value)
  late List<String> tags;

  late DateTime createdAt;
  late DateTime updatedAt;
}

// 使用 Isar
class NodeIndexService {
  late Isar isar;

  Future<void> init() async {
    isar = await Isar.open([NodeIndexSchema]);
  }

  Future<void> indexNode(Node node) async {
    final index = NodeIndex()
      ..nodeId = node.id
      ..title = node.title
      ..tags = node.metadata['tags'] as List<String>? ?? []
      ..createdAt = node.createdAt
      ..updatedAt = node.updatedAt;

    await isar.writeTxn(() async {
      await isar.nodeIndexes.put(index);
    });
  }

  Future<List<NodeIndex>> searchNodes(String query) async {
    return await isar.nodeIndexes
        .filter()
        .titleContains(query, caseSensitive: false)
        .findAll();
  }

  Future<List<NodeIndex>> getNodesByTag(String tag) async {
    return await isar.nodeIndexes
        .filter()
        .tagsElementContains(tag)
        .findAll();
  }
}
```

### 文件系统存储

```dart
class NodeFileSystem {
  static const String nodesDir = 'data/nodes';
  static const String graphsDir = 'data/graphs';
  static const String backupsDir = 'data/backups';

  Future<void> initDirectories() async {
    final dirs = [nodesDir, graphsDir, backupsDir];
    for (final dir in dirs) {
      await Directory(dir).create(recursive: true);
    }
  }

  // 保存节点为 Markdown
  Future<void> saveNode(Node node) async {
    final file = File('$nodesDir/${node.id}.md');

    // Frontmatter + Markdown
    final content = _generateNodeMarkdown(node);
    await file.writeAsString(content);
  }

  String _generateNodeMarkdown(Node node) {
    final frontmatter = {
      'id': node.id,
      'type': node.type.name,
      'title': node.title,
      'created_at': node.createdAt.toIso8601String(),
      'updated_at': node.updatedAt.toIso8601String(),
      'references': node.references.map((k, v) => {
        k: v.toJson(),
      }),
    };

    final yaml = Encoder().convert(frontmatter);
    return '---\n$yaml\n---\n\n${node.content ?? ""}';
  }

  // 加载节点
  Future<Node> loadNode(String nodeId) async {
    final file = File('$nodesDir/$nodeId.md');
    final content = await file.readAsString();

    return _parseNodeMarkdown(content);
  }

  Node _parseNodeMarkdown(String markdown) {
    // 解析 Frontmatter
    final frontmatterMatch = RegExp(r'^---\n(.*?)\n---', dotAll: bool.fromEnvironment('multiline')).firstMatch(markdown);

    if (frontmatterMatch != null) {
      final yaml = frontmatterMatch.group(1)!;
      final json = loadYaml(yaml) as Map<String, dynamic>;
      final body = markdown.substring(frontmatterMatch.end);

      return Node.fromJson(json).copyWith(content: body);
    }

    throw FormatException('Invalid node file format');
  }

  // 批量导出
  Future<void> exportGraph(String graphId, String outputPath) async {
    final graphFile = File('$graphsDir/$graphId.json');
    final graphJson = await graphFile.readAsString();
    final graph = Graph.fromJson(jsonDecode(graphJson));

    // 创建导出目录
    final exportDir = Directory('$outputPath/$graphId');
    await exportDir.create(recursive: true);

    // 复制节点文件
    for (final nodeId in graph.nodeIds) {
      await File('$nodesDir/$nodeId.md').copy('$outputPath/$graphId/$nodeId.md');
    }

    // 复制图文件
    await graphFile.copy('$outputPath/$graphId/graph.json');
  }
}
```

## 验证规则

### Node 验证

```dart
class NodeValidator {
  static ValidationResult validate(Node node) {
    final errors = <String>[];

    // ID 不能为空
    if (node.id.isEmpty) {
      errors.add('Node ID cannot be empty');
    }

    // 标题不能为空
    if (node.title.isEmpty) {
      errors.add('Node title cannot be empty');
    }

    // 内容节点必须有内容
    if (node.type == NodeType.content && node.content == null) {
      errors.add('Content node must have content');
    }

    // 概念节点应该包含至少一个引用
    if (node.type == NodeType.concept && node.references.isEmpty) {
      errors.add('Concept node should have at least one reference');
    }

    // 验证引用的节点存在
    for (final ref in node.references.values) {
      if (ref.nodeId.isEmpty) {
        errors.add('Reference node_id cannot be empty');
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
```

### Graph 验证

```dart
class GraphValidator {
  static ValidationResult validate(Graph graph, List<Node> allNodes) {
    final errors = <String>[];

    // 检查节点是否存在
    for (final nodeId in graph.nodeIds) {
      if (!allNodes.any((n) => n.id == nodeId)) {
        errors.add('Node $nodeId not found');
      }
    }

    // 检查循环引用
    final hasCycle = _detectCycle(graph, allNodes);
    if (hasCycle) {
      errors.add('Graph contains circular references');
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
```

## 数据备份和恢复

### 备份策略

```dart
class BackupService {
  final NodeFileSystem _fileSystem;
  final String _backupDir = 'data/backups';

  BackupService(this._fileSystem);

  /// 创建完整备份
  Future<Backup> createFullBackup() async {
    final timestamp = DateTime.now();
    final backupId = 'backup_${timestamp.millisecondsSinceEpoch}';
    final backupPath = '$_backupDir/$backupId';

    // 创建备份目录
    final backupDirectory = Directory(backupPath);
    await backupDirectory.create(recursive: true);

    // 1. 备份所有节点
    final nodesDir = Directory('data/nodes');
    if (await nodesDir.exists()) {
      await _copyDirectory(nodesDir, Directory('$backupPath/nodes'));
    }

    // 2. 备份所有图
    final graphsDir = Directory('data/graphs');
    if (await graphsDir.exists()) {
      await _copyDirectory(graphsDir, Directory('$backupPath/graphs'));
    }

    // 3. 备份设置
    final settingsFile = File('data/settings.json');
    if (await settingsFile.exists()) {
      await settingsFile.copy('$backupPath/settings.json');
    }

    // 4. 创建备份清单
    final manifest = BackupManifest(
      backupId: backupId,
      timestamp: timestamp,
      nodeCount: await _countFiles('$backupPath/nodes'),
      graphCount: await _countFiles('$backupPath/graphs'),
      size: await _getDirectorySize(backupPath),
    );

    await File('$backupPath/manifest.json')
        .writeAsString(jsonEncode(manifest.toJson()));

    return Backup(
      id: backupId,
      path: backupPath,
      manifest: manifest,
    );
  }

  /// 自动备份（每天）
  Future<void> autoBackup() async {
    final backups = await listBackups();

    // 只保留最近 7 天的备份
    final now = DateTime.now();
    for (final backup in backups) {
      final age = now.difference(backup.manifest.timestamp);
      if (age.inDays > 7) {
        await deleteBackup(backup.id);
      }
    }

    // 创建新备份
    await createFullBackup();
  }

  /// 恢复备份
  Future<void> restoreBackup(String backupId) async {
    final backupPath = '$_backupDir/$backupId';

    // 验证备份完整性
    final manifest = await _loadManifest(backupPath);
    if (!await _validateBackup(backupPath, manifest)) {
      throw BackupException('Backup is corrupted or incomplete');
    }

    // 1. 备份当前数据
    final currentBackup = await createFullBackup();

    // 2. 恢复节点
    await _copyDirectory(
      Directory('$backupPath/nodes'),
      Directory('data/nodes'),
    );

    // 3. 恢复图
    await _copyDirectory(
      Directory('$backupPath/graphs'),
      Directory('data/graphs'),
    );

    // 4. 恢复设置
    final settingsFile = File('$backupPath/settings.json');
    if (await settingsFile.exists()) {
      await settingsFile.copy('data/settings.json');
    }

    debugPrint('Restored from backup: $backupId');
    debugPrint('Current data backed up to: ${currentBackup.id}');
  }

  Future<List<Backup>> listBackups() async {
    final backupDir = Directory(_backupDir);
    if (!await backupDir.exists()) return [];

    final backups = <Backup>[];
    await for (final entity in backupDir.list()) {
      if (entity is Directory) {
        final manifest = await _loadManifest(entity.path);
        backups.add(Backup(
          id: manifest.backupId,
          path: entity.path,
          manifest: manifest,
        ));
      }
    }

    backups.sort((a, b) => b.manifest.timestamp.compareTo(a.manifest.timestamp));
    return backups;
  }

  Future<void> deleteBackup(String backupId) async {
    final backupDir = Directory('$_backupDir/$backupId');
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
  }

  Future<BackupManifest> _loadManifest(String backupPath) async {
    final manifestFile = File('$backupPath/manifest.json');
    final json = await manifestFile.readAsString();
    return BackupManifest.fromJson(jsonDecode(json));
  }

  Future<bool> _validateBackup(String backupPath, BackupManifest manifest) async {
    // 检查文件数量
    final nodeCount = await _countFiles('$backupPath/nodes');
    final graphCount = await _countFiles('$backupPath/graphs');

    return nodeCount == manifest.nodeCount && graphCount == manifest.graphCount;
  }

  Future<void> _copyDirectory(Directory source, Directory target) async {
    await target.create(recursive: true);
    await for (final entity in source.list(recursive: true)) {
      final relativePath = entity.path.substring(source.path.length);
      if (entity is File) {
        await entity.copy('${target.path}$relativePath');
      } else if (entity is Directory) {
        await Directory('${target.path}$relativePath').create(recursive: true);
      }
    }
  }

  Future<int> _countFiles(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) return 0;

    int count = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) count++;
    }
    return count;
  }

  Future<int> _getDirectorySize(String path) async {
    final dir = Directory(path);
    int size = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }
}

class Backup {
  final String id;
  final String path;
  final BackupManifest manifest;
  Backup({
    required this.id,
    required this.path,
    required this.manifest,
  });
}

class BackupManifest {
  final String backupId;
  final DateTime timestamp;
  final int nodeCount;
  final int graphCount;
  final int size; // bytes

  BackupManifest({
    required this.backupId,
    required this.timestamp,
    required this.nodeCount,
    required this.graphCount,
    required this.size,
  });

  Map<String, dynamic> toJson() => {
    'backup_id': backupId,
    'timestamp': timestamp.toIso8601String(),
    'node_count': nodeCount,
    'graph_count': graphCount,
    'size': size,
  };

  factory BackupManifest.fromJson(Map<String, dynamic> json) => BackupManifest(
    backupId: json['backup_id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    nodeCount: json['node_count'] as int,
    graphCount: json['graph_count'] as int,
    size: json['size'] as int,
  );
}
```

### 增量备份

```dart
class IncrementalBackupService {
  /// 仅备份变更的节点
  Future<IncrementalBackup> createIncrementalBackup() async {
    final lastBackup = await _loadLastBackupInfo();
    final changedNodes = await _getChangedNodesSince(lastBackup?.timestamp);

    final backupId = 'incremental_${DateTime.now().millisecondsSinceEpoch}';
    final backupPath = 'data/backups/$backupId';

    // 只备份变更的节点
    for (final nodeId in changedNodes) {
      await File('data/nodes/$nodeId.md')
          .copy('$backupPath/nodes/$nodeId.md');
    }

    // 记录变更
    final manifest = IncrementalManifest(
      backupId: backupId,
      timestamp: DateTime.now(),
      changedNodeIds: changedNodes,
      baseBackupId: lastBackup?.backupId,
    );

    return IncrementalBackup(manifest: manifest);
  }
}
```

## 迁移和版本管理

### 数据版本

```json
{
  "version": "1.0.0",
  "schema_version": 2,
  "migrated_at": "2026-03-01T10:00:00Z"
}
```

### 迁移策略

```dart
class DataMigration {
  static Future<void> migrate(String fromVersion, String toVersion) async {
    switch (toVersion) {
      case '2.0.0':
        await _migrateToV2();
        break;
      // 更多版本迁移...
    }
  }

  static Future<void> _migrateToV2() async {
    // 从旧的 connections 字段迁移到 references
    // 将 containedNodeIds 转换为 contains 类型的引用
    // 更新索引
  }
}
```

## 性能考虑

### 1. 懒加载

```dart
class LazyNode {
  final String id;
  final String title;
  final List<String> referencedNodeIds;  // 只存储ID
  Node? _fullNode;

  Future<Node> get fullNode async {
    _fullNode ??= await NodeRepository().load(id);
    return _fullNode!;
  }
}
```

### 2. 增量更新

```dart
class NodeUpdate {
  final String nodeId;
  final Map<String, dynamic> changes;
  final DateTime timestamp;
}
```

### 3. 索引优化

```dart
class NodeIndex {
  final Map<String, Node> _byId = {};
  final Map<String, List<Node>> _byTitle = {};
  final Map<String, List<Node>> _byTag = {};

  /// 反向索引：被引用关系
  final Map<String, List<Node>> _referencedBy = {};
}
```

## 总结

这套数据模型的核心优势：

1. **统一性**：所有元素都是 Node，简化操作
2. **数学优雅**：通过 content + references 自然形成有向图
3. **灵活性**：references 支持任意关系类型，无需修改 schema
4. **可扩展**：易于添加新的引用类型
5. **高性能**：支持懒加载和增量更新
6. **类型安全**：使用强类型和验证
