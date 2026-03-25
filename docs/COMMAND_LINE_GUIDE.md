# 🎯 通过命令行在 Flutter 应用中执行 Lua 脚本

## ✅ 现在可以了！

你可以在 Flutter 应用运行时，通过命令行直接发送 Lua 脚本执行命令。

---

## 🚀 快速开始

### 步骤 1: 启动 Flutter 应用

```bash
cd D:\noteproject\node_graph_notebook
flutter run
```

**应用启动后，会自动启动 Lua 命令服务器。**

你会在 Debug Console 中看到：
```
[LuaCommandServer] 启动服务器
[LuaCommandServer] 命令目录: C:\Users\...\AppData\Local\Temp\lua_commands
[LuaCommandServer]
[LuaCommandServer] 使用方法:
[LuaCommandServer]   echo "debugPrint('Hello')" > C:\Users\...\AppData\Local\Temp\lua_commands\command.lua
[LuaCommandServer]
```

### 步骤 2: 在另一个命令行窗口中执行 Lua 命令

**Windows 用户：**
```cmd
REM 方式 1: 使用 lua.bat 脚本（推荐）
tool\lua.bat "debugPrint('Hello from command line!')"

REM 方式 2: 直接使用 dart
dart run tool/send_lua_command.dart "debugPrint('Hello from command line!')"
```

**Linux/macOS 用户：**
```bash
# 方式 1: 使用 lua.sh 脚本（推荐）
./tool/lua.sh "debugPrint('Hello from command line!')"

# 方式 2: 直接使用 dart
dart run tool/send_lua_command.dart "debugPrint('Hello from command line!')"
```

### 步骤 3: 查看 Flutter 应用的 Debug Console

你应该看到：
```
[LuaCommandServer] ========================================
[LuaCommandServer] 检测到脚本: command_1234567890.lua
[LuaCommandServer] ========================================
[LuaCommandServer] 脚本内容:
[LuaCommandServer] ---
debugPrint('Hello from command line!')
[LuaCommandServer] ---
[LuaCommandServer]
[LuaCommandServer] 执行结果:
[LuaCommandServer] ---
[LuaCommandServer] Hello from command line!
[LuaCommandServer] ---
[LuaCommandServer] ✓ 执行成功
[LuaCommandServer] 已清理脚本文件
[LuaCommandServer] ========================================
```

---

## 📝 实际示例

### 示例 1: 注册工具栏按钮

```bash
# Windows
tool\lua.bat "
onTest = function()
    debugPrint('按钮被点击！')
    showMessage('命令行按钮工作正常！')
end
registerToolbarButton('cmd_btn', '命令行按钮', 'onTest', 'star')
"

# Linux/macOS
./tool/lua.sh "
onTest = function()
    debugPrint('按钮被点击！')
    showMessage('命令行按钮工作正常！')
end
registerToolbarButton('cmd_btn', '命令行按钮', 'onTest', 'star')
"
```

**执行后：**
- ✅ Flutter 应用工具栏立即出现紫色星标按钮
- ✅ 点击按钮会弹出消息

### 示例 2: 创建节点

```bash
tool\lua.bat "createNode('从命令行创建', '节点内容', nil)"
```

### 示例 3: 列出所有节点

```bash
tool\lua.bat "getAllNodes('onGetNodes')"

# 需要先定义回调
tool\lua.bat "
onGetNodes = function(success, result)
    if success then
        debugPrint('共有 ' .. result.count .. ' 个节点')
    end
end
getAllNodes('onGetNodes')
"
```

### 示例 4: 卸载按钮

```bash
tool\lua.bat "unregisterToolbarButton('cmd_btn')"
```

---

## 📁 从文件执行脚本

### 创建脚本文件

**test.lua:**
```lua
-- 批量注册按钮
onAdd = function()
    debugPrint("添加按钮")
end

onEdit = function()
    debugPrint("编辑按钮")
end

onDelete = function()
    debugPrint("删除按钮")
end

registerToolbarButton("add_btn", "添加", "onAdd", "add")
registerToolbarButton("edit_btn", "编辑", "onEdit", "edit")
registerToolbarButton("delete_btn", "删除", "onDelete", "delete")

debugPrint("✓ 所有按钮已注册")
```

### 执行脚本文件

```bash
# Windows
tool\lua.bat --file=test.lua

# Linux/macOS
./tool/lua.sh --file=test.lua
```

---

## 🔧 工作原理

