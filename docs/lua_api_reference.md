# Lua API 参考手册

本文档提供Node Graph Notebook Lua插件的所有可用API的详细参考。

## 目录

- [节点操作](#节点操作)
- [消息显示](#消息显示)
- [搜索查询](#搜索查询)
- [工具函数](#工具函数)
- [日志记录](#日志记录)
- [事件处理](#事件处理)

---

## 节点操作

### createNode

创建一个新的节点。

**语法**:
```lua
createNode(title, content, parentId)
```

**参数**:
- `title` (string): 节点标题
- `content` (string, 可选): 节点内容
- `parentId` (string, 可选): 父节点ID

**返回值**: 无

**示例**:
```lua
-- 创建简单节点
createNode("我的节点", "节点内容")

-- 创建带父节点的节点
createNode("子节点", "子节点内容", "parent-id-123")
```

**注意事项**:
- 标题不能为空
- 节点会立即保存到Repository
- 节点ID自动生成
- 如果指定了parentId，父节点必须存在

---

### updateNode

更新现有节点的内容。

**语法**:
```lua
updateNode(id, title, content)
```

**参数**:
- `id` (string): 节点ID
- `title` (string, 可选): 新标题
- `content` (string, 可选): 新内容

**返回值**: 无

**示例**:
```lua
-- 更新节点标题
updateNode("node-id-123", "新标题")

-- 更新节点内容
updateNode("node-id-123", nil, "新内容")

-- 同时更新标题和内容
updateNode("node-id-123", "新标题", "新内容")
```

**注意事项**:
- 至少需要提供一个更新参数（title或content）
- 节点必须存在
- 更新会自动同步到文件系统

---

### deleteNode

删除指定节点。

**语法**:
```lua
deleteNode(id)
```

**参数**:
- `id` (string): 要删除的节点ID

**返回值**: 无

**示例**:
```lua
deleteNode("node-id-123")
```

**注意事项**:
- 删除操作不可撤销
- 如果节点有子节点，子节点也会被删除
- 删除不存在的节点不会报错

---

### getNode

获取指定节点的详细信息。

**语法**:
```lua
local node = getNode(id)
```

**参数**:
- `id` (string): 节点ID

**返回值**: 设置全局变量`_temp_node`，包含节点信息

**节点对象结构**:
```lua
{
  id = "node-id",
  title = "节点标题",
  content = "节点内容",
  parentId = "parent-id",  -- 可选
  createdAt = "2026-03-21T00:00:00.000Z",
  updatedAt = "2026-03-21T00:00:00.000Z"
}
```

**示例**:
```lua
getNode("node-id-123")

-- 访问返回的节点信息
if _temp_node then
    print("节点标题: " .. _temp_node.title)
    print("节点内容: " .. (_temp_node.content or "无"))
else
    print("节点不存在")
end
```

---

### getAllNodes

获取所有节点的列表。

**语法**:
```lua
getAllNodes()
```

**参数**: 无

**返回值**: 设置全局变量`_temp_nodes`，为节点数组

**示例**:
```lua
getAllNodes()

-- 访问返回的节点列表
if _temp_nodes then
    print("总节点数: " .. #_temp_nodes)

    for i, node in pairs(_temp_nodes) do
        print(string.format("%d. %s", i, node.title))
    end
end
```

**性能提示**:
- 对于大量节点，考虑使用搜索API
- 数据会一次性加载到内存

---

### getChildNodes

获取指定父节点的所有子节点。

**语法**:
```lua
getChildNodes(parentId)
```

**参数**:
- `parentId` (string): 父节点ID

**返回值**: 设置全局变量`_temp_children`，为子节点数组

**示例**:
```lua
getChildNodes("parent-id-123")

-- 访问返回的子节点列表
if _temp_children then
    print("子节点数: " .. #_temp_children)

    for i, child in pairs(_temp_children) do
        print(child.title)
    end
end
```

---

## 消息显示

### showMessage

向用户显示信息消息。

**语法**:
```lua
showMessage(message)
```

**参数**:
- `message` (string): 消息内容

**示例**:
```lua
showMessage("操作成功完成")
showMessage("共处理了 " .. count .. " 个节点")
```

**注意事项**:
- 当前实现：输出到控制台
- 未来计划：显示为SnackBar

---

### showWarning

向用户显示警告消息。

**语法**:
```lua
showWarning(message)
```

**参数**:
- `message` (string): 警告内容

**示例**:
```lua
showWarning("磁盘空间不足")
showWarning("发现 " .. count .. " 个重复节点")
```

**注意事项**:
- 当前实现：输出到控制台
- 未来计划：显示为警告对话框

---

### showError

向用户显示错误消息。

**语法**:
```lua
showError(message)
```

**参数**:
- `message` (string): 错误内容

**示例**:
```lua
showError("无法保存节点")
showError("找不到节点: " .. nodeId)
```

**注意事项**:
- 当前实现：输出到控制台
- 未来计划：显示为错误对话框

---

## 搜索查询

### searchNodes

根据查询条件搜索节点。

**语法**:
```lua
local results = searchNodes(query)
```

**参数**:
- `query` (string): 搜索关键词

**返回值**: 匹配的节点数组

**示例**:
```lua
-- 搜索标题包含关键词的节点
local results = searchNodes("Lua")

print("找到 " .. #results .. " 个匹配节点")
for i, node in pairs(results) do
    print(node.title)
end
```

**搜索范围**:
- 节点标题
- 节点内容
- 节点标签（如果支持）

**注意事项**:
- 此API尚未实现
- 可以使用getAllNodes()手动过滤

---

## 工具函数

### generateUUID

生成唯一的UUID字符串。

**语法**:
```lua
local id = generateUUID()
```

**返回值**: UUID字符串

**示例**:
```lua
local newId = generateUUID()
print("生成的ID: " .. newId)
-- 输出示例: 1712345678901_1234
```

**注意事项**:
- 使用时间戳+随机数生成
- 适合大多数场景
- 如需标准UUID，可自行实现

---

### getCurrentTime

获取当前时间的ISO 8601格式字符串。

**语法**:
```lua
local time = getCurrentTime()
```

**返回值**: 时间字符串

**示例**:
```lua
local time = getCurrentTime()
print("当前时间: " .. time)
-- 输出示例: 2026-03-21T12:34:56.789Z
```

---

## 日志记录

### print

输出消息到控制台。

**语法**:
```lua
print(message)
```

**参数**:
- `message` (string 或多个参数): 要输出的消息

**示例**:
```lua
print("Hello, Lua!")
print("值:", x, "类型:", type(x))
```

---

### log

记录日志消息。

**语法**:
```lua
log(message)
```

**参数**:
- `message` (string): 日志消息

**示例**:
```lua
log("脚本开始执行")
log("处理节点: " .. nodeId)
```

---

### debug

输出调试消息（仅在调试模式下显示）。

**语法**:
```lua
debug(message)
```

**参数**:
- `message` (string): 调试消息

**示例**:
```lua
debug("变量 x = " .. tostring(x))
debug("进入函数: processNode")
```

**注意事项**:
- 仅在enableDebugOutput=true时显示
- 生产环境不会输出

---

## 事件处理

### 注册事件处理函数

在脚本中定义全局函数来处理特定事件。

**语法**:
```lua
function onEventName(event)
    -- 事件处理逻辑
end
```

---

### onNodeDataChanged

节点数据变更事件。

**事件对象**:
```lua
{
    action = "create|update|delete",
    changedNodes = {
        {id = "...", title = "..."},
        ...
    }
}
```

**示例**:
```lua
function onNodeDataChanged(event)
    print("检测到节点数据变更")

    if event.action == "create" then
        print("创建了新节点")
        for i, node in pairs(event.changedNodes) do
            print("  " .. node.title)
        end
    end
end
```

**注意事项**:
- 此事件系统尚未实现
- 需要LuaEventBridge支持

---

### onGraphDataChanged

图数据变更事件。

**事件对象**:
```lua
{
    action = "create|update|delete",
    graphId = "graph-id"
}
```

**示例**:
```lua
function onGraphDataChanged(event)
    print("图数据已变更: " .. event.graphId)
    print("操作: " .. event.action)
end
```

**注意事项**:
- 此事件系统尚未实现
- 需要LuaEventBridge支持

---

### onAppStart

应用启动事件。

**示例**:
```lua
function onAppStart()
    print("应用已启动")
    -- 初始化逻辑
end
```

**注意事项**:
- 此事件系统尚未实现

---

### onAppExit

应用退出事件。

**示例**:
```lua
function onAppExit()
    print("应用即将退出")
    -- 清理逻辑
end
```

**注意事项**:
- 此事件系统尚未实现

---

## 数据类型

### Lua与Dart类型映射

| Lua类型 | Dart类型 | 说明 |
|---------|----------|------|
| nil | null | 空值 |
| boolean | bool | 布尔值 |
| number | double | 数字（浮点数） |
| string | String | 字符串 |
| table | dynamic | 表或对象 |
| function | Function | 函数 |

### 复杂对象

节点对象、事件对象等复杂类型在Lua中表现为表（table）。

**示例**:
```lua
-- 访问节点对象
getNode("node-id")

if _temp_node then
    print(_temp_node.id)        -- 访问字段
    print(_temp_node.title)     -- 访问字段
    print(_temp_node.content or "无内容")  -- 处理nil
end
```

---

## 错误处理

### pcall

使用pcall进行安全调用。

**语法**:
```lua
local success, error = pcall(function()
    -- 可能出错的代码
end)
```

**示例**:
```lua
local success, error = pcall(function()
    createNode("Test", "Content")
end)

if not success then
    print("错误: " .. error)
end
```

---

## 最佳实践

### 1. 使用局部变量

```lua
-- 好的做法
local function processNode(nodeId)
    getNode(nodeId)
    -- 处理节点
end

-- 避免使用全局变量
globalVar = "value"  -- 不推荐
```

### 2. 错误处理

```lua
local success, error = pcall(function()
    -- 危险操作
end)

if not success then
    showError("操作失败: " .. error)
end
```

### 3. 性能优化

```lua
-- 批量处理
getAllNodes()

if _temp_nodes then
    for i, node in pairs(_temp_nodes) do
        -- 批量操作而非单个API调用
    end
end

-- 避免在循环中频繁调用API
for i = 1, 100 do
    -- 好的做法：收集后批量处理
    -- 而不是每次循环都调用API
end
```

### 4. 日志记录

```lua
-- 合理使用日志级别
print("普通输出")           -- 用户可见
log("重要事件")            -- 记录日志
debug("调试信息")          -- 开发调试
```

---

## 常见问题

### Q: 如何遍历所有节点？

```lua
getAllNodes()

if _temp_nodes then
    for i, node in pairs(_temp_nodes) do
        print(node.title)
    end
end
```

### Q: 如何处理nil值？

```lua
local content = _temp_node.content or "默认内容"
local value = someValue or defaultValue
```

### Q: 如何拼接字符串？

```lua
local message = "Hello, " .. name .. "!"
-- 使用string.format格式化
local formatted = string.format("值: %d, 名称: %s", 42, "Test")
```

### Q: 如何检查函数是否存在？

```lua
if createNode then
    createNode("Test", "Content")
else
    print("createNode函数不可用")
end
```

---

## 示例脚本

### 脚本1: 批量重命名节点

```lua
getAllNodes()

if _temp_nodes then
    local count = 0

    for i, node in pairs(_temp_nodes) do
        if string.find(node.title, "旧名称") then
            local newTitle = string.gsub(node.title, "旧名称", "新名称")
            updateNode(node.id, newTitle, nil)
            count = count + 1
        end
    end

    showMessage("成功重命名 " .. count .. " 个节点")
end
```

### 脚本2: 统计节点信息

```lua
getAllNodes()

if _temp_nodes then
    local totalNodes = #_temp_nodes
    local nodesWithContent = 0

    for i, node in pairs(_temp_nodes) do
        if node.content and node.content ~= "" then
            nodesWithContent = nodesWithContent + 1
        end
    end

    print("统计信息:")
    print("总节点数: " .. totalNodes)
    print("有内容的节点: " .. nodesWithContent)
    print("空节点: " .. (totalNodes - nodesWithContent))
end
```

### 脚本3: 创建节点树

```lua
-- 创建根节点
createNode("项目根节点", "这是一个项目根节点")

-- 获取根节点ID（假设是最后一个创建的）
getAllNodes()
local rootId = _temp_nodes[#_temp_nodes].id

-- 创建子节点
createNode("子节点1", "子节点内容1", rootId)
createNode("子节点2", "子节点内容2", rootId)
createNode("子节点3", "子节点内容3", rootId)

showMessage("节点树创建完成")
```

---

## 更多资源

- [Lua 5.3 参考手册](https://www.lua.org/manual/5.3/)
- [Lua编程教程](https://www.lua.org/pil/contents.html)
- [示例脚本](../../data/lua_scripts/README.md)
- [架构文档](./lua_plugin_architecture.md)
