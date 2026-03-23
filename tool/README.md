# Lua 动态按钮命令行测试工具

## 快速测试（推荐）

### Windows 用户

双击运行：
```
tool\run_test.bat
```

或在命令行中：
```cmd
cd D:\noteproject\node_graph_notebook
tool\run_test.bat
```

### Linux/macOS 用户

```bash
cd /path/to/node_graph_notebook
./tool/run_test.sh
```

或直接运行：
```bash
dart run tool/test_lua_dynamic_buttons.dart
```

---

## 手动测试

### 步骤 1: 安装依赖

```bash
flutter pub get
```

### 步骤 2: 运行测试

```bash
dart run tool/test_lua_dynamic_buttons.dart
```

---

## 预期输出

```
========================================
Lua 动态工具栏按钮测试工具
========================================

[1/4] 初始化 Lua 引擎...
✓ Lua 引擎初始化成功

[2/4] 初始化动态 Hook 管理器...
✓ 动态 Hook 管理器初始化成功

[3/4] 执行测试脚本...
--- 执行输出 ---
开始测试动态工具栏按钮...
正在注册按钮...
✓ 按钮注册成功！
  按钮ID: test_btn
  按钮标签: 测试按钮
  回调函数: onTestClick
  图标: star
测试完成
----------------

✓ 脚本执行成功

[4/4] 测试卸载功能...
--- 执行输出 ---
正在卸载按钮...
✓ 按钮卸载成功
----------------

✓ 卸载测试成功

清理资源...
✓ 资源已清理

========================================
测试总结
========================================
✓ Lua 引擎工作正常
✓ 动态 Hook 管理器工作正常
✓ 按钮注册 API 工作正常
✓ 按钮卸载 API 工作正常

所有功能测试通过！
========================================
```

---

## 测试说明

**这是什么？**
- 这是一个命令行测试工具
- 用于验证 Lua 动态按钮功能是否正常工作
- 不需要启动完整的 Flutter 应用

**它能测试什么？**
- ✅ Lua 引擎初始化
- ✅ 动态 Hook 管理器
- ✅ 按钮注册 API (registerToolbarButton)
- ✅ 按钮卸载 API (unregisterToolbarButton)

**它不能测试什么？**
- ❌ 实际的 GUI 按钮显示（因为是命令行）
- ❌ 按钮点击交互（需要 GUI）

---

## 故障排查

### 问题 1: Flutter 命令未找到

**错误：**
```
'flutter' 不是内部或外部命令
```

**解决方案：**
1. 安装 Flutter: https://flutter.dev/docs/get-started/install
2. 添加 Flutter 到系统 PATH

### 问题 2: 依赖安装失败

**错误：**
```
Could not resolve packages
```

**解决方案：**
```bash
flutter pub upgrade
flutter pub get
```

### 问题 3: Lua 引擎初始化失败

**错误：**
```
✗ Lua 引擎初始化失败
```

**解决方案：**
- 确认 `flutter_embed_lua` 包已安装
- 检查 `pubspec.yaml` 中的依赖

### 问题 4: 代码分析错误

**错误：**
```
error - xxx
```

**解决方案：**
- 检查代码是否有语法错误
- 运行 `flutter analyze` 查看详细错误

---

## 在应用中测试 GUI 效果

命令行测试通过后，你可以在应用中看到实际的按钮：

### 方法 1: 如果应用有 Lua 脚本管理器

1. 启动应用: `flutter run`
2. 找到 Lua 脚本管理界面
3. 执行 `data/scripts/demo_dynamic_button.lua`
4. 观察工具栏是否出现按钮

### 方法 2: 如果没有 Lua 脚本管理器

你需要先创建一个 Lua 脚本执行界面，或者使用现有的插件管理器。

---

## 相关文档

- 完整指南: `docs/lua_dynamic_buttons_guide.md`
- 快速开始: `docs/lua_dynamic_buttons_quickstart.md`
- 实现总结: `docs/lua_dynamic_buttons_implementation.md`
