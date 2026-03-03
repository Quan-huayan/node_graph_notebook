# Markdown ↔ 节点转换功能

## 功能概述

实现 Markdown 文件与节点图之间的双向转换，让用户可以：
- 将现有 Markdown 笔记导入为节点图
- 将节点图导出为 Markdown 文档
- 支持智能拆分和合并

## 核心功能

### 1. Markdown → 节点转换

#### 功能描述
将 Markdown 文件解析为多个节点，根据规则自动拆分。

#### 支持的拆分策略

##### (1) 按标题拆分
```markdown
# 主标题

内容...

## 子标题 1

内容...

## 子标题 2

内容...
```

**配置**：
```dart
HeadingSplitRule(
  level: 2,              // 按 ## 拆分
  minContentLength: 50,  // 最小内容长度
  keepOriginalHeading: true,
)
```

**结果**：
- Node 1: "子标题 1" + 内容
- Node 2: "子标题 2" + 内容

##### (2) 按分割符拆分
```markdown
内容部分 1

---

内容部分 2

___

内容部分 3
```

**配置**：
```dart
SeparatorSplitRule(
  pattern: '---',       // 分割符
  keepSeparator: false,
  regexFlags: 'gm',
)
```

##### (3) AI 智能拆分
使用 AI 分析语义，智能划分节点。

**配置**：
```dart
AISmartSplitRule(
  minSectionLength: 200,
  semanticSimilarityThreshold: 0.7,
  provider: AIProvider.openai,
  maxSections: 10,
)
```

**AI 提示词**：
```
分析以下 Markdown 内容，将其拆分为语义相关的段落：

{markdown}

要求：
1. 每个段落应该主题明确
2. 段落长度适中（200-500字）
3. 保留标题结构
4. 返回 JSON 格式
```

##### (4) 自定义正则拆分
```dart
CustomRegexRule(
  pattern: r'<split>',    // 自定义标签
  flags: 'gm',
)
```

#### 自动提取连接

从 Markdown 中提取 `[[wiki_links]]` 语法：

```markdown
# 前端开发

[[React]] 是一个流行的框架。

详见 [[框架对比]] 文档。
```

**自动创建连接**：
- 当前节点 → "React" 节点
- 当前节点 → "框架对比" 节点

#### 使用示例

```dart
final converter = ConverterService();

// 读取 Markdown 文件
final markdown = await File('notes.md').readAsString();

// 配置转换规则
final rule = ConversionRule(
  splitStrategy: SplitStrategy.heading,
  headingRule: HeadingSplitRule(level: 2),
);

// 执行转换
final nodes = await converter.markdownToNodes(
  markdown: markdown,
  rule: rule,
  filename: 'notes.md',
);

print('创建了 ${nodes.length} 个节点');
```

### 2. 节点 → Markdown 转换

#### 功能描述
将多个节点合并为一个 Markdown 文件。

#### 支持的合并策略

##### (1) 层级合并
按照节点关系构建层级结构：

```markdown
# 主标题

## 子节点 1

内容...

## 子节点 2

内容...
```

**配置**：
```dart
HierarchyMergeRule(
  rootNodeId: 'main',
  addToc: true,          // 添加目录
  headingLevels: true,   // 使用标题层级
  separator: '\n\n---\n\n',
)
```

##### (2) 顺序合并
按照创建时间或自定义顺序合并：

```markdown
# 节点 1

内容...

---

# 节点 2

内容...
```

**配置**：
```dart
SequenceMergeRule(
  sortBy: SortBy.createdAt,
  separator: '\n\n---\n\n',
  addMetadata: false,
)
```

##### (3) 自定义合并
使用自定义模板：

```dart
CustomMergeRule(
  template: '''
# {title}

{content}

---
*Created: {created_at}*
*Tags: {tags}*
''',
);
```

#### 使用示例

```dart
final converter = ConverterService();

// 获取要导出的节点
final nodes = await nodeService.getAllNodes();

// 配置合并规则
final rule = MergeRule(
  strategy: MergeStrategy.hierarchy,
  hierarchyRule: HierarchyMergeRule(
    addToc: true,
    headingLevels: true,
  ),
);

// 执行转换
final markdown = await converter.nodesToMarkdown(
  nodes: nodes,
  rule: rule,
);

// 保存到文件
await File('export.md').writeAsString(markdown);
```

### 3. 批量转换

