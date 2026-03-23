# Lua动态插件系统 - 快速参考指南

## 🚀 5秒上手

```bash
# 1. 启动应用
flutter run -d windows

# 2. 注册按钮
./tool/lua.bat "onTest = function() showMessage('测试', '成功！') end; registerToolbarButton('test', '测试', 'onTest', 'star')"

# 3. 卸载按钮
./tool/lua.bat "unregisterToolbarButton('test')"
```

## 📁 核心文件结构

```
lib/plugins/lua/
├── lua_plugin.dart                 # 插件主类
├── service/
│   ├── lua_engine_service.dart            # Lua引擎服务
│   ├── real_lua_engine.dart              # 真正Lua引擎 (Lua 5.2)
│   ├── lua_dynamic_hook_manager.dart     # 动态Hook管理器 ⭐
│   ├── lua_api_implementation.dart        # API实现
│   ├── global_message_service.dart       # 消息显示服务
│   └── lua_command_server.dart           # 命令服务器
└── models/
    ├── lua_execution_result.dart         # 执行结果模型
    └── lua_script.dart                   # Lua脚本模型
```

## 🔧 关键API

### Lua API (提供给Lua脚本)
```lua
-- 注册工具栏按钮
registerToolbarButton(id, label, callbackName, iconName)
  - id: 按钮唯一标识符
  - label: 按钮文本
  - callbackName: Lua全局函数名
  - iconName: 图标名称 (star, heart, bolt, etc.)

-- 注销工具栏按钮
unregisterToolbarButton(id)

-- 显示消息
showMessage(title, message)  -- 2个参数
showMessage(message)         -- 1个参数
```

### Dart API (内部使用)
```dart
// 注册Lua函数
engineService.registerFunction(name, (List<dynamic> args) {
  // 处理逻辑
  return returnValue;
});

// 执行Lua代码
final result = await engineService.executeString(luaCode);

// 调用Lua全局函数
final result = await engineService.executeString('functionName()');
```

## 🐛 调试技巧

### 1. 查看Debug Console输出
```
✅ 成功标志:
[LuaDynamicHookManager] Hook enabled successfully
[CoreToolbar] build() called
[_DynamicToolbarHook] Callback executed successfully

❌ 失败标志:
✗ 执行失败: FormatException
[Lua MESSAGE] Error: ...
```

### 2. 常见问题排查

**问题：按钮没有出现**
```bash
# 检查1: Hook是否启用
grep "Is enabled:" [debug输出]

# 检查2: UI是否重新构建
grep "CoreToolbar build()" [debug输出]

# 检查3: Hook是否渲染
grep "Rendering toolbar hook: lua.dynamic" [debug输出]
```

**问题：点击按钮没反应**
```bash
# 检查1: 回调是否执行
grep "Button clicked!" [debug输出]

# 检查2: Lua函数是否存在
./tool/lua.bat "print(type(onSimpleTest))"

# 检查3: API是否正确调用
grep "[LUA API] showMessage called" [debug输出]
```

## 📊 架构层次

```
┌─────────────────────────────────────┐
│  Lua脚本层                          │
│  - registerToolbarButton()          │
│  - onSimpleTest()                    │
│  - showMessage()                     │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Lua运行时层                        │
│  - RealLuaEngine (Lua 5.2 FFI)     │
│  - 全局函数注册                      │
│  - 执行Lua代码                       │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  API桥接层                          │
│  - LuaDynamicHookManager            │
│  - LuaAPIImplementation             │
│  - GlobalMessageService             │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Hook系统层                          │
│  - HookRegistry (ChangeNotifier)    │
│  - UIHookBase                        │
│  - Hook生命周期管理                  │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  UI层                               │
│  - CoreToolbar                      │
│  - AnimatedBuilder                   │
│  - ScaffoldMessenger                 │
└─────────────────────────────────────┘
```

## 🎯 最佳实践

### ✅ DO (推荐做法)
1. **使用有意义的按钮ID**
   ```lua
   registerToolbarButton('my_feature_btn', '我的功能', 'onMyFeatureClick', 'star')
   ```

2. **定义清晰的回调函数**
   ```lua
   onMyFeatureClick = function()
     showMessage('我的功能', '功能执行成功！')
     -- 添加更多逻辑
   end
   ```

3. **及时清理资源**
   ```lua
   -- 使用完毕后卸载
   unregisterToolbarButton('my_feature_btn')
   ```

4. **错误处理**
   ```lua
   onSafeFunction = function()
     local success, err = pcall(function()
       -- 可能出错的操作
       showMessage('提示', '操作完成')
     end)

     if not success then
       print("错误: " .. err)
     end
   end
   ```

### ❌ DON'T (避免做法)
1. **不要使用特殊字符作为ID**
   ```lua
   -- ❌ 错误
   registerToolbarButton('测试按钮', '测试', 'onClick', 'star')

   -- ✅ 正确
   registerToolbarButton('test_btn', '测试', 'onClick', 'star')
   ```

2. **不要忘记定义回调函数**
   ```lua
   -- ❌ 错误 (回调函数不存在)
   registerToolbarButton('test', '测试', 'undefinedFunction', 'star')

   -- ✅ 正确 (先定义后使用)
   onUndefinedFunction = function() print("ok") end
   registerToolbarButton('test', '测试', 'onUndefinedFunction', 'star')
   ```

3. **不要重复注册相同ID**
   ```lua
   -- ❌ 错误 (会覆盖之前的按钮)
   registerToolbarButton('same_id', '按钮1', 'onTest1', 'star')
   registerToolbarButton('same_id', '按钮2', 'onTest2', 'star')

   -- ✅ 正确 (先卸载后注册)
   unregisterToolbarButton('same_id')
   registerToolbarButton('same_id', '按钮2', 'onTest2', 'star')
   ```

## 🔧 高级用法

### 批量注册按钮
```lua
-- 定义多个回调
onAction1 = function() showMessage('操作1', '执行成功') end
onAction2 = function() showMessage('操作2', '执行成功') end
onAction3 = function() showMessage('操作3', '执行成功') end

-- 注册多个按钮
registerToolbarButton('action1', '操作1', 'onAction1', 'play_arrow')
registerToolbarButton('action2', '操作2', 'onAction2', 'pause')
registerToolbarButton('action3', '操作3', 'onAction3', 'stop')
```

### 动态回调
```lua
-- 根据状态动态执行不同操作
counter = 0

onCounter = function()
  counter = counter + 1
  showMessage('计数器', '点击次数: ' .. counter)

  if counter == 5 then
    showMessage('提示', '已达到5次，重置计数器')
    counter = 0
  end
end

registerToolbarButton('counter', '计数器', 'onCounter', 'timer')
```

### 条件显示
```lua
-- 检查并显示调试信息
onDebugInfo = function()
  showMessage('调试信息', 'Lua运行时正常工作')
end

-- 仅在开发环境注册
if _DEBUG then
  registerToolbarButton('debug', '调试', 'onDebugInfo', 'bug_report')
end
```

## 📚 相关文档

- `lua_plugin_architecture_explained.md` - 详细架构讲解
- `lua_plugin_flow_diagrams.md` - 可视化流程图
- `lua_api_reference.md` - 完整API参考
- `lua_dynamic_buttons_*.md` - 动态按钮使用指南

## 🎉 成功案例

你现在拥有的能力：
- ✅ 运行时添加UI组件
- ✅ 自动界面更新
- ✅ Lua脚本控制
- ✅ 消息提示反馈
- ✅ 完整生命周期管理

这是一个**生产级的动态插件系统**！🏆
