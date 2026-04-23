# 用例 06: Lua脚本自动化工作流程

## 概述

本文档描述Lua脚本系统的完整调用链和数据流，包括脚本创建、执行、动态Hook、API调用等自动化功能。

## 用户角色

| 角色 | 描述 |
|------|------|
| 自动化用户 | 使用Lua脚本批量操作节点和图 |
| 脚本开发者 | 编写和调试Lua脚本 |
| 高级用户 | 使用动态Hook自定义UI行为 |

## 用例列表

| 用例ID | 用例名称 | 优先级 | 触发者 |
|--------|----------|--------|--------|
| UC-LUA-01 | 创建Lua脚本 | P0 | 用户 |
| UC-LUA-02 | 执行Lua脚本 | P0 | 用户 |
| UC-LUA-03 | 编辑Lua脚本 | P1 | 用户 |
| UC-LUA-04 | 删除Lua脚本 | P1 | 用户 |
| UC-LUA-05 | 启用/禁用脚本 | P1 | 用户 |
| UC-LUA-06 | 脚本API调用 | P0 | Lua引擎 |
| UC-LUA-07 | 动态Hook注册 | P1 | Lua脚本 |
| UC-LUA-08 | 脚本间通信 | P2 | Lua脚本 |

---

## UC-LUA-01: 创建Lua脚本

### 场景描述

用户创建新的Lua脚本用于自动化操作。

### 调用链

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 用户打开Lua脚本管理器                                          │
│    位置: LuaPlugin → Lua Script Menu (Hook点)                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. 用户点击"新建脚本"                                             │
│    输入:                                                          │
│    - 脚本名称                                                     │
│    - 脚本描述 (可选)                                              │
│    - 初始代码模板 (可选)                                          │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. CreateLuaScriptCommand                                         │
│    文件: lib/plugins/lua/command/create_lua_script_command.dart   │
│    参数:                                                          │
│    - name: String                                                │
│    - description: String?                                        │
│    - content: String (初始代码)                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. CommandBus → CreateLuaScriptHandler                            │
│    文件: lib/plugins/lua/handler/create_lua_script_handler.dart   │
│    流程:                                                          │
│    4.1 验证脚本名称                                               │
│    4.2 LuaScriptService.createScript()                           │
│    4.3 发布 ScriptCreatedEvent                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. LuaScriptService.createScript()                                │
│    文件: lib/plugins/lua/service/lua_script_service.dart         │
│    流程:                                                          │
│    5.1 生成脚本ID (UUID)                                          │
│    5.2 创建 LuaScript 对象                                       │
│    5.3 保存到文件 (data/lua_scripts/{scriptId}.lua)              │
│    5.4 更新内存索引                                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. LuaScriptBloc 更新 State → UI 显示新脚本                       │
└─────────────────────────────────────────────────────────────────┘
```

### LuaScript 数据模型

```dart
LuaScript {
  String id;              // 脚本唯一ID
  String name;            // 脚本名称
  String? description;    // 脚本描述
  String content;         // Lua代码内容
  bool enabled;           // 是否启用
  DateTime createdAt;     // 创建时间
  DateTime updatedAt;     // 更新时间
  Map<String, dynamic>? metadata; // 元数据
}
```

---

## UC-LUA-02: 执行Lua脚本

### 场景描述

用户执行已保存的Lua脚本。

### 调用链

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. 用户选择脚本并点击"执行"                                       │
│    位置: Lua脚本列表 → 执行按钮                                   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. ExecuteLuaScriptCommand (scriptId)                             │
│    文件: lib/plugins/lua/command/execute_lua_script_command.dart  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. CommandBus → ExecuteLuaScriptHandler                           │
│    文件: lib/plugins/lua/handler/execute_lua_script_handler.dart  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 4. LuaEngineService.execute(script)                               │
│    文件: lib/plugins/lua/service/lua_engine_service.dart         │
│    流程:                                                          │
│    4.1 加载脚本内容                                               │
│    4.2 应用沙箱限制 (Sandbox)                                     │
│    4.3 注入API对象到Lua环境                                       │
│    4.4 执行Lua代码                                                │
│    4.5 捕获执行结果和错误                                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 5. LuaExecutionResult                                             │
│    文件: lib/plugins/lua/models/lua_execution_result.dart        │
│    {                                                              │
│      success: bool,          // 是否成功                          │
│      output: String?,        // 标准输出                          │
│      error: String?,         // 错误信息                          │
│      duration: Duration,     // 执行耗时                          │
│    }                                                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 6. UI 显示执行结果                                                │
│    - 成功: 显示输出信息                                           │
│    - 失败: 显示错误和堆栈信息                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Lua执行流程详细图

```
LuaEngineService
    │
    ├── 1. 初始化Lua State
    │   └── lua_newstate()
    │
    ├── 2. 应用沙箱配置
    │   ├── LuaSandboxConfig.permissive() - 宽松模式
    │   ├── LuaSandboxConfig.restrictive() - 严格模式
    │   └── 限制:
    │       ├── 禁用文件IO (默认)
    │       ├── 禁用os.execute
    │       └── 限制可用模块
    │
    ├── 3. 注入API对象
    │   ├── app.node - 节点操作API
    │   ├── app.graph - 图操作API
    │   ├── app.ui - UI操作API
    │   ├── app.command - 命令API
    │   └── app.log - 日志API
    │
    ├── 4. 执行脚本
    │   └── luaL_dostring()
    │
    └── 5. 清理资源
        └── lua_close()
