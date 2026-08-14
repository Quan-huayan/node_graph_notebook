/// node_lua —— Lua 动态 Concept 引擎插件（M7，01-E 承诺落地）。
///
/// Lua = 动态 Concept 引擎：data/lua_scripts/*.lua 脚本定义 Concept
/// （validate/createHook 用 Lua 实现——**Concept 接口薄度验证**）与
/// 命令处理（Commands 表）；宿主写 API（host.node_create/update/delete）
/// 经 LuaWriteCommand → Dart Handler 落盘（00 不变量 4.4-1 的 Lua 侧
/// 落地）。沙箱 + 坏脚本隔离 + owner 清理（plugon）。
///
/// 脚本约定见 lua_concept.dart 与 docs/COMMAND_LINE_GUIDE.md（M7 重写）。
library;

export 'lua_plugin.dart';
export 'src/lua_commands.dart';
export 'src/lua_concept.dart';
export 'src/lua_engine.dart';
export 'src/lua_handlers.dart';
export 'src/lua_script_loader.dart';
