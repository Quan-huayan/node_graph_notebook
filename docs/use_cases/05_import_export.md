# 用例 05: 数据导入导出工作流程

## 概述

本文档描述数据导入、导出、Markdown转换等操作的完整调用链和数据流。

## 用户角色

| 角色 | 描述 |
|------|------|
| 迁移用户 | 从其他工具导入数据或导出数据到其他格式 |
| 备份用户 | 导出数据进行备份 |
| Markdown用户 | 导入/导出Markdown格式的笔记 |
| 批量操作用户 | 批量转换节点格式或合并/拆分节点 |

## 用例列表

| 用例ID | 用例名称 | 优先级 | 触发者 |
|--------|----------|--------|--------|
| UC-CONV-01 | 导入Markdown文件 | P0 | 用户 |
| UC-CONV-02 | 导出为Markdown | P0 | 用户 |
| UC-CONV-03 | 批量导入 | P1 | 用户 |
| UC-CONV-04 | 批量导出 | P1 | 用户 |
| UC-CONV-05 | 节点拆分 | P2 | 用户/AI |
| UC-CONV-06 | 节点合并 | P2 | 用户 |

---

## UC-CONV-01: 导入Markdown文件

### 场景描述

用户从文件系统导入Markdown文件，转换为节点。

### 调用链

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 用户点击"导入"按钮                                             │
│    位置: ConverterPlugin → ConverterToolbarHook                  │
│    或 ImportExportPage                                           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 显示导入对话框                                                 │
│    组件: ImportMarkdownDialog                                    │
│    文件: lib/plugins/converter/ui/import_markdown_dialog.dart   │
│    功能:                                                          │
│    - 选择文件/文件夹                                              │
│    - 配置导入选项                                                 │
│    - 预览导入结果                                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. 用户选择文件并确认                                             │
│    ConverterBloc 发送导入事件                                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. ImportExportService.importMarkdown()                           │
│    文件: lib/plugins/converter/service/import_export_service.dart│
│    流程:                                                          │
│    4.1 读取文件内容                                               │
│    4.2 解析Markdown结构                                          │
│    4.3 提取标题、内容、元数据                                      │
│    4.4 创建Node对象                                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. 批量创建节点                                                   │
│    对于每个解析的Node:                                            │
│    ├── CreateNodeCommand                                         │
│    └── CommandBus.dispatch() → CreateNodeHandler                 │
│        └── NodeRepository.save()                                 │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. 导入完成，返回结果                                             │
│    ConversionResult {                                            │
│      success: bool,                                              │
│      importedCount: int,                                         │
│      failedCount: int,                                           │
│      errors: List<String>                                        │
│    }                                                             │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 7. UI 显示导入结果                                                │
│    - 成功: 显示导入的节点数量                                     │
│    - 失败: 显示错误列表                                           │
└─────────────────────────────────────────────────────────────────┘
```

### Markdown解析规则

```
# 标题 → Node.title
内容 → Node.content
--- 分隔符 → 新节点
```yaml 块 → Node.metadata
```

### 数据流

```
文件选择 → ImportMarkdownDialog
              │
              ▼
         ImportExportService
              │
              ├── 读取文件 → File.readAsString()
              │
              ├── 解析Markdown
              │   ├── 提取标题
              │   ├── 提取内容
              │   ├── 提取元数据
              │   └── 处理分隔符
              │
              ├── 创建Node对象
              │
              └── 批量CreateNodeCommand
                      │
                      ▼
                 CommandBus → Repository → 文件系统
```

---

## UC-CONV-02: 导出为Markdown

### 场景描述

用户将节点或图导出为Markdown文件。

### 调用链

```
用户选择节点/图 → 点击"导出"
    │
    ▼
ExportDialog / ExportMarkdownDialog
    │
    ├── 选择导出范围 (当前图/选中节点/全部节点)
    ├── 选择导出格式 (单文件/多文件)
    └── 确认导出
    │
    ▼
ConverterBloc 处理导出事件
    │
    ▼
ImportExportService.exportToMarkdown()
    │
    ├── 获取要导出的节点
    │   └── NodeRepository.findByIds()
    │
    ├── 生成Markdown内容
    │   ├── 单文件模式:
    │   │   ├── # {图名称}
    │   │   ├── 对于每个节点:
    │   │   │   ├── ## {节点标题}
    │   │   │   ├── {节点内容}
    │   │   │   └── --- (分隔符)
    │   │   └── 返回完整Markdown
    │   │
    │   └── 多文件模式:
    │       └── 对于每个节点:
    │           ├── 生成独立.md文件
    │           └── 文件名: {nodeId}.md
    │
    └── 写入文件
        └── File.writeAsString()
    │
    ▼
导出完成，显示成功消息
```

### 导出格式示例

```markdown
# 知识图谱: Flutter开发

## Flutter基础
Flutter是一个跨平台UI框架...

---

## Widget树
Flutter使用Widget树构建UI...

---

## 状态管理
状态管理是Flutter开发的核心...
```

---

## UC-CONV-03: 批量导入

### 场景描述

用户批量导入多个文件或整个文件夹。

### 调用链

