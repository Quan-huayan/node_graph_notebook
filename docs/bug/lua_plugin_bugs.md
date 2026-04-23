# Lua 插件 Bug 报告

**审查日期**: 2026-04-20  
**审查范围**: `lib/plugins/lua` 文件夹  
**文件数量**: 22 个文件

---

## 严重 Bug (Critical)

### BUG-001: 静态变量导致多实例冲突

**文件**: [lua_engine.dart:40](file:///d:/Projects/node_graph_notebook/lib/plugins/lua/service/lua_engine.dart#L40)

**问题描述**:  
`_currentEngine` 是静态变量，在多实例场景下会导致回调函数调用错误的引擎实例。

**代码位置**:
```dart
static LuaEngine? _currentEngine;
```

**影响**:  
如果创建多个 `LuaEngine` 实例，它们会共享同一个 `_currentEngine`，导致回调函数（如 `_print`, `_log`, `_debug` 等）调用错误的引擎实例，产生不可预测的行为。

**建议修复**:  
使用实例变量或为每个引擎实例维护独立的回调上下文。

---

### BUG-002: 错误消息显示错误的变量名

**文件**: [lua_function_schema.dart:199](file:///d:/Projects/node_graph_notebook/lib/plugins/lua/service/lua_function_schema.dart#L199)

**问题描述**:  
在 `validateArguments` 方法中，错误消息使用了 `$name`（函数名）而不是 `param.name`（参数名）。

**代码位置**:
```dart
throw LuaFunctionValidationException(
  'Function "$name" parameter ${i + 1} ($name): $error',  // 应该是 param.name
);
```

**影响**:  
错误消息会显示函数名而不是参数名，导致用户无法准确定位问题参数。

**建议修复**:
```dart
throw LuaFunctionValidationException(
  'Function "$name" parameter ${i + 1} (${param.name}): $error',
);
```

---

### BUG-003: generateUUID 和 getCurrentTime 无法返回值

**文件**: [lua_api_implementation.dart:500-519](file:///d:/Projects/node_graph_notebook/lib/plugins/lua/service/lua_api_implementation.dart#L500-L519)

**问题描述**:  
`generateUUID` 和 `getCurrentTime` 函数执行了返回字符串的脚本，但没有将值返回给 Lua 调用者。

**代码位置**:
```dart
engineService.registerFunction('generateUUID', (args) {
  try {
    final id = _uuid.v4();
    engineService.executeString('return "$id"');  // 执行了但没返回
    return 0;  // 总是返回 0
  } catch (e) {
    return 0;
  }
})
```

**影响**:  
Lua 脚本调用 `generateUUID()` 或 `getCurrentTime()` 时无法获得返回值，总是得到 0。

**建议修复**:  
直接返回字符串值，或使用其他机制将值传递给 Lua。

---

## 高危 Bug (High)

### BUG-004: 回调函数类型不匹配

**文件**: [lua_api_implementation.dart:531](file:///d:/Projects/node_graph_notebook/lib/plugins/lua/service/lua_api_implementation.dart#L531)

**问题描述**:  
`_invokeCallback` 方法接收 `String? callbackName` 参数，但在调用处传递的是 `dynamic` 类型的 `args[2]`。

**代码位置**:
```dart
// 调用处 (第123行)
_invokeCallback(callback, [true, {...}]);  // callback 是 dynamic

// 方法定义 (第531行)
void _invokeCallback(String? callbackName, List<dynamic> args) async {
```

**影响**:  
如果 Lua 脚本传递非字符串类型的回调参数，会导致运行时类型错误。

**建议修复**:  
在调用 `_invokeCallback` 前进行类型检查和转换。

---

### BUG-005: Hook 注销无效

**文件**: [lua_dynamic_hook_manager.dart:191](file:///d:/Projects/node_graph_notebook/lib/plugins/lua/service/lua_dynamic_hook_manager.dart#L191)

**问题描述**:  
在 `_unregisterToolbarButton` 方法中，调用 `hooks.removeWhere(...)` 修改的是 `getHookWrappers` 返回的列表副本，不会影响实际的注册表。

**代码位置**:
```dart
final hooks = hookRegistry.getHookWrappers('main.toolbar', includeDisabled: true);
// ...
hooks.removeWhere((h) => h.hook.metadata.id == hookId);  // 修改副本，无效
```

**影响**:  
动态注册的工具栏按钮无法正确注销，导致资源泄漏和潜在的重复注册问题。

**建议修复**:  
使用 `hookRegistry.unregisterHook(hook)` 方法正确注销 Hook。

---

### BUG-006: BLoC 错误释放外部资源

**文件**: [lua_script_bloc.dart:293](file:///d:/Projects/node_graph_notebook/lib/plugins/lua/bloc/lua_script_bloc.dart#L293)

**问题描述**:  
在 `close` 方法中释放了通过依赖注入传入的 `engineService`，这违反了资源所有权原则。

**代码位置**:
```dart
@override
Future<void> close() async {
  await _currentEngine?.dispose();  // _currentEngine 指向 engineService
  await super.close();
}
```

**影响**:  
如果其他组件也在使用同一个 `engineService`，会导致资源被意外释放，引发后续操作失败。

**建议修复**:  
BLoC 不应该释放通过依赖注入获得的服务，应由服务容器或插件生命周期管理。

---

## 中危 Bug (Medium)

### BUG-007: _removeMetadata 逻辑错误

**文件**: [lua_script_service.dart:142-149](file:///d:/Projects/node_graph_notebook/lib/plugins/lua/service/lua_script_service.dart#L142-L149)

**问题描述**:  
`_removeMetadata` 方法中的条件逻辑可能导致脚本内容被错误截断。

**代码位置**:
```dart
final startIndex = lines.indexWhere((line) =>
    !line.startsWith('--') || line.trim().isEmpty);
```

**影响**:  
空行会被认为是非元数据行，可能导致元数据后的空行被当作脚本内容的一部分，或脚本开头的空行导致元数据解析不完整。

**建议修复**:  
改进逻辑，正确区分元数据注释和脚本内容。

---

### BUG-008: 文件名冲突风险

**文件**: [lua_script_service.dart:165](file:///d:/Projects/node_graph_notebook/lib/plugins/lua/service/lua_script_service.dart#L165)

**问题描述**:  
保存脚本时直接使用脚本名称作为文件名，可能导致文件名冲突或非法字符问题。

**代码位置**:
```dart
final fileName = '${script.name}.lua';
```

**影响**:  
- 两个同名脚本会互相覆盖
- 脚本名称包含非法字符（如 `/`, `\`, `:` 等）会导致文件操作失败

**建议修复**:  
使用脚本 ID 作为文件名，或在文件名中过滤非法字符。

---

### BUG-009: 冗余的类型转换

**文件**: [lua_engine.dart:395-398](file:///d:/Projects/node_graph_notebook/lib/plugins/lua/service/lua_engine.dart#L395-L398)

**问题描述**:  
`_outputBuffer` 已经是 `List<String>` 类型，不需要 `cast<String>()`。

**代码位置**:
```dart
final errorLine = _outputBuffer.cast<String>().firstWhere(
  (line) => line.startsWith('[CALLBACK_ERROR]'),
  orElse: () => '',
);
```

**影响**:  
代码冗余，轻微性能损失。

**建议修复**:
```dart
final errorLine = _outputBuffer.firstWhere(
  (line) => line.startsWith('[CALLBACK_ERROR]'),
  orElse: () => '',
);
```

---

### BUG-010: 异步操作未正确等待

**文件**: [lua_command_server.dart:229-251](file:///d:/Projects/node_graph_notebook/lib/plugins/lua/service/lua_command_server.dart#L229-L251)

**问题描述**:  
`FileSystemWatcher._checkFiles` 方法中调用异步操作但没有等待完成。

**代码位置**:
```dart
void _checkFiles() async {  // async 方法但没有返回 Future
  // ...
  final files = await dir.list().toList();  // await 但外层不等待
```

**影响**:  
在 Timer 回调中调用异步方法但不等待，可能导致异常未被正确捕获，文件状态不一致。

**建议修复**:  
正确处理异步操作，确保异常被捕获。

---

## 低危 Bug (Low)

### BUG-011: 冗余的字符串转义

**文件**: [lua_engine.dart:314-321](file:///d:/Projects/node_graph_notebook/lib/plugins/lua/service/lua_engine.dart#L314-L321)

**问题描述**:  
在 `_valueToLuaAssignment` 方法中，转义了双引号但最终用单引号包裹字符串。

**代码位置**:
```dart
final escaped = value
    .replaceAll('\\', '\\\\')
    .replaceAll('"', '\\"')   // 转义双引号
    .replaceAll("'", "\\'")   // 转义单引号
    ...
return "$name = '$escaped'";  // 用单引号包裹
```

**影响**:  
转义双引号是多余的，不会导致错误但增加不必要的处理。

**建议修复**:  
如果使用单引号包裹，可以移除双引号转义。

---

## 总结

| 严重程度 | 数量 |
|---------|------|
| Critical | 3 |
| High | 3 |
| Medium | 4 |
| Low | 1 |
| **总计** | **11** |

### 优先修复建议

1. **BUG-001**: 静态变量多实例冲突 - 影响核心功能
2. **BUG-002**: 错误消息变量名错误 - 影响用户体验
3. **BUG-003**: UUID/时间函数无法返回值 - 功能完全失效
4. **BUG-005**: Hook 注销无效 - 资源泄漏
5. **BUG-006**: BLoC 错误释放资源 - 潜在崩溃风险
