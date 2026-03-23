import 'package:equatable/equatable.dart';
import '../../../plugins/lua/models/lua_script.dart';

/// Lua脚本事件基类
abstract class LuaScriptEvent extends Equatable {
  const LuaScriptEvent();

  @override
  List<Object?> get props => [];
}

/// 加载所有脚本
class LoadScriptsEvent extends LuaScriptEvent {
  const LoadScriptsEvent();
}

/// 保存脚本
class SaveScriptEvent extends LuaScriptEvent {
  const SaveScriptEvent({required this.script});

  final LuaScript script;

  @override
  List<Object?> get props => [script];
}

/// 删除脚本
class DeleteScriptEvent extends LuaScriptEvent {
  const DeleteScriptEvent({required this.scriptId});

  final String scriptId;

  @override
  List<Object?> get props => [scriptId];
}

/// 切换脚本启用状态
class ToggleScriptEvent extends LuaScriptEvent {
  const ToggleScriptEvent({
    required this.scriptId,
    required this.enabled,
  });

  final String scriptId;
  final bool enabled;

  @override
  List<Object?> get props => [scriptId, enabled];
}

/// 执行脚本
class ExecuteScriptEvent extends LuaScriptEvent {
  const ExecuteScriptEvent({required this.script});

  final LuaScript script;

  @override
  List<Object?> get props => [script];
}

/// 清空控制台输出
class ClearConsoleEvent extends LuaScriptEvent {
  const ClearConsoleEvent();
}

/// 选择当前脚本
class SelectScriptEvent extends LuaScriptEvent {
  const SelectScriptEvent({this.scriptId});

  final String? scriptId;

  @override
  List<Object?> get props => [scriptId];
}

/// 脚本执行完成（内部事件）
class ScriptExecutedEvent extends LuaScriptEvent {
  const ScriptExecutedEvent({
    required this.output,
    this.error,
  });

  final String output;
  final String? error;

  @override
  List<Object?> get props => [output, error];
}

/// 添加控制台输出
class AddConsoleOutputEvent extends LuaScriptEvent {
  const AddConsoleOutputEvent({required this.line});

  final String line;

  @override
  List<Object?> get props => [line];
}
