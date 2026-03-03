# AI 辅助功能

## 功能概述

集成 AI 能力，提供智能节点生成、关系推荐、概念提取等功能。

## 核心功能

### 1. AI 节点生成

#### 功能描述
根据用户提示自动生成节点内容，支持多种生成模式。

#### 使用场景

##### (1) 从零生成
```
用户输入: "创建一个关于 Flutter 状态管理的节点"

AI 生成:
# Flutter 状态管理

Flutter 中有多种状态管理方案：

1. **Provider**
   - 官方推荐
   - 简单易用
   - 适合中小型应用

2. **Riverpod**
   - Provider 的改进版
   - 更好的类型安全
   - 支持空安全

3. **Bloc**
   - 强大的状态管理
   - 适合复杂应用
   - 学习曲线较陡

使用建议：
- 小项目使用 Provider
- 大型应用使用 Bloc 或 Riverpod
```

##### (2) 内容扩展
选中已有节点，让 AI 扩展内容：

```
当前内容: "React 是一个前端框架"

AI 扩展为:
# React

React 是由 Meta（前 Facebook）开发的开源 JavaScript 库，用于构建用户界面。

## 主要特点

- **组件化**: UI 拆分为独立可复用的组件
- **虚拟 DOM**: 高效的 DOM 更新
- **单向数据流**: 数据流向清晰可追踪
- **生态系统**: 丰富的第三方库

## 核心概念

1. **组件**: 函数组件或类组件
2. **Props**: 组件间数据传递
3. **State**: 组件内部状态
4. **Hooks**: 函数组件的状态管理
```

##### (3) 摘要生成
为长内容生成摘要：

```
输入: 2000 字的技术文档

AI 输出: 200 字的摘要，包含：
- 核心观点
- 关键结论
- 重要细节
```

#### API 设计

```dart
abstract class AIService {
  /// 生成节点
  Future<Node> generateNode({
    required String prompt,
    NodeType type,
    Map<String, dynamic>? options,
  });

  /// 扩展内容
  Future<String> expandContent({
    required String content,
    required String direction, // 'more_detail', 'examples', 'related'
  });

  /// 生成摘要
  Future<String> summarizeNode(Node node);

  /// 重写内容
  Future<String> rewriteContent({
    required String content,
    required String style, // 'formal', 'casual', 'concise'
  });
}
```

#### 使用示例

```dart
// 生成新节点
final node = await aiService.generateNode(
  prompt: '解释什么是概念地图',
  type: NodeType.content,
  options: AIGenerationOptions(
    maxLength: 500,
    temperature: 0.7,
  ),
);

// 扩展内容
final expanded = await aiService.expandContent(
  content: node.content!,
  direction: 'more_detail',
);

await nodeService.updateNode(node.id, content: expanded);
```

### 2. 智能关系推荐

#### 功能描述
分析节点内容，推荐可能的连接关系。

#### 推荐类型

##### (1) 语义相似
```
节点 A: "React Hooks 使用教程"
节点 B: "React useState 详解"

推荐: A → B (原因: 都是关于 React 的主题)
```

##### (2) 因果关系
```
节点 A: "过度加班导致健康问题"
节点 B: "工作效率下降"

推荐: A → B (原因: A 导致 B)
```

##### (3) 分类关系
```
节点 A: "Python"
节点 B: "编程语言"

推荐: A 属于 B (原因: A 是 B 的实例)
```

##### (4) 引用关系
```
节点 A: "详见 React 文档"
节点 B: "React 官方文档"

推荐: A 引用 B (原因: A 提到了 B)
```

#### AI 提示词

```
分析以下笔记节点，建议可能的双向链接：

节点列表：
{nodes}

请输出 JSON 格式的建议关系：
[{
  "from": "node_id",
  "to": "node_id",
  "type": "oneWay|bidirectional|category|hierarchical",
  "reason": "建议原因",
  "confidence": 0.8
}]

要求：
1. 只推荐置信度 > 0.6 的关系
2. 原因简洁明确
3. 考虑多种关系类型
```

#### API 设计

```dart
abstract class AIService {
  /// 推荐连接
  Future<List<ConnectionSuggestion>> suggestConnections({
    required List<Node> nodes,
    int? maxSuggestions,
    double minConfidence = 0.6,
  });

  /// 推荐连接到指定节点
  Future<List<ConnectionSuggestion>> suggestConnectionsToNode({
    required Node targetNode,
    required List<Node> candidateNodes,
  });
}
```

