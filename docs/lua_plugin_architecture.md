# Lua插件架构文档

## 概述

Lua插件为Node Graph Notebook提供了强大的脚本扩展能力，允许用户使用Lua语言编写自动化脚本和自定义功能。本文档详细说明了Lua插件的架构设计和实现细节。

## 架构设计

### 分层架构

```
┌─────────────────────────────────────────┐
│           UI Layer                      │
│  (ScriptManagerPage, EditorPage, etc.)  │
└────────────┬────────────────────────────┘
             │
┌────────────┴────────────────────────────┐
│        BLoC Layer                       │
│     (LuaScriptBloc)                     │
└────────────┬────────────────────────────┘
             │
┌────────────┴────────────────────────────┐
│      Command Layer                      │
│  (ExecuteLuaScriptCommand + Handler)    │
└────────────┬────────────────────────────┘
             │
┌────────────┴────────────────────────────┐
│      Service Layer                      │
│  LuaEngineService (双引擎架构)           │
│  ├─ SimpleScriptEngine (兼容模式)        │
│  └─ RealLuaEngine (完整Lua功能)         │
│  LuaAPIImplementation (实际功能实现)      │
│  LuaScriptService                       │
└─────────────────────────────────────────┘
```

### 核心组件

#### 1. LuaEngineService（Lua引擎服务）

**职责**:
- 管理Lua引擎生命周期
- 执行Lua脚本（字符串或文件）
- 注册Dart函数给Lua调用
- 管理Lua全局状态
- 支持双引擎架构

**双引擎架构**:
```dart
enum LuaEngineType {
  /// 简单脚本引擎（兼容模式）
  simple,

  /// 真正的Lua引擎（完整功能）
  realLua,
}
```

**关键方法**:
```dart
Future<void> initialize({LuaEngineType engineType})
Future<LuaExecutionResult> executeString(String script, {Map<String, dynamic>? context})
Future<LuaExecutionResult> executeFile(String filePath, {Map<String, dynamic>? context})
void registerFunction(String name, DartFunctionCallback fn)
Future<void> reset()
Future<void> dispose()
```

**设计决策**:
- 支持双引擎架构，兼容性和性能兼顾
- 真正Lua引擎使用`lua.dart`包
- 简单引擎作为fallback，用于学习场景
- 自动类型转换（Dart ↔ Lua）

#### 2. RealLuaEngine（真正Lua引擎）

**职责**:
- 提供完整的Lua语言支持
- 支持Lua 5.3语法
- 高性能脚本执行

**支持特性**:
- ✅ 完整Lua语法（表、闭包、协程）
- ✅ 标准库（string, table, math, io）
- ✅ 模块系统（require）
- ✅ 错误处理（pcall, xpcall）
- ✅ 元表和面向对象

#### 3. SimpleScriptEngine（简单脚本引擎）

**职责**:
- 提供基础的Lua子集支持
- 用于学习和简单场景
- 无外部依赖

**支持特性**:
- ✅ 变量和函数
- ✅ 条件语句和循环
- ✅ 基础算术和字符串操作
- ❌ 表、闭包、模块

#### 4. LuaAPIImplementation（API实现）

**职责**:
- 连接Lua脚本和实际业务逻辑
- 实现所有Lua API的具体功能
- 集成Repository层

**实现的API**:
```lua
-- 节点操作（完整实现）
createNode(title, content, parentId)
updateNode(id, title, content)
deleteNode(id)
getNode(id)
getAllNodes()
getChildNodes(parentId)

-- 消息显示（基础实现）
showMessage(message)
showWarning(message)
showError(message)

-- 工具函数（完整实现）
generateUUID()
getCurrentTime()
```

**集成点**:
- NodeRepository：节点CRUD操作
- GraphRepository：图数据访问
- UI回调：消息显示（待完善）

#### 5. LuaScriptService（脚本管理服务）

**职责**:
- 脚本文件的CRUD操作
- 脚本元数据解析
- 脚本启用/禁用管理
- 脚本缓存管理

**存储格式**:
```lua
-- id: unique-id
-- name: Script Name
-- description: Description
-- author: Author
-- version: 1.0.0
-- enabled: true
-- createdAt: 2026-03-21T00:00:00.000Z
-- updatedAt: 2026-03-21T00:00:00.000Z

-- 脚本内容
print("Hello, World!")
```

### Command模式

#### ExecuteLuaScriptCommand

```dart
class ExecuteLuaScriptCommand extends Command<LuaExecutionResult> {
  final String scriptPath;
  final String? scriptContent;
  final Map<String, dynamic>? context;
}
```

**设计优势**:
- 统一的执行入口
- 支持撤销（可选）
- 中间件管道支持
- 审计日志

### BLoC状态管理

#### LuaScriptBloc

**Events**:
```dart
LoadScriptsEvent
ExecuteScriptEvent
SaveScriptEvent
DeleteScriptEvent
ToggleScriptEvent
ClearConsoleEvent
```

**States**:
```dart
class LuaScriptState {
  final List<LuaScript> scripts;
  final bool isLoading;
  final String? executingScript;
  final LuaExecutionResult? lastResult;
  final String? error;
  final List<String> consoleOutput;
}
```

## 数据流

### 脚本执行流程

```
用户点击执行
    ↓
LuaScriptBloc.receive(ExecuteScriptEvent)
    ↓
CommandBus.dispatch(ExecuteLuaScriptCommand)
    ↓
ExecuteLuaScriptHandler.handle()
    ↓
LuaEngineService.executeFile()
    ↓
RealLuaEngine执行脚本
    ↓
调用LuaAPIImplementation注册的API
    ↓
访问Repository进行实际操作
    ↓
返回LuaExecutionResult
    ↓
LuaScriptBloc更新状态
    ↓
UI重新渲染
```

