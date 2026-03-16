# Core 模块重构实施总结

## 已完成的工作（11/13 任务，85%）

### ✅ 阶段 1: 服务层重构

#### 1.1 SettingsRegistry 系统（已完成）
- **创建文件**: `lib/core/services/infrastructure/settings_registry.dart`
- **功能特性**:
  - `SettingDefinition<T>` - 设置定义类，支持验证器、回调、敏感数据标记
  - `SettingsRegistry` - 设置注册表，支持类型安全的 get/set
  - 加密存储敏感信息（API Key 等）
  - 设置分组管理
  - JSON 导入/导出功能
  - 统计信息 API

#### 1.2 ThemeRegistry 系统（已完成）
- **创建文件**: `lib/core/services/infrastructure/theme_registry.dart`
- **功能特性**:
  - `ThemeExtension` - 主题扩展定义
  - `ThemeRegistry` - 主题注册表，支持亮色/暗色主题
  - 主题颜色合并功能
  - 插件主题扩展管理
  - JSON 导入/导出功能

#### 1.3 StoragePathService（已完成）
- **创建文件**: `lib/core/services/infrastructure/storage_path_service.dart`
- **功能特性**:
  - 从 SettingsService 提取核心存储路径管理
  - 支持自定义路径和默认路径
  - 路径验证和选择
  - 存储使用情况统计
  - `StorageUsage` 数据类

### ✅ 阶段 2: 任务注册表系统

#### 2.1 TaskRegistry（已完成）
- **创建文件**: `lib/core/execution/task_registry.dart`
- **功能特性**:
  - `CPUTaskFactory` typedef - 任务工厂函数
  - `ResultConverter<T>` typedef - 结果转换器
  - `TaskRegistry` - 任务类型注册表
  - 动态任务注册和反序列化
  - 结果类型转换
  - 插件任务类型管理（按插件 ID 分组）

#### 2.2 ExecutionEngine 更新（已完成）
- **修改文件**: `lib/core/execution/execution_engine.dart`
- **变更内容**:
  - 接受 `TaskRegistry` 参数
  - 使用 `_taskRegistry.convertResult()` 替代硬编码 switch
  - 移除任务特定的结果转换逻辑
  - 设置全局 TaskRegistry 供 isolate 使用
  - 完全解耦具体任务实现

#### 2.3 CPUTask.deserialize 更新（已完成）
- **修改文件**: `lib/core/execution/cpu_task.dart`
- **变更内容**:
  - 修改 `deserialize()` 签名接受 `TaskRegistry` 参数
  - 删除硬编码的 switch 语句
  - 委托给 `registry.deserialize(data)`
  - 添加 TaskRegistry 导入

### ✅ 阶段 3: 插件系统更新

#### 3.1 PluginContext 更新（已完成）
- **修改文件**: `lib/core/plugin/plugin_context.dart`
- **变更内容**:
  - 添加 `taskRegistry` 字段（TaskRegistry）
  - 添加 `settingsRegistry` 字段（SettingsRegistry）
  - 添加 `themeRegistry` 字段（ThemeRegistry）
  - 更新构造函数
  - 注册到 DependencyContainer

#### 3.2 PluginManager 更新（已完成）
- **修改文件**: `lib/core/plugin/plugin_manager.dart`
- **变更内容**:
  - 构造函数接受三个注册表参数
  - 创建和管理三个注册表实例
  - 通过 PluginContext 传递给插件
  - 添加 getter 方法暴露注册表
  - 删除对 SharedPreferencesAsync 的错误依赖

#### 3.3 GraphPlugin 任务注册（已完成）
- **修改文件**: `lib/plugins/builtin_plugins/graph/graph_plugin.dart`
- **创建文件**: `lib/plugins/builtin_plugins/graph/tasks/serialized_tasks.dart`
- **变更内容**:
  - 创建 `_TextLayoutTaskSerialized`
  - 创建 `_NodeSizingTaskSerialized`
  - 创建 `_ConnectionPathTaskSerialized`
  - 在 `onLoad()` 中注册所有任务类型
  - 提供工厂函数和结果转换器

### ✅ 阶段 4: 应用初始化更新

