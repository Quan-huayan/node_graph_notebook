# 用例 03: AI 集成工作流程

## 概述

本文档描述 AI 功能的完整调用链和数据流，包括 AI 对话、Function Calling、节点分析、智能连接推荐等功能。

## 用户角色

| 角色 | 描述 |
|------|------|
| AI辅助用户 | 使用AI分析节点、生成内容、推荐连接 |
| 对话用户 | 通过AI对话框提问和获取答案 |
| 自动化用户 | 通过Function Calling让AI自动操作节点 |
| 配置用户 | 配置AI提供商（OpenAI、Anthropic、智谱AI） |

## 用例列表

| 用例ID | 用例名称 | 优先级 | 触发者 |
|--------|----------|--------|--------|
| UC-AI-01 | 配置AI提供商 | P0 | 用户 |
| UC-AI-02 | AI对话问答 | P0 | 用户 |
| UC-AI-03 | 分析节点内容 | P1 | 用户 |
| UC-AI-04 | 生成节点内容 | P1 | 用户 |
| UC-AI-05 | 推荐连接 | P1 | 用户/AI |
| UC-AI-06 | Function Calling | P0 | AI系统 |
| UC-AI-07 | 图摘要生成 | P2 | 用户 |

---

## UC-AI-01: 配置AI提供商

### 场景描述

用户配置AI服务提供商（OpenAI、Anthropic、智谱AI）并设置API密钥。

### 调用链

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 用户打开设置对话框                                             │
│    位置: SettingsPlugin → Settings Dialog                        │
│    或通过 AISettingsHook 进入AI设置                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 用户选择AI提供商并填写API密钥                                  │
│    支持提供商:                                                    │
│    - OpenAIProvider (GPT-4)                                      │
│    - AnthropicProvider (Claude-3)                                │
│    - ZhipuAIProvider (GLM-4)                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. 保存到设置服务                                                 │
│    SettingsService.save()                                        │
│    - API密钥加密存储                                              │
│    - 提供商配置序列化                                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. AIServiceImpl.setProvider()                                    │
│    - 创建对应的AIProvider实例                                     │
│    - notifyListeners() 通知UI                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. UI 显示"AI已连接"状态                                          │
└─────────────────────────────────────────────────────────────────┘
```

### 数据流

| 阶段 | 数据格式 | 存储位置 |
|------|----------|----------|
| 用户配置 | Map<String, dynamic> | SettingsService |
| API密钥 | 加密字符串 | SharedPreferences |
| AIProvider | OpenAIProvider/AnthropicProvider/ZhipuAIProvider | AIServiceImpl |

---

## UC-AI-02: AI对话问答

### 场景描述

用户通过AI对话框提问，系统基于节点上下文提供答案。

### 调用链

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 用户打开AI聊天对话框                                           │
│    组件: AIChatDialog                                            │
│    位置: lib/plugins/ai/ui/ai_chat_dialog.dart                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 用户输入问题并发送                                             │
│    输入: 问题文本                                                 │
│    可选: 选择相关节点作为上下文                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. AIChatDialog 调用 AIService.answerQuestion()                   │
│    参数:                                                          │
│    - question: 用户问题                                           │
│    - context: 相关节点列表 (可选)                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. AIServiceImpl.answerQuestion()                                 │
│    文件: lib/plugins/ai/service/ai_service.dart                 │
│    流程:                                                          │
│    4.1 将上下文节点内容拼接成 contextText                         │
│    4.2 构建 prompt: "Context:\n{contextText}\n\nQuestion: {q}"  │
│    4.3 调用 AIProvider.generate(prompt)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. AIProvider 调用外部API                                         │
│    ┌─────────────────────────────────────────────────────┐       │
│    │ OpenAIProvider:                                      │       │
│    │   POST https://api.openai.com/v1/chat/completions    │       │
│    │   Body: { model, messages, max_tokens, temperature } │       │
│    └─────────────────────────────────────────────────────┘       │
│    ┌─────────────────────────────────────────────────────┐       │
│    │ AnthropicProvider:                                   │       │
│    │   POST https://api.anthropic.com/v1/messages         │       │
│    │   Headers: { x-api-key, anthropic-version }         │       │
│    └─────────────────────────────────────────────────────┘       │
│    ┌─────────────────────────────────────────────────────┐       │
│    │ ZhipuAIProvider:                                     │       │
│    │   POST https://open.bigmodel.cn/api/paas/v4/...      │       │
│    │   Auth: JWT Token                                    │       │
│    └─────────────────────────────────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. 返回AI响应                                                     │
│    AIChatDialog 显示答案到聊天界面                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 对话数据流

```
用户输入 → AIChatDialog → AIService.answerQuestion()
                              │
                              ├── 收集上下文节点
                              │   └── NodeRepository.findByIds()
                              │
                              ├── 构建 Prompt
                              │
                              └── AIProvider.generate()
                                      │
                                      ├── HTTP POST → AI API
                                      │
                                      └── 解析响应 → 返回文本
                                              │
                                              ▼
                                    AIChatDialog 显示结果