### API调用流程

```
Lua脚本调用API
    ↓
createNode("Test", "Content")
    ↓
RealLuaEngine查找注册函数
    ↓
LuaAPIImplementation.createNode()
    ↓
NodeRepository.save()
    ↓
持久化到文件系统
    ↓
返回结果到Lua
```

## 性能优化

### 1. 双引擎架构

```dart
// 根据场景选择引擎
final engine = LuaEngineService(
  engineType: isProduction
    ? LuaEngineType.realLua    // 生产环境：完整功能
    : LuaEngineType.simple,    // 学习环境：简单快速
);
```

### 2. 脚本缓存

```dart
class LuaScriptService {
  final Map<String, LuaScript> _cache = {};

  Future<LuaScript> getScript(String id) async {
    if (_cache.containsKey(id)) {
      return _cache[id]!;
    }
    // 加载并缓存
  }
}
```

### 3. 异步执行

```dart
// 脚本执行不阻塞UI
Future<LuaExecutionResult> executeScript(String path) async {
  return await compute(_executeInIsolate, path);
}
```

### 4. 资源复用

```dart
// 复用LuaState
class LuaEngineService {
  Future<void> reset() async {
    // 重置而非重新创建
    _realLuaEngine?.reset();
  }
}
```

## 扩展性

### 添加新API

```dart
// 1. 在LuaAPIImplementation中注册
void registerCustomAPI() {
  engineService.registerFunction('myAPI', (args) {
    // 实现逻辑
    return 0;
  });
}

// 2. 在Lua中调用
myAPI("parameter")
```

### 添加新事件

```dart
// 1. 订阅新事件类型
eventBus.stream.listen((event) {
  if (event is MyCustomEvent) {
    _handleMyEvent(event);
  }
});

// 2. 在Lua中处理
function onMyCustomEvent(event)
    print("处理自定义事件")
end
```

### 插件化API

```dart
// 其他插件可以扩展Lua API
class MyPlugin extends Plugin {
  @override
  Future<void> onLoad() async {
    final luaImpl = context.getService<LuaAPIImplementation>();
    luaImpl.registerMyPluginAPIs();
  }
}
```

## 安全考虑

### 当前实现：完全开放模式

**特点**:
- 无权限限制
- 完整API访问
- 适合个人使用

**潜在风险**:
- 恶意脚本可访问所有API
- 无资源限制
- 可能影响应用稳定性

### 安全最佳实践

1. **输入验证**
   ```dart
   void _validateScript(String content) {
     // 检查危险操作
     if (content.contains('os.execute')) {
       throw LuaSecurityException('禁止执行系统命令');
     }
   }
   ```

2. **资源限制**
   ```dart
   class LuaEngineService {
     final int maxExecutionTime = 5000; // 5秒
     final int maxMemoryUsage = 10 * 1024 * 1024; // 10MB
   }
   ```

3. **沙箱隔离**
   ```dart
   final service = LuaEngineService(
     enableSandbox: true, // 启用沙箱
   );
   ```

4. **错误隔离**
   ```dart
   try {
     await engineService.executeString(script);
   } catch (e) {
     // 错误不影响引擎稳定性
   }
   ```

## 测试策略

### 单元测试

- **RealLuaEngine**: 测试完整Lua语法支持
- **LuaEngineService**: 测试双引擎切换
- **LuaAPIImplementation**: 测试API实现
- **LuaScriptService**: 测试文件操作、缓存管理

### 集成测试

- **端到端脚本执行**: 从UI到引擎的完整流程
- **API调用**: Lua调用Dart API的完整流程
- **Repository集成**: 验证数据持久化

### 手动测试

- 执行示例脚本
- 创建自定义脚本
- 测试复杂Lua特性（表、闭包等）

## 故障排查

### 常见问题

#### 1. 脚本执行失败

**症状**: 执行脚本后显示错误

**排查步骤**:
1. 检查Lua语法
2. 查看控制台错误信息
3. 验证API调用
4. 检查引擎状态

#### 2. API调用无效果

**症状**: 调用createNode等API但无反应

**排查步骤**:
1. 确认使用realLua引擎
2. 检查Repository是否正确初始化
3. 查看日志输出
4. 验证数据持久化

#### 3. 性能问题

**症状**: 脚本执行缓慢

**优化方案**:
1. 使用realLua引擎（性能更好）
2. 避免频繁API调用
3. 优化算法复杂度
4. 使用脚本缓存

## 未来改进

### 短期目标

1. **完善消息API**
   - 实现UI回调机制
   - 支持SnackBar和Dialog

2. **增强错误处理**
   - 详细的错误信息
   - 错误恢复机制
   - 错误日志记录

3. **事件系统**
   - 实现LuaEventBridge
   - 支持应用事件响应

### 长期目标

1. **沙箱安全模式**
   - 权限控制
   - 资源限制
   - 代码签名

2. **脚本市场**
   - 脚本分享
   - 在线安装
   - 评分评论

3. **高级功能**
   - 异步API支持
   - 网络请求
   - 外部库加载

## 参考资料

- [Lua 5.3 参考手册](https://www.lua.org/manual/5.3/)
- [lua.dart包文档](https://pub.dev/packages/lua)
- [CQRS 模式](https://martinfowler.com/bliki/CQRS.html)
- [BLoC 模式](https://bloclibrary.dev/)