```
命令行窗口                    Flutter 应用
     │                              │
     │  1. 执行 lua.bat "..."       │
     │                              │
     ├─────────────────────────────>│
     │                              │
     │     写入脚本到临时文件        │
     │                              │
     │                              │  2. 检测到新文件
     │                              │
     │                              │  3. 读取并执行
     │                              │
     │  4. 输出结果 <─────────────────┤
     │                              │
     │  查看 Debug Console          │
     │                              │
```

**特点：**
- ✅ 不需要网络
- ✅ 不需要 HTTP 服务器
- ✅ 基于文件系统监听
- ✅ 跨平台支持
- ✅ 实时响应

---

## 🎯 测试动态按钮功能

### 完整测试流程

```bash
# 1. 启动应用
flutter run

# 2. 等待应用完全启动，看到命令服务器启动消息

# 3. 在新命令行窗口中，注册按钮
tool\lua.bat "
onTestClick = function()
    debugPrint('命令行按钮被点击！')
    showMessage('从命令行创建的按钮工作正常！')
end
registerToolbarButton('test', '测试按钮', 'onTestClick', 'star')
"

# 4. 观察 Flutter 应用工具栏 - 应该出现紫色星标按钮

# 5. 点击按钮 - 应该弹出消息

# 6. 卸载按钮
tool\lua.bat "unregisterToolbarButton('test')"

# 7. 观察 Flutter 应用工具栏 - 按钮应该消失
```

---

## ⚙️ 高级用法

### 创建别名（可选）

**Windows (PowerShell):**
```powershell
# 添加到 $PROFILE
function lua { dart run tool/send_lua_command.dart $args }

# 使用
lua "debugPrint('Hello')"
```

**Linux/macOS (Bash):**
```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
alias lua='cd /path/to/node_graph_notebook && dart run tool/send_lua_command.dart'

# 使用
lua "debugPrint('Hello')"
```

### 批量测试脚本

**test_all.lua:**
```lua
debugPrint("开始批量测试...")

-- 测试 1: 注册单个按钮
registerToolbarButton("test1", "测试1", "onTest1", "add")

-- 测试 2: 注册多个按钮
registerToolbarButton("test2", "测试2", "onTest2", "edit")
registerToolbarButton("test3", "测试3", "onTest3", "delete")

-- 测试 3: 列出按钮
local count = listDynamicButtons()
debugPrint("当前有 " .. count .. " 个按钮")

-- 测试 4: 卸载按钮
unregisterToolbarButton("test1")
unregisterToolbarButton("test2")
unregisterToolbarButton("test3")

debugPrint("批量测试完成")
```

执行：
```bash
tool\lua.bat --file=test_all.lua
```

---

## 🐛 故障排查

### 问题 1: 应用启动后没有看到命令服务器消息

**可能原因：**
- Lua 插件未启用
- 插件加载失败

**解决方案：**
1. 检查 Debug Console 是否有错误
2. 确认 Lua 插件已加载
3. 查看完整日志：`flutter run -v`

### 问题 2: 命令执行后应用没有反应

**检查步骤：**
1. 确认应用正在运行
2. 查看命令目录是否正确创建
3. 检查临时文件权限

### 问题 3: 脚本执行出错

**查看错误信息：**
- Flutter 应用的 Debug Console 会显示详细错误
- 检查 Lua 语法是否正确
- 确认 API 调用是否正确

---

## ✅ 验证清单

使用这个清单确保功能正常：

```
□ 应用启动
  □ Flutter 应用成功启动
  □ 看到命令服务器启动消息
  □ 命令目录已创建

□ 命令执行
  □ 可以通过命令行发送 Lua 脚本
  □ 应用检测到脚本文件
  □ 脚本成功执行

□ 功能测试
  □ 注册按钮成功
  □ 工具栏出现按钮
  □ 点击按钮有响应
  □ 卸载按钮成功
```

---

## 📚 相关文档

- 完整指南: `docs/lua_dynamic_buttons_guide.md`
- 快速开始: `docs/lua_dynamic_buttons_quickstart.md`
- 命令行测试: `tool/README.md`

---

## 🎉 总结

现在你可以：
- ✅ 在 Flutter 应用运行时，通过命令行执行 Lua 脚本
- ✅ 实时注册和卸载工具栏按钮
- ✅ 测试所有 Lua 动态按钮功能
- ✅ 从文件执行复杂脚本

**不需要**：
- ❌ 创建额外的 UI 界面
- ❌ 重启应用
- ❌ 复杂的配置

只需要：
- ✅ 启动应用
- ✅ 运行命令
- ✅ 观察结果

简单、快速、高效！🚀