```

---

## UC-LUA-03: 编辑Lua脚本

### 场景描述

用户在编辑器中修改Lua脚本内容。

### 调用链

```
用户选择脚本 → 打开编辑器 → 修改代码 → 保存
    │
    ▼
UpdateLuaScriptCommand (scriptId, newContent)
    │
    ▼
CommandBus → UpdateLuaScriptHandler
    │
    ▼
LuaScriptService.updateScript()
    │
    ├── 验证脚本存在
    ├── 更新内容
    ├── 更新时间戳
    └── 保存到文件
    │
    ▼
ScriptUpdatedEvent → UI 更新
```

---

## UC-LUA-06: 脚本API调用

### 场景描述

Lua脚本通过内置API操作应用功能。

### Lua API 体系

```
LuaAPIImplementation
    │
    ├── app.node.* (节点操作API)
    │   ├── app.node.create(title, content, x, y)
    │   ├── app.node.get(nodeId)
    │   ├── app.node.update(nodeId, data)
    │   ├── app.node.delete(nodeId)
    │   ├── app.node.list()
    │   └── app.node.search(query)
    │
    ├── app.graph.* (图操作API)
    │   ├── app.graph.connect(sourceId, targetId)
    │   ├── app.graph.disconnect(sourceId, targetId)
    │   ├── app.graph.getNodes()
    │   └── app.graph.getConnections()
    │
    ├── app.command.* (命令API)
    │   ├── app.command.dispatch(commandName, args)
    │   └── app.command.query(queryName, args)
    │
    ├── app.ui.* (UI操作API)
    │   ├── app.log.info(message)
    │   ├── app.log.warn(message)
    │   ├── app.log.error(message)
    │   └── app.ui.showNotification(message)
    │
    └── app.hook.* (动态Hook API)
        ├── app.hook.register(hookPoint, callback)
        └── app.hook.unregister(hookId)
```

### API调用流程

```
Lua脚本执行
    │
    └── 调用: app.node.create("My Node", "Content", 100, 100)
    │
    ▼
LuaEngineService 拦截调用
    │
    ├── 验证API是否允许调用 (沙箱检查)
    ├── 解析参数
    └── 调用 LuaAPIImplementation
    │
    ▼
LuaAPIImplementation.createNode()
    │
    ├── 创建 CreateNodeCommand
    ├── 通过 CommandBus.dispatch() 执行
    └── 返回结果 (nodeId 或 error)
    │
    ▼
Lua脚本接收返回值
    └── nodeId = app.node.create(...)
```

### 示例Lua脚本

```lua
-- 批量创建节点
local nodes = {"Node A", "Node B", "Node C"}

for i, name in ipairs(nodes) do
  local nodeId = app.node.create(name, "Content for " .. name, i * 150, 100)
  app.log.info("Created node: " .. name .. " (ID: " .. nodeId .. ")")
end

-- 连接节点
local nodeIds = app.node.list()
for i = 1, #nodeIds - 1 do
  app.graph.connect(nodeIds[i], nodeIds[i + 1])
  app.log.info("Connected " .. nodeIds[i] .. " -> " .. nodeIds[i + 1])
end