```

---

## UC-AI-03: 分析节点内容

### 场景描述

AI分析节点内容，提供摘要、关键词、主题和情感分析。

### 调用链

```
用户选择节点 → 点击"AI分析"
    │
    ▼
AIPlugin 触发分析请求
    │
    ▼
AIService.analyzeNode(node)
    │
    ├── 构建 Prompt: "Analyze this node..."
    ├── AIProvider.generate(prompt)
    └── 解析响应
    │
    ▼
NodeAnalysis {
  nodeId: String,
  summary: String,
  keywords: List<String>,
  topics: List<String>,
  sentiment: String?
}
    │
    ▼
UI 显示分析结果
```

---

## UC-AI-04: 生成节点内容

### 场景描述

用户通过Prompt让AI生成新的节点内容。

### 调用链

```
用户输入Prompt → 点击"生成"
    │
    ▼
AIService.generateNode(prompt: "...", options: {...})
    │
    ├── AIProvider.generate(prompt)
    ├── 解析响应 (标题 + 内容)
    └── 创建 Node 对象
    │
    ▼
Node {
  id: UUID,
  title: AI生成的标题,
  content: AI生成的内容,
  position: Offset(100, 100),
  size: Size(300, 400),
  ...
}
    │
    ▼
CreateNodeCommand (自动创建)
    │
    ▼
CommandBus → CreateNodeHandler → NodeRepository.save()
    │
    ▼
新节点显示在图中
```

---

## UC-AI-05: 推荐连接

### 场景描述

AI分析节点内容相似度，推荐可能的连接关系。

### 调用链

```
用户点击"推荐连接"
    │
    ▼
AIService.suggestConnections(nodes: [...], maxSuggestions: 10)
    │
    ├── 遍历所有节点对
    ├── 计算相似度 _calculateSimilarity()
    │   ├── 标题完全匹配: 1.0
    │   ├── 标题包含: 0.7
    │   └── 单词重叠: overlap/total
    │
    ├── 过滤相似度 > 0.3 的节点对
    └── 按置信度排序，返回Top N
    │
    ▼
List<ConnectionSuggestion> [
  {
    fromNodeId: "node-1",
    toNodeId: "node-2",
    reason: "Similar content: 85%",
    confidence: 0.85,
    relationType: "relatesTo"
  },
  ...
]
    │
    ▼
UI 显示推荐列表 → 用户确认应用
    │
    ▼
ConnectNodesCommand (批量执行)
    │
    ▼
连接创建完成
```

---

## UC-AI-06: Function Calling

### 场景描述

AI通过Function Calling自动执行节点操作（创建、更新、删除、连接、搜索等）。

### 架构说明

Function Calling 是 AI 与系统集成的核心机制，允许 AI 模型调用应用内部的工具函数。

### 工具注册表

```
AIToolRegistry
    │
    ├── create_node_tool
    │   └── CreateNodeTool
    │       ├── name: "create_node"
    │       ├── description: "Create a new node"
    │       └── parameters: { title, content, position }
    │
    ├── update_node_tool
    │   └── UpdateNodeTool
    │       ├── name: "update_node"
    │       └── parameters: { nodeId, title, content }
    │
    ├── delete_node_tool
    │   └── DeleteNodeTool
    │       ├── name: "delete_node"
    │       └── parameters: { nodeId }
    │
    ├── connect_nodes_tool
    │   └── ConnectNodesTool
    │       ├── name: "connect_nodes"
    │       └── parameters: { sourceId, targetId, relationType }
    │
    ├── search_nodes_tool
    │   └── SearchNodesTool
    │       ├── name: "search_nodes"
    │       └── parameters: { query }
    │
    └── list_nodes_tool
        └── ListNodesTool
            ├── name: "list_nodes"
            └── parameters: { limit, offset }