```
用户选择文件夹 → 点击"批量导入"
    │
    ▼
ImportExportService.importDirectory()
    │
    ├── 扫描文件夹
    │   └── Directory.list() → 获取所有.md文件
    │
    ├── 对于每个文件:
    │   └── importMarkdown(file)
    │       ├── 解析
    │       ├── 创建节点
    │       └── 记录成功/失败
    │
    └── 返回批量结果
    │
    ▼
ConversionResult {
  success: bool,
  totalFiles: int,
  importedCount: int,
  failedCount: int,
  errors: Map<String, String>  // 文件路径 → 错误信息
}
    │
    ▼
UI 显示批量导入进度和结果
```

---

## UC-CONV-04: 批量导出

### 场景描述

用户批量导出多个节点或整个图到文件夹。

### 调用链

```
用户选择导出范围 → 选择目标文件夹 → 确认
    │
    ▼
ImportExportService.exportDirectory()
    │
    ├── 获取节点列表
    │   └── NodeRepository.queryAll() 或 findByIds()
    │
    ├── 创建目标文件夹
    │   └── Directory.create()
    │
    ├── 对于每个节点:
    │   ├── 生成Markdown内容
    │   ├── 构建文件路径
    │   └── File.writeAsString()
    │
    └── 返回导出结果
    │
    ▼
UI 显示导出进度和完成消息
```

---

## UC-CONV-05: 节点拆分

### 场景描述

将一个大节点拆分为多个小节点（手动或通过AI）。

### 调用链 (AI拆分)

```
用户选择节点 → 点击"AI拆分"
    │
    ▼
AIService.intelligentSplit(markdown: node.content)
    │
    ├── 构建Prompt
    │   └── "Split this content into logical sections..."
    │
    ├── AIProvider.generate()
    │
    └── 解析响应
        └── List<Node> (拆分后的节点)
    │
    ▼
对于每个拆分后的节点:
    ├── CreateNodeCommand
    └── 保存到Repository
    │
    ▼
原节点标记为已拆分或保留
```

### 调用链 (手动拆分)

```
用户在编辑器中选择内容 → 点击"拆分为新节点"
    │
    ▼
ConverterService.splitNode()
    │
    ├── 提取选中内容
    ├── 创建新节点 (内容 = 选中部分)
    ├── 从原节点移除选中内容
    └── 保存两个节点
    │
    ▼
UI 更新显示
```

---

## UC-CONV-06: 节点合并

### 场景描述

将多个节点合并为一个节点。

### 调用链

```
用户选择多个节点 → 点击"合并"
    │
    ▼
MergeRules 配置
    ├── 合并策略:
    │   ├── 内容追加 (append)
    │   ├── 内容插入 (insert at position)
    │   └── 自定义合并函数
    │
    └── 元数据合并策略:
        ├── 覆盖 (overwrite)
        ├── 合并 (merge)
        └── 保留第一个 (keep first)
    │
    ▼
ConverterService.mergeNodes()
    │
    ├── 获取所有选中节点
    ├── 根据策略合并内容
    ├── 合并元数据
    ├── 创建合并后的节点
    ├── 删除原节点 (可选)
    └── 保存
    │
    ▼
UI 更新显示合并后的节点
```

---

## 转换规则模型

### ConversionRule

```dart
ConversionRule {
  id: String;              // 规则ID
  name: String;            // 规则名称
  type: ConversionType;    // import/export/split/merge
  config: Map<String, dynamic>; // 配置
  enabled: bool;           // 是否启用
}
```

### ConversionConfig

```dart
ConversionConfig {
  sourceFormat: String;    // 源格式 (markdown, json, etc.)
  targetFormat: String;    // 目标格式
  options: Map<String, dynamic>; // 转换选项
}
```

### ConversionValidation

```dart
ConversionValidation {
  isValid: bool;
  errors: List<String>;
  warnings: List<String>;
}
```

---

## 数据流: 导入导出完整流程

```
文件系统                    ConverterPlugin                  ConverterService                  Repository
   │                              │                              │                              │
   │──选择文件────────────────────▶│                              │                              │
   │                              │──解析文件─────────────────────▶│                              │
   │                              │   (Markdown/JSON)             │                              │
   │                              │                              │──创建Node对象                  │
   │                              │                              │                              │
   │                              │◀──转换结果────────────────────│                              │
   │                              │                              │                              │
   │                              │──批量CreateNodeCommand─────────────────────────────────────▶│
   │                              │                              │                              │
   │                              │                              │                              │──写入文件
   │                              │◀────────────────────────────────────────────────────────────│
   │                              │                              │                              │
   │◀──导入完成───────────────────│                              │                              │
   │                              │                              │                              │
   │                              │                              │                              │
   │──导出请求────────────────────▶│                              │                              │
   │                              │──获取节点─────────────────────────────────────────────────▶│
   │                              │                              │◀──节点数据───────────────────│
   │                              │                              │                              │
   │                              │                              │──生成Markdown                │
   │                              │                              │                              │
   │◀──写入文件────────────────────│◀──导出结果───────────────────│                              │
```

---

## 扩展点

| 扩展点 | 说明 | 实现方式 |
|--------|------|----------|
| 新导入格式 | 支持新的导入格式 | 实现 ImportService 接口 |
| 新导出格式 | 支持新的导出格式 | 实现 ExportService 接口 |
| 自定义规则 | 用户自定义转换规则 | ConversionRule 配置 |
| 转换预览 | 预览转换结果 | ConverterPreviewPanel |
