# 编码规范

## 项目编码规范

本文档定义 Node Graph Notebook 项目的编码标准和最佳实践。

## 目录

- [Dart 语言规范](#dart-语言规范)
- [Flutter 规范](#flutter-规范)
- [Flame 引擎规范](#flame-引擎规范)
- [命名规范](#命名规范)
- [代码组织](#代码组织)
- [注释和文档](#注释和文档)
- [错误处理](#错误处理)
- [测试规范](#测试规范)
- [性能优化](#性能优化)

## Dart 语言规范

### 基础规范

遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 和 [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)。

#### 1. 类型注解

**公共 API 必须有类型注解**：

```dart
// ✅ 好的做法
class NodeService {
  Future<Node> createNode({
    required String title,
    String? content,
  }) async {
    // ...
  }
}

// ❌ 避免
class NodeService {
  createNode({required title, content}) async {
    // ...
  }
}
```

**私有方法可以省略类型**：

```dart
// ✅ 可接受
void _processData(data) {
  // ...
}

// ✅ 更好（有类型）
void _processData(List<Node> data) {
  // ...
}
```

#### 2. 可空性

**明确可空性**：

```dart
// ✅ 明确可空
String? title;
Node? parentNode;

// ❌ 避免（延迟初始化应该用 late）
late String title;
```

**使用 null-aware 操作符**：

```dart
// ✅ 好的做法
final title = node?.title ?? 'Untitled';
final content = node?.content ?? '';

// ❌ 冗长
final title = node != null ? node.title : 'Untitled';
```

#### 3. async/await

**优先使用 async/await 而非 .then()**：

```dart
// ✅ 好的做法
Future<Node> createNode(String title) async {
  final node = await _validate(title);
  return await _save(node);
}

// ❌ 避免
Future<Node> createNode(String title) {
  return _validate(title).then((node) => _save(node));
}
```

**避免不必要的 async**：

```dart
// ❌ 不必要的 async
Future<String> getTitle() async {
  return 'My Title';
}

// ✅ 简化
Future<String> getTitle() {
  return Future.value('My Title');
}

// ✅ 或直接返回
String getTitle() => 'My Title';
```

#### 4. 错误处理

**使用 typed exceptions**：

```dart
// ✅ 定义具体异常类型
class NodeNotFoundError implements Exception {
  final String nodeId;
  NodeNotFoundError(this.nodeId);

  @override
  String toString() => 'Node not found: $nodeId';
}

// 使用
try {
  final node = await service.getNode(id);
} on NodeNotFoundError catch (e) {
  debugPrint(e);
}
```

**避免捕获通用 Exception**：

```dart
// ❌ 避免
try {
  // ...
} catch (e) {
  debugPrint(e);
}

// ✅ 更好
try {
  // ...
} on NodeNotFoundError catch (e) {
  // 处理特定错误
} on ValidationError catch (e) {
  // 处理验证错误
}
```

## Flutter 规范

### Widget 规范

#### 1. Widget 构建

**拆分为小组件**：

```dart
// ❌ 避免（巨大的 build 方法）
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 100+ 行的 UI 代码...
        ],
      ),
    );
  }
}

// ✅ 好的做法（拆分）
class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildContent(),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() => HeaderWidget();
  Widget _buildContent() => ContentWidget();
  Widget _buildFooter() => FooterWidget();
}
```

#### 2. const 构造函数

**尽可能使用 const**：

```dart
// ✅ 好的做法
const Padding(
  padding: EdgeInsets.all(16),
  child: Text('Hello'),
)

// ❌ 避免
Padding(
  padding: EdgeInsets.all(16),
  child: Text('Hello'),
)
```

**const 优先级**：

1. 所有 icon、text、padding 等基础组件
2. 不需要重建的子组件
3. 样式相关的组件（Theme、TextStyle）

#### 3. 命名参数

**Widget 构造函数使用命名参数**：

```dart
// ✅ 好的做法
class NodeCard extends StatelessWidget {
  const NodeCard({
    super.key,
    required this.node,
    this.onTap,
    this.selected = false,
  });

  final Node node;
  final VoidCallback? onTap;
  final bool selected;
}
```

#### 4. Widget 生命周期优化

**避免在 build 中执行耗时操作**：

```dart
// ❌ 避免
class NodeList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final expensiveValue = _calculateExpensiveValue();  // 每次重建都计算
    return Text('$expensiveValue');
  }

  int _calculateExpensiveValue() {
    // 复杂计算...
  }
}

// ✅ 好的做法 - 使用 StatefulWidget 缓存
class NodeList extends StatefulWidget {
  @override
  _NodeListState createState() => _NodeListState();
}

class _NodeListState extends State<NodeList> {
  late int _cachedValue;

  @override
  void initState() {
    super.initState();
    _cachedValue = _calculateExpensiveValue();
  }

  @override
  Widget build(BuildContext context) {
    return Text('$_cachedValue');
  }
}
```

#### 5. 条件渲染

**使用条件运算符而非空 Widget**：

```dart
// ❌ 避免
Widget build(BuildContext context) {
  if (condition) {
    return MyWidget();
  } else {
    return SizedBox();  // 不必要的空 Widget
  }
}

// ✅ 好的做法
Widget build(BuildContext context) {
  return condition ? MyWidget() : SizedBox.shrink();
}

// ✅ 更好的做法 - 提取方法
Widget _buildContent() {
  if (!condition) return const SizedBox.shrink();
  return MyWidget();
}
```

#### 6. ListView 优化

**大列表使用 builder**：

```dart
// ✅ 好的做法 - 懒加载
ListView.builder(
  itemCount: nodes.length,
  itemBuilder: (ctx, i) => NodeCard(nodes[i]),
)

// ❌ 避免 - 一次性创建所有 Widget
ListView(
  children: nodes.map((n) => NodeCard(n)).toList(),
)
```

**保持 itemExtent**：

```dart
ListView.builder(
  itemCount: items.length,
  itemExtent: 60.0,  // 提升滚动性能
  itemBuilder: (ctx, i) => ItemWidget(items[i]),
)
```

#### 2. const 构造函数

**尽可能使用 const**：

```dart
// ✅ 好的做法
const Padding(
  padding: EdgeInsets.all(16),
  child: Text('Hello'),
)

// ❌ 避免
Padding(
  padding: EdgeInsets.all(16),
  child: Text('Hello'),
)
```

#### 3. 命名参数

**Widget 构造函数使用命名参数**：

```dart
// ✅ 好的做法
class NodeCard extends StatelessWidget {
  const NodeCard({
    super.key,
    required this.node,
    this.onTap,
    this.selected = false,
  });

  final Node node;
  final VoidCallback? onTap;
  final bool selected;
}
```

### 状态管理

#### Provider 使用规范

**Model 层组织**：

```dart
// ✅ 好的做法 - 分离 Model 和 Service
class NodeModel extends ChangeNotifier {
  final NodeService _service;

  List<Node> _nodes = [];
  bool _isLoading = false;
  String? _error;

  List<Node> get nodes => _nodes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  NodeModel(this._service);

  Future<void> loadNodes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _nodes = await _service.getAllNodes();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// ❌ 避免 - Model 包含业务逻辑
class NodeModel extends ChangeNotifier {
  Future<void> loadNodes() async {
    // 不应该直接访问 repository
    _nodes = await NodeRepository().getAll();
    notifyListeners();
  }
}
```

**Provider 读取规则**：

```dart
// ✅ watch - 需要重建时使用
class NodeList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final model = context.watch<NodeModel>();
    return ListView.builder(
      itemCount: model.nodes.length,
      itemBuilder: (ctx, i) => NodeCard(model.nodes[i]),
    );
  }
}

// ✅ read - 不需要重建时使用（如回调）
ElevatedButton(
  onPressed: () {
    context.read<NodeModel>().loadNodes();
  },
  child: Text('Load'),
)

// ✅ select - 监听特定属性
class NodeCount extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.select<NodeModel, int>((m) => m.nodes.length);
    return Text('Total: $count');
  }
}
```

#### Provider 组织原则

**1. 依赖注入顺序**：

```dart
MultiProvider(
  providers: [
    // 1. 基础设施层（Repository）
    Provider<NodeRepository>(
      create: (_) => NodeRepository(),
    ),

    // 2. 服务层（Service）
    Provider<NodeService>(
      create: (ctx) => NodeService(
        repository: ctx.read<NodeRepository>(),
      ),
    ),

    // 3. 状态层（Model）
    ChangeNotifierProvider<NodeModel>(
      create: (ctx) => NodeModel(
        service: ctx.read<NodeService>(),
      ),
    ),
  ],
)
```

**2. Provider 作用域**：

```dart
// 全局状态 - 应用级别
MultiProvider(
  providers: [
    ChangeNotifierProvider<AppSettings>(
      create: (_) => AppSettings(),
    ),
  ],
  child: MaterialApp(...),
)

// 局部状态 - 页面级别
class GraphPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GraphModel(
        graphId: 'graph123',
        service: context.read<GraphService>(),
      ),
      child: GraphView(),
    );
  }
}
```

## Flame 引擎规范

### 组件规范

#### 1. 继承和混入

```dart
// ✅ 标准的 Flame 组件
class NodeComponent extends PositionComponent with Draggable, TapCallbacks {
  NodeComponent({
    required this.node,
    Vector2? position,
  }) : super(position: position);

  final Node node;

  @override
  void render(Canvas canvas) {
    // 渲染逻辑
  }

  @override
  void update(double dt) {
    // 更新逻辑
  }

  @override
  bool onDragStart(DragStartEvent event) {
    // 拖拽开始
    return true;
  }
}
```

#### 2. 生命周期

**正确初始化和释放**：

```dart
class NodeComponent extends PositionComponent {
  NodeComponent({required this.node}) : super();

  final Node node;
  late Sprite _sprite;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _sprite = await Sprite.load('node.png');
    size = _sprite.image.size;
  }

  @override
  void onRemove() {
    _sprite.image.dispose();
    super.onRemove();
  }
}
```

#### 3. 性能优化

**避免在 render 中分配内存**：

```dart
// ❌ 避免（每次渲染都创建对象）
@override
void render(Canvas canvas) {
  final paint = Paint()..color = Colors.red;
  canvas.drawRect(rect, paint);
}

// ✅ 好的做法（缓存 Paint 对象）
class NodeComponent extends PositionComponent {
  late final Paint _paint;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _paint = Paint()..color = Colors.red;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(rect, _paint);
  }
}
```

## 命名规范

### 文件命名

**使用 snake_case**：

```
✅ 好的做法:
node_service.dart
markdown_parser.dart
ai_client.dart

❌ 避免:
nodeService.dart
Markdown-Parser.dart
AI-client.dart
```

### 类命名

**使用 PascalCase**：

```dart
// ✅ 好的做法
class NodeService {}
class MarkdownParser {}
class AIClient {}

// ❌ 避免
class nodeService {}
class markdown_parser {}
class AI_CLIENT {}
```

### 变量和函数命名

**使用 camelCase**：

```dart
// ✅ 好的做法
String nodeTitle;
List<Node> allNodes;
Future<void> createNode() {}

// ❌ 避免
String node_title;
List<Node> All_Nodes;
Future<void> Create_Node() {}
```

### 私有成员

**使用下划线前缀**：

```dart
class NodeService {
  // 公共
  Node getNode(String id) {}

  // 私有
  Node _cachedNode;
  void _validateNode(Node node) {}
}
```

### 常量命名

**使用 lowerCamelCase 或 UPPER_CASE**：

```dart
// ✅ lowerCamelCase（推荐）
const defaultNodeSize = 300.0;
const maxConnectionCount = 100;

// ✅ UPPER_CASE（也接受）
const DEFAULT_NODE_SIZE = 300.0;
const MAX_CONNECTION_COUNT = 100;
```

### 布尔值命名

**使用谓词形式**：

```dart
// ✅ 好的做法
bool isValid;
bool hasContent;
bool canConnect;
bool shouldUpdate;

// ❌ 避免
bool valid;
bool content;
bool connect;
bool update;
```

## 代码组织

### 文件结构

**单一职责**：

```dart
// ✅ 好的做法 - 每个文件一个类
// node_service.dart
class NodeService {
  // ...
}

// ❌ 避免 - 多个类混在一起
// services.dart
class NodeService { /* ... */ }
class GraphService { /* ... */ }
class AIService { /* ... */ }
```

### 导入顺序

```dart
// 1. Dart SDK
import 'dart:async';
import 'dart:convert';

// 2. Flutter 框架
import 'package:flutter/material.dart';

// 3. 第三方包
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// 4. 项目内部
import 'package:node_graph_notebook/core/models/node.dart';
import 'package:node_graph_notebook/core/services/node_service.dart';

// 5. 相对导入（尽量减少）
import '../utils/helpers.dart';
```

### 类成员顺序

```dart
class NodeService {
  // 1. 静态常量
  static const double defaultSize = 300.0;

  // 2. 公共属性
  final NodeRepository repository;

  // 3. 私有属性
  List<Node> _cache = [];

  // 4. 构造函数
  NodeService({required this.repository});

  // 5. 公共方法（按重要性排序）
  Future<Node> createNode({...}) {}
  Future<void> deleteNode(String id) {}

  // 6. 私有方法
  Future<Node> _validate(Node node) {}

  // 7. 重写方法
  @override
  void dispose() {}
}
```

## 注释和文档

### 文档注释

**使用 /// 文档注释**：

```dart
/// 节点服务
///
/// 提供节点的 CRUD 操作和关系管理功能。
///
/// 示例：
/// ```dart
/// final service = NodeService();
/// final node = await service.createNode(
///   title: 'My Note',
///   content: 'Content here',
/// );
/// ```
class NodeService {
  /// 创建新节点
  ///
  /// [title] 节点标题（必需）
  /// [content] 节点内容（可选）
  /// 返回创建的 [Node] 对象
  Future<Node> createNode({
    required String title,
    String? content,
  }) async {
    // ...
  }
}
```

### 代码注释

**解释"为什么"而非"是什么"**：

```dart
// ✅ 好的做法（解释原因）
// 使用双缓冲避免闪烁
final _buffer = List<Node>.filled(100, null);

// ❌ 避免（显而易见）
// 创建包含 100 个 null 的列表
final _buffer = List<Node>.filled(100, null);
```

### TODO 注释

**使用标准 TODO 格式**：

```dart
// TODO(username): 实现自动保存功能
// TODO(username): [性能] 优化大数据集渲染
// FIXME: 修复节点删除时的内存泄漏
// HACK: 临时解决方案，等待 Flutter 3.0 修复
```

## 错误处理

### 断言

**使用 assert 进行开发时检查**：

```dart
Node createNode({
  required String title,
  String? content,
}) {
  assert(title.isNotEmpty, 'Title cannot be empty');
  // ...
}
```

### 参数验证

```dart
Future<Node> createNode({
  required String title,
  String? content,
}) async {
  if (title.isEmpty) {
    throw ValidationError('Title cannot be empty');
  }

  // ...
}
```

### Result 类型（可选）

```dart
class Result<T> {
  final T? data;
  final String? error;

  bool get isSuccess => error == null;
  bool get isFailure => error != null;

  Result.success(this.data) : error = null;
  Result.failure(this.error) : data = null;
}

// 使用
final result = await createNode(title: 'Test');
if (result.isSuccess) {
  debugPrint(result.data);
} else {
  debugPrint(result.error);
}
```

## 测试规范

### 单元测试

```dart
// test/unit/node_service_test.dart

void main() {
  group('NodeService', () {
    late NodeService service;
    late MockRepository mockRepo;

    setUp(() {
      mockRepo = MockRepository();
      service = NodeService(repository: mockRepo);
    });

    test('createNode should return valid node', () async {
      // Arrange
      final title = 'Test Node';

      // Act
      final node = await service.createNode(title: title);

      // Assert
      expect(node.title, title);
      expect(node.id, isNotEmpty);
    });

    test('createNode should throw on empty title', () {
      expect(
        () => service.createNode(title: ''),
        throwsA(isA<ValidationError>()),
      );
    });
  });
}
```

### Widget 测试

```dart
// test/widget/node_card_test.dart

void main() {
  testWidgets('NodeCard should display title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NodeCard(
          node: Node(title: 'Test', content: 'Content'),
        ),
      ),
    );

    expect(find.text('Test'), findsOneWidget);
  });
}
```

### 测试命名

**使用 should_ 格式**：

```dart
// ✅ 好的做法
test('should return node when found', () {});
test('should throw when node not found', () {});

// ❌ 避免
test('testNodeLookup', () {});
test('node lookup functionality', () {});
```

## 性能优化

### 避免阻塞主线程

```dart
// ❌ 阻塞 UI
void loadNodes() {
  final nodes = file.readAsStringSync(); // 阻塞
  setState(() => _nodes = nodes);
}

// ✅ 异步加载
Future<void> loadNodes() async {
  final nodes = await file.readAsString();
  setState(() => _nodes = nodes);
}
```

### 列表优化

```dart
// ✅ 使用 ListView.builder
ListView.builder(
  itemCount: nodes.length,
  itemBuilder: (ctx, i) => NodeCard(nodes[i]),
)

// ❌ 避免大量数据时使用 ListView()
ListView(
  children: nodes.map((n) => NodeCard(n)).toList(),
)
```

### 缓存和记忆

```dart
// ✅ 使用 cached network image
CachedNetworkImage(imageUrl: node.imageUrl)

// ✅ 记忆计算结果
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    other is Node &&
    runtimeType == other.runtimeType &&
    id == other.id; // ID 相同即为同一节点

@override
int get hashCode => id.hashCode;
```

## 工具和配置

### dart analyze

配置 `analysis_options.yaml`：

```yaml
include: package:lints/recommended.yaml

analyzer:
  strong-mode:
    implicit-casts: false
    implicit-dynamic: false

  errors:
    missing_required_param: error
    missing_return: error
    todo: ignore

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - avoid_print
    - avoid_unnecessary_containers
    - prefer_single_quotes
    - sort_constructors_first
    - prefer_final_fields
    - prefer_final_locals
```

## 代码分析最佳实践

### 常见问题及解决方案

本节总结代码分析过程中遇到的常见问题及其解决方案，帮助避免引入非规范代码。

#### 1. sort_constructors_first

**问题**：构造函数应该在类成员之前声明。

**错误示例**：
```dart
// ❌ 错误：构造函数在字段之后
class NodeService {
  final NodeRepository repository;
  List<Node> _cache = [];

  NodeService({required this.repository});
}
```

**正确示例**：
```dart
// ✅ 正确：构造函数在所有成员之前
class NodeService {
  NodeService({required this.repository});

  final NodeRepository repository;
  List<Node> _cache = [];
}
```

**规则**：
- 构造函数必须位于类声明的最前面
- factory 构造函数也应紧跟在 const 构造函数之后
- 所有字段和方法必须位于构造函数之后

#### 2. unnecessary_await_in_return

**问题**：return 语句中不必要地使用 await。

**错误示例**：
```dart
// ❌ 错误：不必要的 await
Future<String> getTitle() async {
  return await _fetchTitle();
}
```

**正确示例**：
```dart
// ✅ 正确：直接返回 Future
Future<String> getTitle() async {
  return _fetchTitle();
}
```

**规则**：
- 在 return 语句中直接返回 Future，无需 await
- await 只在需要使用返回值时使用

#### 3. avoid_slow_async_io

**问题**：使用异步方法检查文件存在性。

**错误示例**：
```dart
// ❌ 错误：使用异步 exists()
if (file.existsSync()) {
  // ...
}
```

**正确示例**：
```dart
// ✅ 正确：使用同步 existsSync()
if (file.existsSync()) {
  // ...
}
```

**规则**：
- 优先使用 `existsSync()` 替代 `await exists()`
- 只在确实需要异步时才使用 async 版本

#### 4. deprecated_member_use

**问题**：使用已弃用的 API。

**常见已弃用 API**：

1. **withOpacity 替换为 withValues**：
```dart
// ❌ 已弃用
color.withOpacity(0.5)

// ✅ 正确
color.withValues(alpha: 0.5)
```

2. **HasGameRef 替换为 HasGameReference**：
```dart
// ❌ 已弃用
class MyComponent extends PositionComponent with HasGameRef<MyGame> {}

// ✅ 正确
class MyComponent extends PositionComponent with HasGameReference<MyGame> {}
```

3. **DropdownButtonFormField 的 value 参数**：
```dart
// ⚠️  value 在某些情况下会警告，使用 initialValue
DropdownButtonFormField<String>(
  initialValue: _selectedValue, // 推荐
  // value: _selectedValue, // 可能产生警告
)
```

**规则**：
- 使用 IDE 的自动提示和警告
- 定期查看 Flutter/Dart 更新日志
- 优先使用新 API，避免使用已弃用的 API

#### 5. avoid_dynamic_calls

**问题**：对动态类型调用方法。

**错误示例**：
```dart
// ❌ 错误：dynamic 类型调用
dynamic data = jsonDecode(response);
final name = data['name']; // 类型为 dynamic

// ❌ 对 dynamic 调用方法
data.toString(); // 警告
```

**正确示例**：
```dart
// ✅ 正确：明确类型
Map<String, dynamic> data = jsonDecode(response);
final name = data['name'] as String; // 明确转换

// ✅ 使用明确类型
final text = name.toString(); // 类型明确
```

**规则**：
- 避免 `dynamic` 类型，使用具体类型
- JSON 解析时使用 `Map<String, dynamic>`
- 必要时使用 `as` 进行类型转换

#### 6. prefer_const_constructors

**问题**：可以使用 const 但未使用。

**错误示例**：
```dart
// ❌ 错误：缺少 const
final padding = EdgeInsets.all(16);
final text = Text('Hello');
final sizedBox = SizedBox(height: 10);
```

**正确示例**：
```dart
// ✅ 正确：使用 const
final padding = const EdgeInsets.all(16);
const Text('Hello');
const SizedBox(height: 10);
```

**规则**：
- 所有不可变对象都应使用 const
- 包括：EdgeInsets、SizedBox、Text、Icon 等
- Widget 树中的常量子树应使用 const

#### 7. avoid_print

**问题**：在生产代码中使用 print。

**错误示例**：
```dart
// ❌ 错误：使用 print
debugPrint('Debug info');
debugPrint('Error: $e');
```

**正确示例**：
```dart
// ✅ 正确：使用日志框架
import 'package:flutter/foundation.dart';

debugPrint('Debug info'); // 仅调试模式
kDebugMode ? debugPrint('Info') : null; // 条件输出

// 对于生产环境，使用统一的日志服务
Logger.info('Debug info');
Logger.error('Error', e);
```

**规则**：
- 使用 `debugPrint` 替代 `print`
- 生产代码移除所有 print 语句
- 使用统一的日志框架

#### 8. unnecessary_import

**问题**：导入未使用的包。

**错误示例**：
```dart
// ❌ 错误：不必要的导入
import 'dart:ui'; // 未使用
import 'package:flutter/foundation.dart'; // 已通过 material.dart 导入

import 'package:flutter/material.dart';
```

**正确示例**：
```dart
// ✅ 正确：只导入需要的
import 'package:flutter/material.dart'; // 已包含 dart:ui 和 foundation
```

**规则**：
- Flutter 的 material.dart 已包含常用包
- 使用 IDE 的"优化导入"功能
- 定期清理未使用的导入

#### 9. prefer_final_locals

**问题**：局部变量可以是 final 但未声明。

**错误示例**：
```dart
// ❌ 错误：变量未声明为 final
String name = node.title;
int count = nodes.length;
bool isValid = validate(node);
```

**正确示例**：
```dart
// ✅ 正确：使用 final
final String name = node.title;
final int count = nodes.length;
final bool isValid = validate(node);
```

**规则**：
- 所有不重新赋值的局部变量都应是 final
- 提高代码可读性和安全性

#### 10. use_decorated_box

**问题**：Container 仅用于装饰。

**错误示例**：
```dart
// ❌ 错误：Container 仅使用 decoration
Container(
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text('Hello'),
)
```

**正确示例**：
```dart
// ✅ 正确：使用 DecoratedBox
DecoratedBox(
  decoration: BoxDecoration(
    color: Colors.blue,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text('Hello'),
)
```

**规则**：
- Container 仅用于装饰时使用 DecoratedBox
- Container 应仅在需要组合 padding、decoration、constraints 时使用

### 代码分析工作流

#### 开发流程

1. **编码前**：
   - 确保编辑器启用了 Dart 分析
   - 配置好 `analysis_options.yaml`

2. **编码中**：
   - 实时关注编辑器的警告和提示
   - 及时修复 info 级别的问题
   - 不要累积警告

3. **提交前**：
   ```bash
   # 1. 运行完整分析（使用脚本过滤第三方警告）
   # Windows
   .\scripts\analyze.bat

   # Linux/macOS
   bash scripts/analyze.sh

   # 或者直接运行（会显示第三方插件警告）
   flutter analyze

   # 2. 格式化代码
   dart format .

   # 3. 运行测试
   flutter test
   ```

#### 第三方插件警告处理

**问题说明**：

某些第三方插件（如 `file_picker`）会产生平台集成的警告，例如：
```
Package file_picker:linux references file_picker:linux as the default plugin,
but it does not provide an inline implementation.
```

**这些警告的特点**：
- 来自第三方插件本身，不是你的代码问题
- 不影响项目运行和功能
- 插件维护者需要修复配置问题

**解决方案**：

1. **使用提供的分析脚本**（推荐）：
   ```bash
   # Windows
   .\scripts\analyze.bat

   # Linux/macOS
   bash scripts/analyze.sh
   ```

   这些脚本会自动过滤掉第三方插件的警告，只显示你自己代码的问题。

2. **在 CI/CD 中过滤**：
   ```bash
   # 在 CI 管道中
   flutter analyze 2>&1 | grep -v "Package file_picker:"
   ```

3. **忽略这些警告**：
   - 如果看到 "Package file_picker:" 相关的警告，可以安全忽略
   - 关注 "Analyzing node_graph_notebook..." 之后的问题

4. **定期检查插件更新**：
   ```bash
   # 检查并更新依赖
   flutter pub upgrade

   # 查看过时的包
   flutter pub outdated
   ```

**重要**：
- 不要在 `analysis_options.yaml` 中尝试忽略这些警告
- 它们不是 Dart analyzer 的输出，而是 Flutter 插件系统的输出
- 使用提供的脚本是最佳实践

#### 持续改进

1. **定期审查**：
   - 每周运行一次完整的代码分析
   - 修复所有 info 级别问题
   - 不要让问题累积

2. **团队协作**：
   - Code Review 时检查代码规范
   - 统一使用相同的 analysis_options.yaml
   - 分享常见问题和解决方案

3. **工具更新**：
   - 保持 Flutter/Dart SDK 最新
   - 定期更新 linter 规则
   - 关注新的最佳实践

### 代码格式化

```bash
# 格式化所有代码
dart format .

# 检查格式
dart format --output=none --set-exit-if-changed .
```

## 代码审查清单

提交代码前检查：

- [ ] 所有公共 API 有文档注释
- [ ] 没有编译警告
- [ ] 所有测试通过
- [ ] 没有调试 print 语句
- [ ] 没有注释掉的代码
- [ ] 命名符合规范
- [ ] 错误处理完善
- [ ] 性能考虑（大列表、异步操作）
- [ ] 代码格式化通过

## 总结

遵循这些规范将使代码：

- ✅ **更易读**：一致的命名和组织
- ✅ **更易维护**：清晰的结构和文档
- ✅ **更少错误**：类型安全和错误处理
- ✅ **更好性能**：优化和最佳实践
- ✅ **团队协作**：统一的编码风格