#### 使用示例

```dart
// 获取所有节点的推荐
final suggestions = await aiService.suggestConnections(
  nodes: await nodeService.getAllNodes(),
  maxSuggestions: 20,
);

// 显示推荐给用户
for (final suggestion in suggestions) {
  print('${suggestion.fromNodeId} → ${suggestion.toNodeId}');
  print('原因: ${suggestion.reason}');
  print('置信度: ${suggestion.confidence}');
}

// 用户确认后创建连接
await nodeService.connectNodes(
  fromNodeId: suggestions[0].fromNodeId,
  toNodeId: suggestions[0].toNodeId,
  direction: suggestions[0].direction,
);
```

### 3. 概念节点提取

#### 功能描述
识别高阶关系，自动创建概念节点。

#### 提取场景

##### (1) 因果链
```
节点: A → B → C (都是因果关系)

提取为:
概念节点 "因果链": 包含 [A, B, C]
描述: "A 导致 B，进而导致 C 的因果传递链"
```

##### (2) 分类体系
```
节点: "猫", "狗", "鸟", "鱼"

提取为:
概念节点 "动物": 包含 [猫, 狗, 鸟, 鱼]
描述: "这些节点都是动物的实例"
```

##### (3) 抽象概念
```
节点: "Vue 的响应式系统"
节点: "MobX 的 observable"
节点: "React 的 state"

提取为:
概念节点 "前端状态管理": 包含 [上述节点]
描述: "这些框架都实现了响应式状态管理"
```

##### (4) 关系的关系
```
关系1: React ←→ JavaScript
关系2: Vue ←→ JavaScript
关系3: Angular ←→ JavaScript

提取为:
概念节点 "JS 框架生态": 包含 [上述关系的节点]
描述: "这些框架都基于 JavaScript"
```

#### AI 提示词

```
将以下节点关系网络中的关键关系提取为概念节点：

节点：{nodes}
关系：{connections}

识别：
1. 跨多个节点的高阶关系（如"因果关系链"、"分类体系"）
2. 关系之间的关系（如"A导致B，B影响C" → "因果传递"）
3. 抽象概念（如多个具体实例的共同属性）

输出格式：
[{
  "concept_title": "概念名称",
  "concept_description": "概念描述",
  "contained_node_ids": ["id1", "id2"],
  "concept_type": "causalChain|classification|abstraction|relationship",
  "reason": "提取原因"
}]
```

#### API 设计

```dart
abstract class AIService {
  /// 提取概念节点
  Future<List<ConceptExtraction>> extractConcepts({
    required List<Node> nodes,
    required List<Connection> connections,
    int? maxConcepts,
  });

  /// 分析节点群组
  Future<List<NodeGroup>> analyzeGroups({
    required List<Node> nodes,
    GroupingMethod method,
  });
}

class ConceptExtraction {
  final String conceptTitle;
  final String conceptDescription;
  final List<String> containedNodeIds;
  final ConceptType conceptType;
  final String reason;
  final double confidence;
}

enum ConceptType {
  causalChain,     // 因果链
  classification,  // 分类
  abstraction,     // 抽象概念
  relationship,    // 关系关系
  process,         // 过程
}

enum GroupingMethod {
  semanticSimilarity,
  connectionDensity,
  topicClustering,
}
```

#### 使用示例

```dart
// 提取概念节点
final concepts = await aiService.extractConcepts(
  nodes: await nodeService.getAllNodes(),
  connections: await graphService.getGraphConnections(currentGraphId),
  maxConcepts: 10,
);

// 显示提取结果
for (final concept in concepts) {
  print('概念: ${concept.conceptTitle}');
  print('类型: ${concept.conceptType}');
  print('包含节点: ${concept.containedNodeIds}');
  print('原因: ${concept.reason}');
}

// 用户确认后创建概念节点
for (final concept in concepts) {
  await nodeService.createConceptNode(
    title: concept.conceptTitle,
    description: concept.conceptDescription,
    containedNodeIds: concept.containedNodeIds,
  );
}
```

### 4. 智能问答

#### 功能描述
基于用户的笔记内容，AI 回答相关问题。

#### 使用场景

