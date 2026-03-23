# Lua 动态工具栏按钮 - 快速开始

## 30秒快速演示

### 步骤 1: 运行示例脚本

在应用的脚本管理器中，找到并执行 `demo_dynamic_button.lua` 脚本。

### 步骤 2: 查看结果

- ✅ 工具栏会立即出现一个新的紫色按钮（播放图标）
- ✅ 点击按钮会显示消息并执行 Lua 代码
- ✅ 按钮提示文本为"点击我"

### 步骤 3: 卸载按钮

执行 `unregister_buttons.lua` 脚本，按钮会立即消失。

## 核心API

### 注册按钮

```lua
registerToolbarButton(buttonId, label, callbackName, iconName)
```

**示例：**
```lua
onMyClick = function()
    print("被点击了！")
end

registerToolbarButton("my_btn", "我的按钮", "onMyClick", "add")
```

### 卸载按钮

```lua
unregisterToolbarButton(buttonId)
```

**示例：**
```lua
unregisterToolbarButton("my_btn")
```

## 完整示例

### 示例 1: 创建节点按钮

```lua
-- id: create-node-button
-- enabled: true

onCreateNode = function()
    createNode("从Lua创建", "内容", nil)
    showMessage("节点已创建！")
end

registerToolbarButton("create_node", "创建节点", "onCreateNode", "add")
```

### 示例 2: 多个按钮

```lua
-- id: multiple-buttons
-- enabled: true

-- 按钮回调
onAdd = function()
    print("添加按钮")
end

onEdit = function()
    print("编辑按钮")
end

onDelete = function()
    print("删除按钮")
end

-- 注册多个按钮
registerToolbarButton("btn_add", "添加", "onAdd", "add")
registerToolbarButton("btn_edit", "编辑", "onEdit", "edit")
registerToolbarButton("btn_delete", "删除", "onDelete", "delete")
```

### 示例 3: 带清理的脚本

```lua
-- id: self-cleaning-button
-- enabled: true

-- 脚本卸载时自动清理按钮
onScriptUnload = function()
    unregisterToolbarButton("temp_btn")
    print("按钮已清理")
end

onButtonClick = function()
    showMessage("临时按钮")
end

registerToolbarButton("temp_btn", "临时", "onButtonClick", "star")
```

## 常用图标

| 图标名 | 说明 | 图标名 | 说明 |
|--------|------|--------|------|
| `add` | 添加 | `delete` | 删除 |
| `edit` | 编辑 | `save` | 保存 |
| `search` | 搜索 | `refresh` | 刷新 |
| `play_arrow` | 播放 | `pause` | 暂停 |
| `stop` | 停止 | `settings` | 设置 |
| `favorite` | 收藏 | `star` | 星标 |
| `visibility` | 可见 | `lock` | 锁定 |
| `home` | 主页 | `menu` | 菜单 |
| `info` | 信息 | `help` | 帮助 |
| `warning` | 警告 | `error` | 错误 |

完整图标列表请参考：`docs/lua_dynamic_buttons_guide.md`

## 工作流程

```
1. 编写 Lua 脚本
   ↓
2. 定义回调函数
   ↓
3. 调用 registerToolbarButton()
   ↓
4. 执行脚本
   ↓
5. 按钮出现在工具栏
   ↓
6. 用户点击按钮
   ↓
7. 回调函数执行
```

## 注意事项

⚠️ **按钮ID唯一性**
- 每个按钮ID必须是唯一的
- 重复注册会替换旧按钮

⚠️ **回调函数**
- 必须在注册前定义
- 必须是全局函数
- 不支持参数（使用全局变量）

⚠️ **生命周期**
- 按钮只在运行时存在
- 应用重启后消失
- 需要重新注册

⚠️ **调试**
- 查看控制台输出
- 使用 `print()` 调试
- 使用 `showMessage()` 显示结果

## 进阶用法

### 条件注册

```lua
if someCondition then
    registerToolbarButton("conditional", "条件按钮", "onCallback", "check")
end
```

### 动态更新

```lua
-- 更新按钮
unregisterToolbarButton("my_btn")
registerToolbarButton("my_btn", "新标签", "新回调", "新图标")
```

### 批量管理

```lua
-- 批量卸载
local buttons = {"btn1", "btn2", "btn3"}
for i, id in pairs(buttons) do
    unregisterToolbarButton(id)
end
```

## 故障排查

**问题：按钮没有显示**
- 检查脚本是否成功执行
- 查看控制台错误信息
- 确认按钮ID唯一

**问题：点击无反应**
- 检查回调函数名拼写
- 确认回调函数已定义
- 查看控制台错误信息

**问题：图标不显示**
- 检查图标名称拼写
- 查看支持的图标列表
- 使用默认图标 `extension`

## 示例脚本位置

- `data/scripts/demo_dynamic_button.lua` - 基础示例
- `data/scripts/toolbar_button_manager.lua` - 多按钮管理
- `data/scripts/unregister_buttons.lua` - 卸载示例

## 相关文档

- [完整功能指南](./lua_dynamic_buttons_guide.md)
- [Lua API 参考](./lua_api_reference.md)
- [Lua 插件架构](./lua_plugin_architecture.md)

## 总结

Lua 动态工具栏按钮功能让你可以：

✅ 运行时动态添加UI元素
✅ 自定义按钮外观和行为
✅ 与应用功能深度集成
✅ 简单易用的API

开始创建你的自定义按钮吧！🚀
