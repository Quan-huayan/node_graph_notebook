# Lua 动态工具栏按钮使用指南

## 概述

Lua 插件系统现在支持动态创建和卸载工具栏按钮。这意味着你可以通过 Lua 脚本在运行时向应用工具栏添加自定义按钮，并在不需要时移除它们。

## 功能特性

✅ **动态注册** - 在 Lua 脚本中运行时注册工具栏按钮
✅ **动态卸载** - 随时通过脚本卸载已注册的按钮
✅ **自定义图标** - 支持多种 Material Design 图标
✅ **回调函数** - 按钮点击时触发 Lua 回调函数
✅ **列表查询** - 查询所有已注册的动态按钮

## 可用 API

### 1. registerToolbarButton

注册一个新的工具栏按钮。

**语法：**
```lua
registerToolbarButton(buttonId, label, callbackName, iconName)
```

**参数：**
- `buttonId` (string) - 按钮的唯一标识符
- `label` (string) - 按钮的提示文本
- `callbackName` (string, 可选) - 点击时调用的 Lua 函数名
- `iconName` (string, 可选) - Material Design 图标名称

**返回值：**
- `1` - 注册成功
- `0` - 注册失败

**示例：**
```lua
onMyButtonClick = function()
    print("按钮被点击了！")
    showMessage("Hello from Lua!")
end

registerToolbarButton(
    "my_button",      -- 按钮ID
    "点击我",          -- 提示文本
    "onMyButtonClick", -- 回调函数
    "play_arrow"      -- 图标
)
```

### 2. unregisterToolbarButton

卸载一个已注册的工具栏按钮。

**语法：**
```lua
unregisterToolbarButton(buttonId)
```

**参数：**
- `buttonId` (string) - 要卸载的按钮ID

**返回值：**
- `1` - 卸载成功
- `0` - 卸载失败（按钮不存在）

**示例：**
```lua
local result = unregisterToolbarButton("my_button")
if result == 1 then
    print("按钮已卸载")
else
    print("卸载失败")
end
```

### 3. listDynamicButtons

列出所有已注册的动态按钮。

**语法：**
```lua
local buttons = listDynamicButtons()
```

**返回值：**
- 返回一个表格数组，每个元素包含：
  - `id` - 按钮ID
  - `label` - 按钮标签
  - `callback` - 回调函数名
  - `icon` - 图标名称

**示例：**
```lua
local buttons = listDynamicButtons()
for i, btn in pairs(buttons) do
    print(i .. ". " .. btn.label .. " (ID: " .. btn.id .. ")")
end
```

## 支持的图标

以下是支持的图标名称（部分）：

**常用操作：**
- `add` - 添加
- `remove` - 删除
- `edit` - 编辑
- `save` - 保存
- `refresh` - 刷新
- `search` - 搜索

**媒体控制：**
- `play_arrow` - 播放
- `pause` - 暂停
- `stop` - 停止

**导航：**
- `arrow_back` - 返回
- `arrow_forward` - 前进
- `home` - 主页
- `menu` - 菜单

**系统：**
- `settings` - 设置
- `info` - 信息
- `warning` - 警告
- `error` - 错误
- `help` - 帮助

**其他：**
- `favorite` - 收藏
- `star` - 星标
- `visibility` - 可见
- `lock` - 锁定
- `extension` - 插件图标（默认）

## 示例脚本

### 示例 1: 基础按钮

```lua
-- id: simple-button
-- name: 简单按钮示例
-- enabled: true

-- 定义回调函数
onSimpleClick = function()
    print("简单按钮被点击！")
    showMessage("Hello from Lua!")
end

-- 注册按钮
registerToolbarButton("simple_btn", "简单按钮", "onSimpleClick", "extension")
```

### 示例 2: 批量注册按钮

```lua
-- id: multiple-buttons
-- name: 多按钮示例
-- enabled: true

-- 按钮回调
onCreateClick = function()
    createNode("Lua节点", "内容", nil)
    showMessage("节点已创建")
end

onListClick = function()
    getAllNodes("onListComplete")
end

onListComplete = function(success, result)
    if success then
        showMessage("共有 " .. result.count .. " 个节点")
    end
end

-- 注册多个按钮
registerToolbarButton("create_btn", "创建", "onCreateClick", "add")
registerToolbarButton("list_btn", "列表", "onListClick", "list")

-- 列出所有按钮
local buttons = listDynamicButtons()
print("已注册 " .. #buttons .. " 个按钮")
```

### 示例 3: 动态卸载

```lua
-- id: cleanup-buttons
-- name: 清理按钮
-- enabled: true

-- 查看当前按钮
local buttons = listDynamicButtons()
print("当前有 " .. #buttons .. " 个动态按钮")

-- 卸载所有按钮
for i, btn in pairs(buttons) do
    print("正在卸载: " .. btn.label)
    unregisterToolbarButton(btn.id)
end

print("清理完成")
```

## 使用流程

### 1. 创建脚本

在 `data/scripts/` 目录下创建 Lua 脚本文件：

```lua
-- id: my-script
-- name: 我的脚本
-- enabled: true

onMyAction = function()
    -- 你的逻辑
end

registerToolbarButton("my_btn", "我的按钮", "onMyAction", "play_arrow")
```