```
用户问: "我的笔记中关于 React 的要点有哪些？"

AI 回答:
根据您的笔记，关于 React 的要点包括：

1. **组件化思想** (来自 "React 基础" 节点)
   - UI 拆分为独立组件
   - 组件可复用和维护

2. **Hooks 系统** (来自 "React Hooks" 节点)
   - useState: 状态管理
   - useEffect: 副作用处理

3. **虚拟 DOM** (来自 "React 性能优化" 节点)
   - 高效的 DOM 更新
   - Diff 算法优化

相关节点:
- React 基础
- React Hooks
- React 性能优化
```

#### API 设计

```dart
abstract class AIService {
  /// 回答问题
  Future<QAResult> answerQuestion({
    required String question,
    required List<Node> context,
    int? maxReferences,
  });

  /// 搜索相关节点
  Future<List<Node>> searchRelevantNodes({
    required String query,
    required List<Node> nodes,
  });
}

class QAResult {
  final String answer;
  final List<NodeReference> references;
  final List<String> relatedQuestions;
}

class NodeReference {
  final String nodeId;
  final String title;
  final String excerpt;
  final double relevance;
}
```

#### 使用示例

```dart
final result = await aiService.answerQuestion(
  question: '什么是 Flutter 的核心优势？',
  context: await nodeService.searchNodes('Flutter'),
);

print(result.answer);
print('\n参考来源:');
for (final ref in result.references) {
  print('- ${ref.title}');
  print('  ${ref.excerpt}');
}
```

### 5. AI 智能拆分

#### 功能描述
使用 AI 理解语义，智能拆分长文档为节点。

#### 实现方式

```
输入: 一篇 2000 字的长文档

AI 分析:
1. 识别主题变化点
2. 计算段落相似度
3. 确定最佳拆分位置

输出:
- 节点 1: 主题 A (300 字)
- 节点 2: 主题 B (500 字)
- 节点 3: 主题 C (400 字)
...
```

#### AI 提示词

```
将以下 Markdown 文档智能拆分为多个语义相关的节点：

{markdown}

要求：
1. 每个节点应该主题明确
2. 节点之间逻辑清晰
3. 保持内容的完整性
4. 节点长度适中（200-500字）
5. 识别并列出节点间的关系

输出 JSON：
{
  "nodes": [
    {
      "title": "节点标题",
      "content": "节点内容",
      "tags": ["标签1", "标签2"]
    }
  ],
  "connections": [
    {
      "from": "节点1",
      "to": "节点2",
      "type": "关系类型",
      "reason": "原因"
    }
  ]
}
```

## Flutter 集成

### 异步 UI 更新模式

**StreamBuilder 实时显示 AI 生成**：

```dart
class AIAssistantPage extends StatefulWidget {
  @override
  _AIAssistantPageState createState() => _AIAssistantPageState();
}

class _AIAssistantPageState extends State<AIAssistantPage> {
  final AIService _aiService = AIService();
  final TextEditingController _promptController = TextEditingController();
  String? _generatedContent;
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI 助手')),
      body: Column(
        children: [
          // 输入区域
          Padding(
            padding: EdgeInsets.all(16),
            child: TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: '输入提示词...',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // 生成按钮
          ElevatedButton(
            onPressed: _isGenerating ? null : _generateContent,
            child: _isGenerating
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('生成'),
          ),

          // 输出区域
          Expanded(
            child: _generatedContent == null
                ? Center(child: Text('等待生成...'))
                : MarkdownViewer(content: _generatedContent!),
          ),
        ],
      ),
    );
  }

  Future<void> _generateContent() async {
    setState(() => _isGenerating = true);

    try {
      final content = await _aiService.generateNode(
        prompt: _promptController.text,
      );

      setState(() => _generatedContent = content);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败: $e')),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }
}
```

### Stream 流式响应

**使用 StreamBuilder 显示流式生成**：

```dart
class StreamingAIPage extends StatelessWidget {
  final AIService _aiService = AIService();
  final TextEditingController _promptController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(
            controller: _promptController,
            decoration: InputDecoration(labelText: '提示词'),
          ),
          ElevatedButton(
            onPressed: () {
              final stream = _aiService.generateNodeStream(
                prompt: _promptController.text,
              );
              // 触发 StreamBuilder 重建
              context.read<AIModel>().setGenerationStream(stream);
            },
            child: Text('流式生成'),
          ),
          Expanded(
            child: StreamBuilder<String>(
              stream: context.watch<AIModel>().generationStream,
              builder: (ctx, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('错误: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return Center(child: Text('等待输入...'));
                }

                return MarkdownViewer(content: snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

**AI Service 的 Stream 实现**：

```dart
class AIService with ChangeNotifier {
  Future<AIClient> _getClient() async {
    // 返回配置的 AI 客户端
    return OpenAIClient(apiKey: _apiKey);
  }