#### 功能描述
批量转换整个目录的 Markdown 文件。

#### 使用示例

```dart
final converter = ConverterService();

final result = await converter.convertDirectory(
  inputPath: '/path/to/markdown/files',
  outputPath: '/path/to/graph/data',
  config: ConversionConfig(
    splitRule: HeadingSplitRule(level: 2),
    extractConnections: true,
    extractTags: true,
    createConceptNodes: true,
  ),
);

print('成功: ${result.successCount}');
print('失败: ${result.failureCount}');
print('耗时: ${result.duration}');
```

### 4. 智能功能

#### AI 辅助拆分

```dart
final nodes = await converter.smartSplit(
  markdown: longDocument,
  provider: AIProvider.anthropic,
);
```

#### 自动概念提取

```dart
final concepts = await aiService.extractConcepts(
  nodes: nodes,
  connections: connections,
);

// 自动创建概念节点
for (final concept in concepts) {
  await nodeService.createConceptNode(
    title: concept.title,
    description: concept.description,
    containedNodeIds: concept.containedNodeIds,
  );
}
```

## UI 界面设计

### 转换配置页面

```
┌──────────────────────────────────────────────────┐
│  Markdown ↔ 节点转换                            │
├──────────────────────────────────────────────────┤
│  源文件：[📁 选择文件/目录]                     │
│  转换方向：○ MD → 节点  ○ 节点 → MD            │
├──────────────────────────────────────────────────┤
│  拆分规则 (MD → 节点)：                          │
│  ○ 按标题拆分                                    │
│    标题级别: [▼2] (1-6)                         │
│    ☑ 保留原标题                                 │
│  ○ 按分割符拆分                                  │
│    分割符: [_____]                               │
│  ○ AI 智能拆分                                   │
│    AI 提供商: [▼OpenAI]                         │
│  ○ 自定义正则                                    │
│    正则: [____________]                         │
├──────────────────────────────────────────────────┤
│  合并规则 (节点 → MD)：                          │
│  ○ 层级合并                                      │
│    根节点: [▼选择节点]                          │
│    ☑ 添加目录                                    │
│    ☑ 使用标题层级                                │
│  ○ 顺序合并                                      │
│    排序: [▼创建时间 ▼]                          │
├──────────────────────────────────────────────────┤
│  高级选项：                                      │
│  ☑ 自动提取 [[wiki_links]] 为连接              │
│  ☑ 提取 #tags 为节点标签                        │
│  ☑ 解析 Frontmatter                             │
│  ☑ 自动生成概念节点                              │
│  ☑ 保留原始文件                                  │
├──────────────────────────────────────────────────┤
│  [预览转换结果]  [开始转换]  [取消]              │
└──────────────────────────────────────────────────┘
```

### 预览窗口

```
┌──────────────────────────────────────────────────┐
│  转换预览                                        │
├──────────────────────────────┬───────────────────┤
│  原始 Markdown              │  节点预览          │
│  ┌──────────────────────┐   │  ┌──────────────┐ │
│  │ # 主标题             │   │  │ ┌──────────┐ │ │
│  │                      │   │  │ │主标题    │ │ │
│  │ ## 章节1             │   │  │ └──────────┘ │ │
│  │ 内容...              │   │  │              │ │
│  │                      │   │  │ ┌──────────┐ │ │
│  │ ## 章节2             │   │  │ │章节1    │ │ │
│  │ 内容...              │   │  │ └──────────┘ │ │
│  └──────────────────────┘   │  │              │ │
│                            │  │ ┌──────────┐ │ │
│                            │  │ │章节2    │ │ │
│                            │  │ └──────────┘ │ │
│                            │  │              │ │
│                            │  │ [连接线]     │ │
│                            │  └──────────────┘ │
├──────────────────────────────┴───────────────────┤
│  预计创建 3 个节点，2 个连接                     │
│  [确认]  [重新配置]                             │
└──────────────────────────────────────────────────┘
```

## API 设计

### 核心接口

