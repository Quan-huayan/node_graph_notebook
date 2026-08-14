# Lua脚本示例

本目录包含Lua插件系统的示例脚本。

## 示例脚本列表

### 1. hello_world.lua
**类型**: 基础示例
**描述**: 简单的Hello World示例，演示Lua脚本的基本语法和使用方法。

**功能**:
- 变量定义和使用
- 函数定义和调用
- 循环和条件语句
- 输出日志

**适用场景**: 学习Lua语法，测试脚本系统

---

### 2. node_organizer.lua
**类型**: API调用示例
**描述**: 节点整理器，演示如何使用Lua API操作节点。

**功能**:
- 获取所有节点
- 统计节点信息
- 生成整理报告
- 演示API调用

**适用场景**: 学习如何使用Flutter API，自动化节点管理

---

### 3. event_handler.lua
**类型**: 事件响应示例
**描述**: 事件处理器，演示如何监听和响应应用事件。

**功能**:
- 监听节点数据变更事件
- 监听图数据变更事件
- 自定义事件处理逻辑
- 事件日志记录

**适用场景**: 学习事件系统，实现自动化响应

---

## 脚本格式规范

所有脚本文件应遵循以下格式：

```lua
-- id: unique-script-id
-- name: Script Display Name
-- description: Brief description of what the script does
-- author: Your Name
-- version: 1.0.0
-- enabled: true
-- createdAt: 2026-03-21T00:00:00.000Z
-- updatedAt: 2026-03-21T00:00:00.000Z

-- 脚本内容从这里开始
debugPrint("Hello, World!")
```

### 必需字段

- `id`: 唯一标识符（英文，连字符分隔）
- `name`: 显示名称
- `enabled`: 是否启用（true/false）

### 可选字段

- `description`: 描述信息
- `author`: 作者名称
- `version`: 版本号
- `createdAt`: 创建时间（ISO 8601格式）
- `updatedAt`: 更新时间（ISO 8601格式）

---

## 可用的Lua API

### 节点操作

- `createNode(title, content)` - 创建新节点
- `updateNode(id, title, content)` - 更新节点
- `deleteNode(id)` - 删除节点
- `getNode(id)` - 获取指定节点
- `getAllNodes()` - 获取所有节点
- `getChildNodes(parentId)` - 获取子节点

### 消息显示

- `showMessage(message)` - 显示信息消息
- `showWarning(message)` - 显示警告消息
- `showError(message)` - 显示错误消息

### 日志记录

- `debugPrint(message)` - 输出到控制台
- `log(message)` - 记录日志
- `debug(message)` - 调试输出（仅在调试模式下）

### 搜索

- `searchNodes(query)` - 搜索节点

### 工具函数

- `generateUUID()` - 生成唯一ID
- `getCurrentTime()` - 获取当前时间

---

## 事件处理

### 注册事件处理函数

在脚本中定义事件处理函数：

```lua
function onNodeDataChanged(event)
    debugPrint("节点数据已变更")
    -- 处理事件逻辑
end
```

### 可用事件

- `onNodeDataChanged(event)` - 节点数据变更
- `onGraphDataChanged(event)` - 图数据变更
- `onNodeClick(nodeId)` - 节点点击
- `onAppStart()` - 应用启动
- `onAppExit()` - 应用退出

### 事件对象

事件对象包含以下字段：

```lua
{
    action = "create/update/delete",
    changedNodes = {...},
    graphId = "graph-id",
    timestamp = "2026-03-21T00:00:00.000Z"
}
```

---

## 最佳实践

### 1. 错误处理

使用`pcall`捕获错误：

```lua
local success, error = pcall(function()
    -- 可能出错的代码
    createNode("Test", "Content")
end)

if not success then
    debugPrint("错误: " .. error)
end
```

### 2. 日志记录

合理使用日志级别：

```lua
debugPrint("普通信息")
log("重要日志")
debug("调试信息")  -- 仅在调试模式下显示
```

### 3. 性能优化

- 避免在循环中频繁调用API
- 批量处理数据
- 使用局部变量

```lua
local nodes = getAllNodes()
for i, node in pairs(nodes) do
    -- 处理节点
end
```

### 4. 脚本组织

- 使用模块化设计
- 避免全局变量污染
- 添加必要的注释

```lua
-- 局部函数
local function helperFunction()
    -- 辅助逻辑
end

-- 主逻辑
function main()
    helperFunction()
end

main()
```

---

## 调试技巧

### 1. 使用print调试

```lua
debugPrint("调试点1")
debugPrint("变量值: " .. tostring(variable))
```

### 2. 查看表内容

```lua
function printTable(t)
    for k, v in pairs(t) do
        debugPrint(k .. " = " .. tostring(v))
    end
end

printTable(event)
```

### 3. 检查函数是否存在

```lua
if createNode then
    createNode("Test", "Content")
else
    debugPrint("createNode 函数不可用")
end
```

---

## 常见问题

### Q: 如何获取节点详情？
A: 使用`getNode(id)`函数获取指定节点的详细信息。

### Q: 如何批量处理节点？
A: 使用`getAllNodes()`获取所有节点，然后遍历处理。

### Q: 事件处理函数不执行？
A: 确保脚本已启用，且事件处理函数名称正确。

### Q: API调用失败？
A: 检查API是否可用，参数是否正确，使用`pcall`捕获错误。

---

## 更多资源

- [Lua官方文档](https://www.lua.org/manual/)
- [Lua 5.3 参考手册](https://www.lua.org/manual/5.3/)
- [Node Graph Notebook文档](../../docs/)

---

**注意**: 本插件采用完全开放模式，请谨慎执行来源不明的脚本。