#### 4.1 core.dart 导出更新（已完成）
- **修改文件**: `lib/core/core.dart`
- **变更内容**:
  - 导出 models/
  - 导出 repositories/
  - 导出 services/infrastructure/*
  - 导出 commands/*
  - 导出 events/*
  - 导出 execution/*
  - 导出 plugin/*
  - 导出 config/*

#### 4.2 services.dart 导出更新（已完成）
- **修改文件**: `lib/core/services/services.dart`
- **变更内容**:
  - 导出 infrastructure/*
  - 保留向后兼容的导出（theme_service, settings_service 等）

#### 4.3 app.dart 初始化更新（已完成）
- **修改文件**: `lib/app.dart`
- **变更内容**:
  - 添加三个注册表的实例变量
  - 在 `_initializeCore()` 中创建所有注册表
  - 使用 TaskRegistry 初始化 ExecutionEngine
  - 传递注册表到 PluginManager
  - 在 MultiProvider 中添加注册表 Provider
  - 添加 `_registerCoreSettings()` 方法

---

## 待完成的工作（2/13 任务，15%）

### ⏳ DataRecovery Plugin（待实施）

**目标**: 将 `DataRecoveryService` 转换为 Command/Handler 模式

**需要创建的文件**:
```
lib/plugins/builtin_plugins/data_recovery/
├── command/
│   ├── validate_data_command.dart
│   └── repair_data_command.dart
├── handler/
│   ├── validate_data_handler.dart
│   └── repair_data_handler.dart
└── data_recovery_plugin.dart
```

**实施步骤**:
1. 创建 `ValidateDataCommand` 和 `RepairDataCommand`
2. 创建对应的 Command Handlers
3. 迁移 `DataRecoveryService` 的逻辑到 Handlers
4. 注册 Commands 到 CommandBus
5. 删除旧的 `lib/core/services/data_recovery_service.dart`

### ⏳ AI Plugin SettingsRegistry 更新（待实施）

**目标**: 演示插件如何使用 SettingsRegistry

**需要修改的文件**:
- `lib/plugins/builtin_plugins/ai/ai_plugin.dart`

**实施步骤**:
1. 在 `onLoad()` 中注册 AI 设置：
   - `ai.provider` - AI 提供商
   - `ai.baseUrl` - API 基础 URL
   - `ai.model` - 模型名称
   - `ai.apiKey` - API 密钥（敏感信息）
2. 更新代码从 SettingsRegistry 读取设置
3. 移除对 SettingsService 的直接依赖

---

## 架构改进成果

### ✅ 消除的问题

1. **循环依赖**: ✅ 解决
   - `lib/core/execution/` 不再依赖 `lib/plugins/` 中的任务
   - 通过 TaskRegistry 动态注册实现反向依赖

2. **硬编码任务类型**: ✅ 解决
   - `CPUTask.deserialize()` 不再有 switch 语句
   - 任务类型通过注册表动态发现

3. **服务层职责不清**: ✅ 大部分解决
   - 基础设施服务移至 `infrastructure/`
   - 插件特定配置移至注册表
   - DataRecoveryService 待转换为 Command

4. **导出不完整**: ✅ 解决
   - `core.dart` 完整导出所有模块
   - 清晰的公共 API

5. **紧耦合**: ✅ 解决
   - `ExecutionEngine._convertResult()` 不再硬编码转换
   - 通过注册表实现完全解耦

### ✅ 新增的能力

1. **插件可扩展性**:
   - 插件可以注册自定义任务类型
   - 插件可以注册自定义设置项
   - 插件可以注册主题扩展

2. **类型安全**:
   - SettingsRegistry 提供类型安全的 get/set
   - TaskRegistry 提供类型安全的结果转换

3. **响应式更新**:
   - SettingsRegistry 和 ThemeRegistry 都是 ChangeNotifier
   - 设置变化自动通知监听器

4. **关注点分离**:
   - Core 只包含基础设施和框架抽象
   - 领域逻辑通过插件提供
   - 写操作统一使用 CommandBus

---

## 验证步骤

### 1. 代码分析
```bash
# 运行代码分析
flutter analyze

# 应该没有错误（除了可能的第三方插件警告）
```

### 2. 代码生成
```bash
# 生成 JSON 序列化代码
flutter pub run build_runner build --delete-conflicting-outputs
```

### 3. 运行测试
```bash
# 运行所有测试
flutter test

# 应该全部通过（注意：一些测试可能需要更新以适应新架构）
```

### 4. 启动应用
```bash
# 运行应用
flutter run

# 验证：
# - 应用启动无错误
# - 插件加载成功
# - 创建节点正常工作
# - 文本布局正常（验证 TaskRegistry）
```

---

## 兼容性说明

### 向后兼容的组件

1. **SettingsService** - 保留，用于向后兼容
2. **ThemeService** - 保留，用于向后兼容
3. **DataRecoveryService** - 保留，待转换为插件后删除

### Breaking Changes

1. **CPUTask.deserialize()**
   - 旧签名: `static CPUTask<dynamic> deserialize(Map<String, dynamic> data)`
   - 新签名: `static CPUTask<dynamic> deserialize(Map<String, dynamic> data, TaskRegistry registry)`
   - 影响: 只有自定义任务类型的插件需要更新

2. **ExecutionEngine.initialize()**
   - 旧签名: `Future<void> initialize({int? maxWorkers})`
   - 新签名: `Future<void> initialize({int? maxWorkers, TaskRegistry? taskRegistry})`
   - 影响: 直接调用 ExecutionEngine 的代码需要传递 TaskRegistry

3. **PluginContext**
   - 新增三个可选字段：`taskRegistry`, `settingsRegistry`, `themeRegistry`
   - 影响: 无（向后兼容）

---

## 下一步建议

### 短期（1-2 周）
1. 完成 DataRecovery Plugin 转换
2. 完成 AI Plugin SettingsRegistry 迁移
3. 编写单元测试覆盖新功能
4. 更新文档

### 中期（1-2 月）
1. 迁移其他插件使用 SettingsRegistry
2. 添加更多任务类型到 TaskRegistry
3. 性能优化和基准测试
4. 插件开发文档

### 长期（3-6 月）
1. 插件市场（动态加载插件）
2. 插件沙箱和安全隔离
3. 插件版本管理和依赖解析
4. 插件性能监控和分析

---

## 文件清单

### 新建文件（9 个）
1. `lib/core/services/infrastructure/settings_registry.dart`
2. `lib/core/services/infrastructure/theme_registry.dart`
3. `lib/core/services/infrastructure/storage_path_service.dart`
4. `lib/core/execution/task_registry.dart`
5. `lib/plugins/builtin_plugins/graph/tasks/serialized_tasks.dart`

### 修改文件（8 个）
1. `lib/core/plugin/plugin_context.dart` - 添加三个注册表字段
2. `lib/core/plugin/plugin_manager.dart` - 创建和管理注册表
3. `lib/core/execution/execution_engine.dart` - 使用 TaskRegistry
4. `lib/core/execution/cpu_task.dart` - 更新 deserialize 方法
5. `lib/plugins/builtin_plugins/graph/graph_plugin.dart` - 注册任务类型
6. `lib/core/core.dart` - 完善导出
7. `lib/core/services/services.dart` - 重新组织导出
8. `lib/app.dart` - 初始化三个注册表

### 待创建文件（5 个，DataRecovery Plugin）
1. `lib/plugins/builtin_plugins/data_recovery/command/validate_data_command.dart`
2. `lib/plugins/builtin_plugins/data_recovery/command/repair_data_command.dart`
3. `lib/plugins/builtin_plugins/data_recovery/handler/validate_data_handler.dart`
4. `lib/plugins/builtin_plugins/data_recovery/handler/repair_data_handler.dart`
5. `lib/plugins/builtin_plugins/data_recovery/data_recovery_plugin.dart`

---

## 总结

本次重构成功实现了以下目标：

1. ✅ **消除循环依赖** - 通过 TaskRegistry 实现动态注册
2. ✅ **消除硬编码** - 不再使用 switch 语句
3. ✅ **理清服务层职责** - 基础设施与领域逻辑分离
4. ✅ **完善导出** - core.dart 提供清晰的公共 API
5. ✅ **实现完全解耦** - ExecutionEngine 不依赖具体任务

架构现在遵循整洁架构原则：
- **Core** 只包含基础设施和框架抽象
- **Plugins** 提供所有领域功能
- **CommandBus** 统一处理写操作
- **Repository** 处理读操作

系统现在具备了良好的可扩展性和可维护性，为未来的插件生态打下坚实基础。
