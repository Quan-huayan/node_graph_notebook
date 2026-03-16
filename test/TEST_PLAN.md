# 测试计划

## 1. 测试目标

为 node_graph_notebook 项目编写全面的测试套件，确保：
- 核心功能的正确性
- 代码质量和稳定性
- 系统各组件的集成正常
- 回归测试的有效性

## 2. 测试策略

### 2.1 单元测试

针对项目中的核心模块和功能进行独立测试，验证每个组件的行为是否符合预期。

### 2.2 集成测试

测试多个组件之间的交互和集成，确保系统作为一个整体正常工作。

## 3. 测试范围

### 3.1 核心模块测试

#### 3.1.1 命令系统
- 测试 Command 接口和实现
- 测试 CommandBus 的消息传递
- 测试 CommandHandler 的注册和执行
- 测试 Middleware 的执行顺序和功能

#### 3.1.2 事件系统
- 测试事件的发布和订阅机制
- 测试 AppEvents 的各种事件类型

#### 3.1.3 元数据系统
- 测试 MetadataSchema 的定义和验证
- 测试 StandardMetadata 的实现
- 测试 MetadataValidator 的验证逻辑

#### 3.1.4 模型系统
- 测试 Node 模型的属性和行为
- 测试 Graph 模型的节点管理
- 测试 Connection 模型的连接逻辑
- 测试 NodeReference 的引用机制

#### 3.1.5 插件系统
- 测试 PluginManager 的插件生命周期管理
- 测试 PluginRegistry 的插件注册和发现
- 测试 DependencyContainer 的依赖注入
- 测试 ServiceRegistry 的服务注册和获取
- 测试 UIHook 系统的钩子机制

#### 3.1.6 仓库系统
- 测试 GraphRepository 的图数据操作
- 测试 NodeRepository 的节点数据操作
- 测试 MetadataIndex 的元数据索引

#### 3.1.7 服务系统
- 测试 SettingsService 的设置管理
- 测试 ThemeService 的主题管理
- 测试 DataRecoveryService 的数据恢复
- 测试 ShortcutManager 的快捷键管理

### 3.2 插件测试

#### 3.2.1 AI 插件
- 测试 AI 服务的初始化和配置
- 测试 AI 命令的执行
- 测试 AI 对话框的交互

#### 3.2.2 转换器插件
- 测试 ConverterService 的转换逻辑
- 测试导入/导出功能
- 测试转换规则的应用

#### 3.2.3 图形插件
- 测试 GraphBloc 的状态管理
- 测试 NodeBloc 的节点操作
- 测试图形操作命令的执行
- 测试节点连接和断开逻辑

#### 3.2.4 搜索插件
- 测试 SearchBloc 的搜索逻辑
- 测试搜索预设的管理
- 测试搜索结果的处理

#### 3.2.5 布局插件
- 测试布局算法的应用
- 测试布局命令的执行

### 3.3 UI 测试

- 测试核心工具栏的交互
- 测试侧边栏的显示和隐藏
- 测试对话框的打开和关闭
- 测试页面的导航和切换

### 3.4 集成测试

- 测试完整的图形创建和编辑流程
- 测试节点的添加、编辑和删除
- 测试图形的导入和导出
- 测试 AI 集成功能
- 测试插件的安装和卸载

## 4. 测试工具和框架

- **单元测试**：使用 `flutter_test` 和 `test` 包
- **BLoC 测试**：使用 `bloc_test` 包
- **模拟测试**：使用 `mockito` 包
- **集成测试**：使用 `integration_test` 包

## 5. 测试文件结构

```
test/
  ├── core/
  │   ├── commands/
  │   ├── events/
  │   ├── metadata/
  │   ├── models/
  │   ├── plugin/
  │   ├── repositories/
  │   └── services/
  ├── plugins/
  │   ├── ai/
  │   ├── converter/
  │   ├── graph/
  │   ├── search/
  │   └── layout/
  ├── ui/
  │   ├── bars/
  │   ├── dialogs/
  │   └── pages/
  ├── integration/
  └── TEST_PLAN.md
```

## 6. 测试执行计划

1. **阶段 1**：核心模块单元测试
   - 命令系统测试
   - 事件系统测试
   - 模型系统测试
   - 插件系统测试
   - 仓库系统测试
   - 服务系统测试

2. **阶段 2**：插件单元测试
   - AI 插件测试
   - 转换器插件测试
   - 图形插件测试
   - 搜索插件测试
   - 布局插件测试

3. **阶段 3**：UI 测试
   - 工具栏测试
   - 侧边栏测试
   - 对话框测试
   - 页面测试

4. **阶段 4**：集成测试
   - 完整流程测试
   - 功能集成测试

## 7. 测试覆盖率目标

- 核心模块：≥ 80%
- 插件模块：≥ 70%
- UI 模块：≥ 60%
- 整体项目：≥ 75%

## 8. 测试运行命令

### 运行所有单元测试
```bash
flutter test
```

### 运行特定目录的测试
```bash
flutter test test/core/
```

### 运行集成测试
```bash
flutter test integration_test/
```

### 查看测试覆盖率
```bash
flutter test --coverage
```

## 9. 测试维护策略

- 每次代码变更后运行相关测试
- 新功能开发时同步编写测试
- 定期运行完整测试套件
- 分析测试覆盖率，补充缺失的测试

## 10. 测试文档

- 测试计划文档（本文件）
- 测试用例文档
- 测试覆盖率报告
- 测试结果分析报告
