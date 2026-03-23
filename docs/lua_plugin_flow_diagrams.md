# Lua动态插件系统 - 可视化架构流程图

## 🎯 核心流程图

### 1. 动态按钮加载流程

```
┌─────────────────┐
│  用户执行命令    │
│  ./tool/lua.bat  │
│  "registerToolbar..."│
└────────┬─────────┘
         │
         ▼
┌─────────────────┐
│  创建Lua脚本文件 │
│  command_xxx.lua │
└────────┬─────────┘
         │
         ▼
┌─────────────────────────────┐
│  LuaCommandServer 监听        │
│  - 文件系统监听                │
│  - UTF-8解码                   │
│  - 读取脚本内容                │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  LuaEngineService 执行        │
│  - RealLuaEngine (Lua 5.2)   │
│  - 直接执行，避免转义问题       │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  LuaDynamicHookManager        │
│  - 拦截registerToolbarButton  │
│  - 创建_DynamicToolbarHook     │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  HookRegistry 注册           │
│  - 注册Hook到指定Hook点       │
│  - notifyListeners()         │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  Hook生命周期管理             │
│  uninitialized → initialized  │
│  onInit() → onEnable()       │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  UI自动更新                    │
│  HookRegistry.notifyListeners │
│       ↓                       │
│  AnimatedBuilder检测到变化     │
│       ↓                       │
│  CoreToolbar.build()          │
│       ↓                       │
│  重新渲染Hook列表              │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  用户看到新按钮                │
│  ✅ 紫色星星图标               │
│  ✅ "简单测试"文字              │
└─────────────────────────────┘
```

### 2. 按钮点击流程

```
┌─────────────────┐
│  用户点击按钮    │
└────────┬─────────┘
         │
         ▼
┌─────────────────────────────┐
│  _DynamicToolbarHook          │
│  _handleButtonPress()        │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  LuaEngineService            │
│  executeString('onSimpleTest()')│
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  Lua引擎执行全局函数          │
│  onSimpleTest()              │
│       ↓                       │
│  showMessage('测试', '...')    │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  LuaAPIImplementation         │
│  showMessage(title, message)  │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  GlobalMessageService        │
│  showMessage()               │
│       ↓                       │
│  ScaffoldMessenger.showSnackBar│
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  用户看到消息提示             │
│  ✅ SnackBar显示              │
│  ✅ "测试: 按钮工作正常！"      │
└─────────────────────────────┘
```

### 3. 动态卸载流程

```
┌─────────────────┐
│  用户执行命令    │
│  unregisterToolbarButton│
└────────┬─────────┘
         │
         ▼
┌─────────────────────────────┐
│  LuaDynamicHookManager        │
│  - 找到对应Hook               │
│  - 禁用Hook (onDisable)      │
│  - 从HookRegistry移除        │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  HookRegistry.notifyListeners │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  AnimatedBuilder检测变化       │
│  → CoreToolbar.build()       │
│  → Hook数量减少              │
└────────┬──────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  按钮立即消失                 │
│  ✅ UI实时更新                │
└─────────────────────────────┘
```

## 🔧 问题解决时间线

### 问题1: UTF-8编码错误
```
❌ 问题: FormatException: Missing extension byte
🔍 根源: 字符串转义破坏UTF-8编码
✅ 解决: 直接执行脚本，避免转义
📝 文件: real_lua_engine.dart
⏱️ 修复时间: ~30分钟
```

### 问题2: Hook未启用
```
❌ 问题: Is enabled: false
🔍 根源: Hook生命周期未手动管理
✅ 解决: 手动调用transitionTo启用Hook
📝 文件: lua_dynamic_hook_manager.dart
⏱️ 修复时间: ~45分钟
```

### 问题3: UI未更新
```
❌ 问题: Hook启用但UI不变
🔍 根源: HookRegistry不是ChangeNotifier
✅ 解决: 继承ChangeNotifier + AnimatedBuilder
📝 文件: hook_registry.dart, core_toolbar.dart
⏱️ 修复时间: ~40分钟
```

### 问题4: invokeCallback不存在
```
❌ 问题: 调用不存在的方法
🔍 根源: API名称错误
✅ 解决: 使用executeString调用全局函数
📝 文件: lua_dynamic_hook_manager.dart
⏱️ 修复时间: ~10分钟
```

### 问题5: showMessage参数不匹配
```
❌ 问题: 消息不显示
🔍 根源: 函数签名不匹配
✅ 解决: 支持1-2个参数 + 实际显示消息
📝 文件: lua_api_implementation.dart, global_message_service.dart
⏱️ 修复时间: ~20分钟
```

**总修复时间: ~2.5小时** ⏱️

## 🎓 经验总结

### 关键设计决策
1. **直接执行脚本** - 避免复杂的字符串处理
2. **ChangeNotifier模式** - 响应式UI更新
3. **生命周期管理** - 明确的状态转换
4. **沙箱隔离** - 安全的Lua环境

### 架构优势
- ✅ **高度解耦** - 各组件职责清晰
- ✅ **易于测试** - 可以独立测试各层
- ✅ **用户友好** - 简单的Lua API
- ✅ **生产就绪** - 完善的错误处理