```dart
abstract class ConverterService {
  /// Markdown → 节点
  Future<List<Node>> markdownToNodes({
    required String markdown,
    required ConversionRule rule,
    String? filename,
  });

  /// 节点 → Markdown
  Future<String> nodesToMarkdown({
    required List<Node> nodes,
    required MergeRule rule,
  });

  /// 文件 → 节点
  Future<List<Node>> fileToNodes({
    required String filePath,
    required ConversionRule rule,
  });

  /// 节点 → 文件
  Future<void> nodesToFile({
    required List<Node> nodes,
    required String filePath,
    required MergeRule rule,
  });

  /// 批量转换
  Future<ConversionResult> convertDirectory({
    required String inputPath,
    required String outputPath,
    required ConversionConfig config,
  });

  /// 智能拆分
  Future<List<Node>> smartSplit({
    required String markdown,
    AIProvider? provider,
  });

  /// 验证转换
  Future<ConversionValidation> validateConversion({
    required String markdown,
    required List<Node> nodes,
  });
}
```

### 数据模型

```dart
class ConversionRule {
  final SplitStrategy splitStrategy;
  final HeadingSplitRule? headingRule;
  final SeparatorSplitRule? separatorRule;
  final AISmartSplitRule? aiRule;
  final CustomRegexRule? customRule;

  final bool extractConnections;
  final bool extractTags;
  final bool parseFrontmatter;
}

class MergeRule {
  final MergeStrategy strategy;
  final HierarchyMergeRule? hierarchyRule;
  final SequenceMergeRule? sequenceRule;
  final CustomMergeRule? customRule;
}

class ConversionConfig {
  final ConversionRule rule;
  final bool createConceptNodes;
  final bool preserveOriginalFiles;
  final bool exportToSingleFile;
}

class ConversionResult {
  final int successCount;
  final int failureCount;
  final List<String> errors;
  final Duration duration;
  final List<String> createdNodeIds;
}

class ConversionValidation {
  final bool isValid;
  final List<String> warnings;
  final List<String> suggestions;
}
```

## Flutter 集成

### 文件选择器

使用 `file_picker` 包选择文件和目录：

```dart
class FilePickerService {
  /// 选择单个 Markdown 文件
  Future<File?> pickMarkdownFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown'],
    );

    if (result.files.single.path == null) return null;
    return File(result.files.single.path!);
  }

  /// 选择目录
  Future<Directory?> pickDirectory() async {
    final directoryPath = await FilePicker.platform.getDirectoryPath();
    if (directoryPath == null) return null;
    return Directory(directoryPath);
  }

  /// 批量选择文件
  Future<List<File>> pickMultipleMarkdownFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown'],
      allowMultiple: true,
    );

    if (result.files.isEmpty) return [];

    return result.files
        .map((f) => f.path)
        .whereType<String>()
        .map((path) => File(path))
        .toList();
  }
}
```

### 转换 UI 流程