```

### Function Calling 流程

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 用户发送消息到AI                                              │
│    例如: "创建一个关于Flutter的节点"                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. AIFunctionCallingService 构建请求                              │
│    文件: lib/plugins/ai/function_calling/service/                │
│         ai_function_calling_service.dart                        │
│    流程:                                                          │
│    - 收集所有已注册的工具定义                                     │
│    - 构建 tools 参数列表                                         │
│    - 发送到AI API (支持 function calling 的模型)                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. AI API 返回 function call 请求                                 │
│    响应示例:                                                      │
│    {                                                              │
│      "role": "assistant",                                         │
│      "function_call": {                                           │
│        "name": "create_node",                                     │
│        "arguments": "{\"title\": \"Flutter\", ...}"              │
│      }                                                            │
│    }                                                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. AIFunctionCallingService 解析并执行工具                        │
│    流程:                                                          │
│    4.1 查找工具: AIToolRegistry.getTool(toolName)                │
│    4.2 验证参数: AIToolParameterValidator.validate()             │
│    4.3 执行工具: tool.execute(arguments)                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. 工具执行 - 以 CreateNodeTool 为例                              │
│    文件: lib/plugins/ai/function_calling/tools/                  │
│         create_node_tool.dart                                   │
│    流程:                                                          │
│    5.1 解析参数 (title, content, position)                       │
│    5.2 创建 Node 对象                                            │
│    5.3 通过 CommandBus 分发 CreateNodeCommand                    │
│    5.4 返回执行结果 (success/error)                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. 将工具执行结果返回给 AI                                        │
│    AI 根据结果生成最终回复给用户                                   │
└─────────────────────────────────────────────────────────────────┘
```

### 工具参数验证

```
AIToolParameterValidator
    │
    ├── 检查必填参数
    ├── 验证参数类型 (String, int, double, bool, enum)
    ├── 验证参数范围 (min/max)
    └── 验证枚举值
```

### Function Calling 数据流

```
用户消息 → AIFunctionCallingService
              │
              ├── 构建请求 (带 tools 定义)
              │
              ▼
         AI API (支持 function calling)
              │
              ▼
         Function Call 响应
              │
              ├── 解析工具名和参数
              │
              ▼
         AIToolRegistry.getTool(name)
              │
              ├── AIToolParameterValidator.validate()
              │
              ▼
         Tool.execute(arguments)
              │
              ├── 调用内部API (CommandBus/Repository)
              │
              ▼
         执行结果 → AI API → 用户回复
```

---

## UC-AI-07: 图摘要生成

### 场景描述

AI分析整个图结构，生成图的摘要信息。

### 调用链

```
用户点击"生成图摘要"
    │
    ▼
AIService.generateGraphSummary(nodes, connections)
    │
    ├── 收集所有节点内容
    ├── 分析连接关系
    ├── 构建 Prompt
    └── AIProvider.generate()
    │
    ▼
GraphSummary {
  title: String,
  description: String,
  keyTopics: List<String>,
  nodeCount: int,
  connectionCount: int
}
    │
    ▼
UI 显示图摘要
```

---

## AI 提供商对比

| 提供商 | API端点 | 认证方式 | 推荐模型 | 特点 |
|--------|---------|----------|----------|------|
| OpenAI | /v1/chat/completions | Bearer Token | gpt-4 | 通用能力强 |
| Anthropic | /v1/messages | x-api-key Header | claude-3-sonnet | 长上下文处理 |
| 智谱AI | /api/paas/v4/chat/completions | JWT Token | glm-4 | 中文优化 |

---

## 时序图: AI Function Calling

```
用户           AIChatDialog    AIFunctionCalling   AIToolRegistry    Tool      CommandBus    Repository
 │                 │                  │                  │              │           │             │
 │──发送消息───────▶│                  │                  │              │           │             │
 │                 │──请求AI(带tools)─▶│                  │              │           │             │
 │                 │                  │────HTTP POST─────▶│              │           │             │
 │                 │                  │◀───响应───────────│              │           │             │
 │                 │                  │  (function_call)  │              │           │             │
 │                 │                  │                  │              │           │             │
 │                 │                  │──查找工具─────────▶│              │           │             │
 │                 │                  │◀──返回工具实例─────│              │           │             │
 │                 │                  │                  │              │           │             │
 │                 │                  │──验证参数─────────▶│              │           │             │
 │                 │                  │◀──验证通过─────────│              │           │             │
 │                 │                  │                  │              │           │             │
 │                 │                  │──execute()──────────────────────▶│           │             │
 │                 │                  │                  │              │──dispatch─▶│             │
 │                 │                  │                  │              │           │──save()─────▶│
 │                 │                  │                  │              │◀──────────│             │
 │                 │                  │◀──结果────────────│              │           │             │
 │                 │◀──AI最终回复──────│                  │              │           │             │
 │◀──显示回复──────│                  │                  │              │           │             │
```

---

## 扩展点

| 扩展点 | 说明 | 实现方式 |
|--------|------|----------|
| 新AI提供商 | 添加新的AI服务提供商 | 实现 AIProvider 接口 |
| 新工具 | 添加Function Calling工具 | 实现 AITool 接口并注册 |
| 对话历史 | 支持多轮对话上下文 | 扩展 answerQuestion 方法 |
| 流式响应 | 支持流式输出 | 修改 AIProvider.generate() |