  /// 流式生成节点内容
  Stream<String> generateNodeStream({
    required String prompt,
  }) async* {
    final client = await _getClient();

    try {
      await for (final chunk in client.streamGenerate(prompt)) {
        yield chunk;  // 逐块返回内容
      }
    } catch (e) {
      throw AIServiceException('流式生成失败: $e');
    }
  }

  /// 非流式生成
  Future<String> generateNode({
    required String prompt,
  }) async {
    final client = await _getClient();

    try {
      return await client.generate(prompt);
    } catch (e) {
      throw AIServiceException('生成失败: $e');
    }
  }
}

// OpenAI 客户端实现
class OpenAIClient implements AIClient {
  final String apiKey;
  final String baseUrl = 'https://api.openai.com/v1';

  OpenAIClient({required this.apiKey});

  @override
  Future<String> generate(String prompt) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  }

  @override
  Stream<String> streamGenerate(String prompt) async* {
    final response = await http.post(
      Uri.parse('$baseUrl/chat/completions'),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': 'gpt-4',
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
        'stream': true,
      }),
    );

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      final lines = chunk.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') return;

          try {
            final json = jsonDecode(data);
            final content = json['choices'][0]['delta']['content'];
            if (content != null) {
              yield content;
            }
          } catch (e) {
            // 忽略解析错误
          }
        }
      }
    }
  }
}
```

### AI Model 状态管理

```dart
class AIModel extends ChangeNotifier {
  final AIService _service;

  Stream<String>? _generationStream;
  String? _currentPrompt;
  List<String> _history = [];

  Stream<String>? get generationStream => _generationStream;
  String? get currentPrompt => _currentPrompt;
  List<String> get history => List.unmodifiable(_history);

  AIModel(this._service);

  void setGenerationStream(Stream<String> stream) {
    _generationStream = stream;
    notifyListeners();
  }

  Future<String> generateNode(String prompt) async {
    _currentPrompt = prompt;
    notifyListeners();

    try {
      final content = await _service.generateNode(prompt: prompt);
      _history.add(prompt);
      _history.add(content);
      notifyListeners();
      return content;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ConnectionSuggestion>> suggestConnections(
    List<Node> nodes,
  ) async {
    try {
      final suggestions = await _service.suggestConnections(nodes: nodes);
      return suggestions;
    } catch (e) {
      throw AIServiceException('推荐失败: $e');
    }
  }
}
```

### 错误处理和重试

```dart
class AIService with ChangeNotifier {
  int _retryCount = 0;
  static const int _maxRetries = 3;

  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } on AIServiceException catch (e) {
      if (_retryCount < _maxRetries && e.isRetryable) {
        _retryCount++;
        await Future.delayed(Duration(seconds: _retryCount * 2));
        return _executeWithRetry(operation);
      }
      _retryCount = 0;
      rethrow;
    }
  }
}

class AIServiceException implements Exception {
  final String message;
  final bool isRetryable;

  AIServiceException(this.message, {this.isRetryable = false});

  @override
  String toString() => message;
}
```

## UI 设计

### 支持的提供商

#### 1. OpenAI (GPT-4)

```dart
final openai = OpenAIProvider(
  apiKey: 'your-api-key',
  model: 'gpt-4',
  maxTokens: 2000,
);

aiService.setProvider(openai);
```

#### 2. Anthropic (Claude)

```dart
final claude = AnthropicProvider(
  apiKey: 'your-api-key',
  model: 'claude-3-sonnet',
  maxTokens: 4000,
);

aiService.setProvider(claude);
```

#### 3. 本地 Ollama

```dart
final ollama = OllamaProvider(
  baseUrl: 'http://localhost:11434',
  model: 'llama2',
);

aiService.setProvider(ollama);
```

#### 4. 自定义提供商

```dart
class CustomAIProvider implements AIClient {
  @override
  Future<String> generate(String prompt) async {
    // 调用自定义 API
    final response = await http.post(
      Uri.parse('https://your-api.com/generate'),
      body: {'prompt': prompt},
    );
    return response.body;
  }
}