```dart
class ConverterPage extends StatefulWidget {
  @override
  _ConverterPageState createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  final _converterService = ConverterService();
  ConversionRule _rule = ConversionRule(
    splitStrategy: SplitStrategy.heading,
    headingRule: HeadingSplitRule(level: 2),
  );

  bool _isConverting = false;
  String? _selectedPath;
  List<Node> _previewNodes = [];
  int _totalNodes = 0;
  int _convertedNodes = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Markdown 转节点'),
      ),
      body: Column(
        children: [
          // 文件选择
          ListTile(
            leading: Icon(Icons.folder_open),
            title: Text(_selectedPath ?? '选择文件或目录'),
            trailing: Icon(Icons.chevron_right),
            onTap: _selectSource,
          ),

          // 转换规则配置
          ExpansionTile(
            title: Text('转换规则'),
            children: [
              RadioListTile<SplitStrategy>(
                title: Text('按标题拆分'),
                value: SplitStrategy.heading,
                groupValue: _rule.splitStrategy,
                onChanged: (value) => setState(() {
                  _rule = _rule.copyWith(splitStrategy: value);
                }),
              ),
              // 更多规则选项...
            ],
          ),

          // 预览
          if (_previewNodes.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _previewNodes.length,
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(_previewNodes[i].title),
                  subtitle: Text(
                    '${_previewNodes[i].content?.length ?? 0} 字符',
                  ),
                ),
              ),
            ),

          // 进度
          if (_isConverting)
            LinearProgressIndicator(
              value: _totalNodes > 0 ? _convertedNodes / _totalNodes : 0,
            ),

          // 操作按钮
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _selectedPath == null ? null : _previewConversion,
                  child: Text('预览'),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _previewNodes.isEmpty ? null : _startConversion,
                  child: Text('开始转换'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectSource() async {
    final path = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('选择来源'),
        children: [
          SimpleDialogOption(
            child: Text('选择单个文件'),
            onPressed: () async {
              final file = await FilePickerService().pickMarkdownFile();
              Navigator.of(ctx).pop(file?.path);
            },
          ),
          SimpleDialogOption(
            child: Text('选择目录'),
            onPressed: () async {
              final dir = await FilePickerService().pickDirectory();
              Navigator.of(ctx).pop(dir?.path);
            },
          ),
        ],
      ),
    );

    if (path != null) {
      setState(() => _selectedPath = path);
    }
  }

  Future<void> _previewConversion() async {
    if (_selectedPath == null) return;

    setState(() => _isConverting = true);

    try {
      final isDirectory = await FileSystemEntity.isDirectory(_selectedPath!);
      List<Node> nodes;

      if (isDirectory) {
        // 批量转换预览
        nodes = await _converterService.previewDirectoryConversion(
          _selectedPath!,
          _rule,
        );
      } else {
        // 单文件预览
        final markdown = await File(_selectedPath!).readAsString();
        nodes = await _converterService.markdownToNodes(
          markdown: markdown,
          rule: _rule,
        );
      }

      setState(() {
        _previewNodes = nodes.take(50).toList(); // 只显示前50个
        _totalNodes = nodes.length;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('预览失败: $e')),
      );
    } finally {
      setState(() => _isConverting = false);
    }
  }

  Future<void> _startConversion() async {
    setState(() => _isConverting = true);

    try {
      final isDirectory = await FileSystemEntity.isDirectory(_selectedPath!);

      if (isDirectory) {
        // 批量转换
        final result = await _converterService.convertDirectory(
          inputPath: _selectedPath!,
          outputPath: 'data/nodes',
          config: ConversionConfig(rule: _rule),
          onProgress: (current, total) {
            setState(() {
              _convertedNodes = current;
              _totalNodes = total;
            });
          },
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('转换完成: ${result.successCount} 成功, ${result.failureCount} 失败'),
          ),
        );
      } else {
        // 单文件转换
        final markdown = await File(_selectedPath!).readAsString();
        final nodes = await _converterService.markdownToNodes(
          markdown: markdown,
          rule: _rule,
        );

        for (final node in nodes) {
          await context.read<NodeService>().createNode(
            title: node.title,
            content: node.content,
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建了 ${nodes.length} 个节点')),
        );
      }

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转换失败: $e')),
      );
    } finally {
      setState(() => _isConverting = false);
    }
  }
}
```

### 后台任务处理

使用 Isolate 处理大量文件的转换：

```dart
class IsolateConverterService {
  Future<ConversionResult> convertInIsolate({
    required String inputPath,
    required String outputPath,
    required ConversionRule rule,
  }) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(
      _conversionWorker,
      _ConversionMessage(
        sendPort: receivePort.sendPort,
        inputPath: inputPath,
        outputPath: outputPath,
        rule: rule.toJson(),
      ),
    );

    final result = await receivePort.first as ConversionResult;
    return result;
  }

  static void _conversionWorker(_ConversionMessage message) async {
    // 在独立 Isolate 中执行转换
    final result = await ConverterService().convertDirectory(
      inputPath: message.inputPath,
      outputPath: message.outputPath,
      config: ConversionConfig(rule: message.rule),
    );

    message.sendPort.send(result);
  }
}

class _ConversionMessage {
  final SendPort sendPort;
  final String inputPath;
  final String outputPath;
  final Map<String, dynamic> rule;

  _ConversionMessage({
    required this.sendPort,
    required this.inputPath,
    required this.outputPath,
    required this.rule,
  });
}
```

## 实现细节

### Markdown 解析

使用 `markdown` 包解析 Markdown：

```dart
import 'package:markdown/markdown.dart';

class MarkdownParser {
  List<MarkdownNode> parse(String markdown) {
    final lines = markdown.split('\n');
    final nodes = <MarkdownNode>[];

    for (final line in lines) {
      if (line.startsWith('#')) {
        // 标题
        final level = line.indexOf(' ');
        final title = line.substring(level + 1);
        nodes.add(MarkdownNode(
          type: MarkdownNodeType.heading,
          level: level,
          content: title,
        ));
      } else if (line.contains('[[') && line.contains(']]')) {
        // Wiki 链接
        final links = _extractWikiLinks(line);
        // 处理链接...
      }
      // 其他解析...
    }

    return nodes;
  }

  List<String> _extractWikiLinks(String line) {
    final pattern = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = pattern.allMatches(line);
    return matches.map((m) => m.group(1)!).toList();
  }
}
```