### 2. 运行脚本

在应用的脚本管理器中：
1. 找到你的脚本
2. 点击"执行"按钮
3. 按钮将立即出现在工具栏

### 3. 卸载按钮

执行另一个脚本来卸载：

```lua
unregisterToolbarButton("my_btn")
```

或者重新加载应用，所有动态按钮会被清除。

## 工作原理

### 架构图

```
Lua 脚本
    ↓
registerToolbarButton()
    ↓
LuaDynamicHookManager
    ↓
HookRegistry.registerHook()
    ↓
DynamicToolbarHook (UIHookBase)
    ↓
主工具栏 (显示按钮)
```

### 生命周期

1. **注册阶段**
   - Lua 脚本调用 `registerToolbarButton()`
   - `LuaDynamicHookManager` 创建 `_DynamicToolbarHook`
   - Hook 注册到 `HookRegistry`
   - UI 自动更新，显示新按钮

2. **运行阶段**
   - 用户点击工具栏按钮
   - `_DynamicToolbarHook.renderToolbar()` 渲染按钮
   - 点击时触发 `_handleButtonPress()`
   - 调用 Lua 引擎的 `invokeCallback()`
   - 执行 Lua 回调函数

3. **卸载阶段**
   - Lua 脚本调用 `unregisterToolbarButton()`
   - Hook 从 `HookRegistry` 注销
   - UI 自动更新，按钮消失

## 注意事项

⚠️ **按钮ID唯一性**
- 每个按钮ID必须是唯一的
- 如果注册相同ID的按钮，旧的会被替换

⚠️ **回调函数**
- 回调函数必须是全局函数
- 确保回调函数在注册前已定义
- 回调函数不支持参数（使用闭包或全局变量）

⚠️ **生命周期**
- 动态按钮只在应用运行时存在
- 重启应用后所有动态按钮会被清除
- 如需持久化，在启动脚本中重新注册

⚠️ **性能考虑**
- 避免注册过多按钮（建议 < 10 个）
- 复杂的回调逻辑可能影响UI响应
- 使用 `showMessage()` 显示结果，不要用阻塞操作

## 调试技巧

### 查看已注册的按钮

```lua
local buttons = listDynamicButtons()
print("=== 动态按钮列表 ===")
for i, btn in pairs(buttons) do
    print(string.format("%d. %s (ID: %s)", i, btn.label, btn.id))
    print(string.format("   回调: %s", btn.callback or "无"))
    print(string.format("   图标: %s", btn.icon or "默认"))
end
```

### 测试按钮

```lua
-- 注册测试按钮
onTest = function()
    print("测试成功！")
    showMessage("测试按钮工作正常")
end

registerToolbarButton("test", "测试", "onTest", "check")
```

### 清理所有按钮

```lua
local buttons = listDynamicButtons()
for i, btn in pairs(buttons) do
    unregisterToolbarButton(btn.id)
    print("已卸载: " .. btn.label)
end
```

## 完整示例

查看以下完整示例脚本：
- `data/scripts/demo_dynamic_button.lua` - 基础示例
- `data/scripts/toolbar_button_manager.lua` - 多按钮管理
- `data/scripts/unregister_buttons.lua` - 卸载示例

## 高级用法

### 条件注册

```lua
-- 根据条件注册按钮
local shouldRegister = true  -- 你的条件逻辑

if shouldRegister then
    registerToolbarButton("conditional_btn", "条件按钮", "onConditionalClick", "star")
end
```

### 动态更新

```lua
-- 先卸载，再重新注册
unregisterToolbarButton("dynamic_btn")
registerToolbarButton("dynamic_btn", "新标签", "onNewCallback", "new_icon")
```

### 按钮组

```lua
-- 创建相关按钮组
local buttonGroup = {
    {id = "btn1", label = "按钮1", callback = "onBtn1", icon = "add"},
    {id = "btn2", label = "按钮2", callback = "onBtn2", icon = "edit"},
    {id = "btn3", label = "按钮3", callback = "onBtn3", icon = "delete"},
}

for i, btn in pairs(buttonGroup) do
    registerToolbarButton(btn.id, btn.label, btn.callback, btn.icon)
end
```

## 常见问题

**Q: 按钮没有显示？**
A: 检查：
1. 脚本是否成功执行
2. 查看控制台是否有错误
3. 使用 `listDynamicButtons()` 确认注册状态

**Q: 点击按钮没有反应？**
A: 检查：
1. 回调函数名是否正确
2. 回调函数是否已定义
3. 查看控制台错误信息

**Q: 如何更改按钮图标？**
A: 重新注册按钮：
```lua
unregisterToolbarButton("my_btn")
registerToolbarButton("my_btn", "标签", "回调", "新图标")
```

**Q: 按钮会持久化吗？**
A: 不会。应用重启后所有动态按钮会被清除。需要在启动脚本中重新注册。

## 总结

Lua 动态工具栏按钮功能为应用提供了强大的扩展能力：
- ✅ 运行时动态注册/卸载
- ✅ 自定义外观和行为
- ✅ 与应用功能深度集成
- ✅ 简单易用的 API

开始创建你的自定义工具栏按钮吧！