aiService.setProvider(CustomAIProvider());
```

## UI 设计

### AI 助手面板

```
┌─────────────────────────────────────────────┐
│  🤖 AI 助手                      [设置]    │
├─────────────────────────────────────────────┤
│  [生成节点] [关系推荐] [概念提取] [问答]   │
├─────────────────────────────────────────────┤
│                                             │
│  提示词: _______________________________     │
│           [AI 生成建议 ↓]                   │
│                                             │
│  选项:                                       │
│  长度: [▼适中]  温度: [▼0.7]               │
│  ☑ 包含示例  ☑ 添加引用                     │
│                                             │
│  [生成]  [清空]                             │
├─────────────────────────────────────────────┤
│  建议的关系: (3)                            │
│  • "React" → "Hooks"                        │
│    原因: 都是 React 核心概念                │
│    [添加] [忽略]                            │
│                                             │
│  • "Vue" ↔ "React"                          │
│    原因: 相似的框架                          │
│    [添加] [忽略]                            │
├─────────────────────────────────────────────┤
│  发现的概念: (2)                            │
│  • "前端框架" (包含 4 个节点)               │
│    [创建概念节点]                            │
│                                             │
│  • "状态管理模式" (包含 3 个节点)           │
│    [创建概念节点]                            │
└─────────────────────────────────────────────┘
```

### 智能拆分对话框

```
┌─────────────────────────────────────────────┐
│  AI 智能拆分                                │
├─────────────────────────────────────────────┤
│  输入文档: [📁 选择文件]                    │
│  文件名: notes.md (2,345 字)                │
├─────────────────────────────────────────────┤
│  拆分预览:                                  │
│  ┌───────────────────────────────┐         │
│  │ 预计创建 5 个节点             │         │
│  │                               │         │
│  │ 1. React 简介 (234 字)        │         │
│  │ 2. 组件化开发 (456 字)        │         │
│  │ 3. Hooks 详解 (567 字)        │         │
│  │ 4. 状态管理 (345 字)          │         │
│  │ 5. 性能优化 (678 字)          │         │
│  │                               │         │
│  │ 识别到 3 个连接关系           │         │
│  └───────────────────────────────┘         │
├─────────────────────────────────────────────┤
│  AI 提供商: [▼OpenAI GPT-4]                │
│  [重新拆分]  [确认创建]  [取消]            │
└─────────────────────────────────────────────┘
```

## 配置

### AI 设置

```json
{
  "ai_provider": "openai",
  "api_key": "sk-...",
  "model": "gpt-4",
  "temperature": 0.7,
  "max_tokens": 2000,
  "timeout": 30000,
  "retry_attempts": 3
}
```

### 功能开关

```json
{
  "features": {
    "auto_suggest_connections": true,
    "auto_extract_concepts": false,
    "smart_split_by_default": false,
    "ai_summary_on_hover": true
  }
}
```

## 注意事项

1. **API 密钥安全**：加密存储，不上传到云端
2. **成本控制**：设置 token 限制，避免超额费用
3. **隐私保护**：不发送敏感内容到 AI
4. **离线支持**：本地 AI（Ollama）作为备选
5. **结果验证**：AI 生成的内容需要用户确认

## 性能优化

1. **缓存响应**：相同提示词使用缓存
2. **批量处理**：多个请求合并发送
3. **流式输出**：实时显示生成内容
4. **后台处理**：耗时的 AI 操作异步执行

## 测试

```dart
test('should generate node content', () async {
  final node = await aiService.generateNode(
    prompt: '什么是 Flutter',
  );

  expect(node.title, isNotEmpty);
  expect(node.content, isNotEmpty);
  expect(node.content, contains('Flutter'));
});

test('should suggest connections', () async {
  final nodes = [
    createNode(title: 'React'),
    createNode(title: 'Vue'),
  ];

  final suggestions = await aiService.suggestConnections(
    nodes: nodes,
  );

  expect(suggestions.isNotEmpty);
});
```

## 未来扩展

- [ ] 多模态 AI（图像识别）
- [ ] 语音转文字节点
- [ ] 自动翻译节点内容
- [ ] AI 聊天界面
- [ ] 自定义训练模型
- [ ] 协作 AI（多个 AI 协同）