### Wiki 链接处理

```dart
class WikiLinkProcessor {
  List<String> extractLinks(String content) {
    final pattern = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = pattern.allMatches(content);
    return matches.map((m) => m.group(1)!).toList();
  }

  Future<List<Connection>> createConnections({
    required Node node,
    required Map<String, String> titleToIdMap,
  }) async {
    final links = extractLinks(node.content!);
    final connections = <Connection>[];

    for (final link in links) {
      final targetId = titleToIdMap[link];
      if (targetId != null) {
        connections.add(Connection(
          fromNodeId: node.id,
          toNodeId: targetId,
          direction: ConnectionDirection.outgoing,
        ));
      }
    }

    return connections;
  }
}
```

### 标签提取

```dart
class TagExtractor {
  List<String> extractTags(String content) {
    final tags = <String>[];

    // 提取 #tag
    final tagPattern = RegExp(r'#([a-zA-Z0-9_\u4e00-\u9fa5]+)');
    final tagMatches = tagPattern.allMatches(content);
    tags.addAll(tagMatches.map((m) => m.group(1)!));

    // 提取 Frontmatter 中的 tags
    final frontmatter = _parseFrontmatter(content);
    if (frontmatter['tags'] != null) {
      tags.addAll(List<String>.from(frontmatter['tags']));
    }

    return tags;
  }

  Map<String, dynamic> _parseFrontmatter(String content) {
    if (!content.startsWith('---')) return {};

    final end = content.indexOf('---', 3);
    if (end == -1) return {};

    final frontmatter = content.substring(3, end);
    // 解析 YAML 格式
    // ...
  }
}
```

## 测试

### 单元测试

```dart
test('should split markdown by heading', () async {
  final markdown = '''
# Main

## Section 1

Content 1

## Section 2

Content 2
''';

  final rule = HeadingSplitRule(level: 2);
  final nodes = await converter.markdownToNodes(
    markdown: markdown,
    rule: ConversionRule(splitStrategy: SplitStrategy.heading),
  );

  expect(nodes.length, 2);
  expect(nodes[0].title, 'Section 1');
  expect(nodes[1].title, 'Section 2');
});

test('should extract wiki links', () async {
  final content = 'See [[React]] and [[Vue]]';

  final links = WikiLinkProcessor().extractLinks(content);

  expect(links, ['React', 'Vue']);
});
```

### 集成测试

```dart
test('should convert markdown file to nodes', () async {
  final file = File('test.md');
  await file.writeAsString(testMarkdown);

  final nodes = await converter.fileToNodes(
    filePath: file.path,
    rule: testRule,
  );

  expect(nodes.isNotEmpty);
  expect(await nodeExists(nodes[0].id), true);
});
```

## 使用场景

### 1. 导入现有笔记

用户有大量 Markdown 笔记，想导入到节点图中：

```
1. 点击 "导入 Markdown"
2. 选择笔记目录
3. 配置拆分规则（按标题拆分）
4. 点击 "开始转换"
5. 自动创建节点和连接
```

### 2. 导出为文档

用户想将节点图分享为 Markdown 文档：

```
1. 选择要导出的节点
2. 点击 "导出为 Markdown"
3. 配置合并规则（层级合并，添加目录）
4. 选择保存位置
5. 生成 Markdown 文件
```

### 3. 批量处理

整理大量 Markdown 文件：

```
1. 选择根目录
2. 递归处理所有 .md 文件
3. 自动提取标签和链接
4. 创建统一的节点图
```

## 注意事项

1. **编码问题**：确保文件使用 UTF-8 编码
2. **图片处理**：本地图片需要复制到项目目录
3. **循环引用**：检测并处理循环链接
4. **性能优化**：大文件分段处理，避免内存溢出
5. **备份**：转换前自动备份原始文件

## 未来扩展

- [ ] 支持 Pandoc 风格的元数据块
- [ ] 支持 Org-mode 格式
- [ ] 支持 Notion 导入
- [ ] 支持 Obsidian 笔记库导入
- [ ] 智能合并相似节点
- [ ] 自动检测最佳拆分策略