app.ui.showNotification("Created " .. #nodes .. " nodes successfully!")
```

---

## UC-LUA-07: 动态Hook注册

### 场景描述

Lua脚本在运行时动态注册UI Hook，扩展应用界面。

### 调用链

```
Lua脚本执行 app.hook.register()
    │
    ▼
LuaDynamicHookManager.registerAPIs()
    │
    ├── app.hook.register(hookPointId, callback)
    │   └── hookPointId: 如 'main.toolbar'
    │   └── callback: Lua回调函数
    │
    ▼
LuaDynamicHookManager.createDynamicHook()
    │
    ├── 创建 LuaDynamicHook 对象
    │   ├── hookPointId: 目标Hook点
    │   ├── callback: Lua函数引用
    │   └── metadata: 动态生成的Hook元数据
    │
    ├── HookRegistry.registerHook(hook)
    │
    └── Hook.onInit() 调用
    │
    ▼
Hook渲染时执行Lua回调

当Hook点被渲染时:
    │
    ├── HookRegistry.getHookWrappers(hookPointId)
    ├── 找到 LuaDynamicHook
    │
    ▼
LuaDynamicHook.build(context)
    │
    ├── 调用Lua回调函数
    │   └── callback(context)
    │
    ├── Lua返回Widget配置
    │
    └── Flutter渲染Widget
```

### 示例: 动态工具栏按钮

```lua
-- 注册一个工具栏按钮
app.hook.register("main.toolbar", function(context)
  return {
    type = "button",
    label = "My Script",
    icon = "play_arrow",
    onPressed = function()
      app.log.info("Button pressed!")
      app.ui.showNotification("Hello from Lua!")
    end
  }
end)
```

---

## UC-LUA-08: 脚本间通信

### 场景描述

多个Lua脚本之间通过全局消息服务进行通信。

### 调用链

```
脚本A发送消息
    │
    ▼
GlobalMessageService.publish(channel, message)
    │
    ├── channel: 消息频道
    └── message: 消息内容 (任意Lua值)
    │
    ▼
GlobalMessageService 通知订阅者
    │
    ▼
脚本B接收消息
    │
    └── app.message.subscribe(channel, callback)
```

### 示例

```lua
-- 脚本A: 发布者
app.message.publish("node-created", { nodeId = "123", title = "New Node" })

-- 脚本B: 订阅者
app.message.subscribe("node-created", function(data)
  app.log.info("Node created: " .. data.title)
  -- 执行相应逻辑
end)
```

---

## Lua命令服务器

### 场景描述

外部进程或工具可以通过命令服务器向Lua系统发送命令。

### 架构

```
外部客户端 (CLI/其他应用)
    │
    ├── 发送命令 (JSON格式)
    │   └── { "command": "execute_script", "scriptId": "xxx" }
    │
    ▼
LuaCommandServer
    │
    ├── 解析命令
    ├── 查找对应命令处理器
    └── 执行LuaScriptService方法
    │
    ▼
返回结果 (JSON格式)
```

### 支持命令

```
- execute_script: 执行脚本
- create_script: 创建脚本
- update_script: 更新脚本
- delete_script: 删除脚本
- list_scripts: 列出所有脚本
- get_script: 获取脚本详情
```

---

## 安全沙箱

### LuaSandboxConfig

```dart
LuaSandboxConfig {
  enableFileIO: bool;      // 是否允许文件操作
  enableOS: bool;          // 是否允许OS调用
  enableNetwork: bool;     // 是否允许网络
  allowedModules: List<String>;  // 允许的模块
  maxExecutionTime: Duration;    // 最大执行时间
  maxMemoryUsage: int;           // 最大内存使用
}
```

### 沙箱策略

| 配置 | 宽松模式 (permissive) | 严格模式 (restrictive) |
|------|----------------------|------------------------|
| 文件IO | 允许 | 禁止 |
| OS调用 | 允许 | 禁止 |
| 网络 | 允许 | 禁止 |
| 模块 | 所有 | 仅基础模块 |
| 执行时间 | 无限制 | 30秒 |
| 内存 | 无限制 | 64MB |

---

## 时序图: Lua脚本执行

```
用户           LuaScriptBLoC   CommandBus    LuaScriptService    LuaEngineService    LuaAPI    Repository
 │                 │              │                │                   │                  │          │
 │──执行脚本──────▶│               │                │                   │                  │          │
 │                 │──Command─────▶│                │                   │                  │          │
 │                 │               │──dispatch()──▶│                   │                  │          │
 │                 │               │                │──execute()──────▶│                  │          │
 │                 │               │                │                   │                  │          │
 │                 │               │                │                   │──注入API────────▶│          │
 │                 │               │                │                   │                  │          │
 │                 │               │                │                   │──Lua执行─────────│          │
 │                 │               │                │                   │                  │          │
 │                 │               │                │                   │  ┌──app.node.create()
 │                 │               │                │                   │  │──▶│
 │                 │               │                │                   │  │   │──Command──▶│
 │                 │               │                │                   │  │   │            │──save()
 │                 │               │                │                   │  │   │◀───────────│
 │                 │               │                │                   │◀─│   │            │
 │                 │               │                │                   │  │◀─│            │
 │                 │               │                │                   │  │   │            │
 │                 │               │                │◀──结果────────────│  │   │            │
 │                 │               │◀──结果─────────│                   │                  │          │
 │                 │◀──State更新───│                │                   │                  │          │
 │◀──显示结果─────│                 │                │                   │                  │          │
```

---

## 扩展点

| 扩展点 | 说明 | 实现方式 |
|--------|------|----------|
| 新API | 添加新的Lua API | LuaAPIImplementation 添加方法 |
| 新沙箱配置 | 自定义沙箱策略 | LuaSandboxConfig |
| 新命令 | 添加命令服务器命令 | LuaCommandServer 注册 |
| 新Hook点 | Lua可注册的Hook点 | HookRegistry 注册 |
