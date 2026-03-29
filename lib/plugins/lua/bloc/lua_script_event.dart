import 'package:equatable/equatable.dart';
import '../../../plugins/lua/models/lua_script.dart';

/// Lua脚本事件基类
abstract class LuaScriptEvent extends Equatable {
  /// 创建Lua脚本事件
  const LuaScriptEvent();

  @override
  List<Object?> get props => [];
}

/// 加载所有脚本
class LoadScriptsEvent extends LuaScriptEvent {
  /// 创建加载脚本事件
  const LoadScriptsEvent();
}

/// 保存脚本
class SaveScriptEvent extends LuaScriptEvent {
  /// 创建保存脚本事件
  const SaveScriptEvent({required this.script});

  /// 要保存的脚本
  final LuaScript script;

  @override
  List<Object?> get props => [script];
}

/// 删除脚本
class DeleteScriptEvent extends LuaScriptEvent {
  /// 创建删除脚本事件
  const DeleteScriptEvent({required this.scriptId});

  /// 要删除的脚本ID
  final String scriptId;

  @override
  List<Object?> get props => [scriptId];
}

/// 切换脚本启用状态
class ToggleScriptEvent extends LuaScriptEvent {
  /// 创建切换脚本状态事件
  const ToggleScriptEvent({
    required this.scriptId,
    required this.enabled,
  });

  /// 脚本ID
  final String scriptId;

  /// 是否启用
  final bool enabled;

  @override
  List<Object?> get props => [scriptId, enabled];
}

/// 执行脚本
class ExecuteScriptEvent extends LuaScriptEvent {
  /// 创建执行脚本事件
  const ExecuteScriptEvent({required this.script});

  /// 要执行的脚本
  final LuaScript script;

  @override
  List<Object?> get props => [script];
}

/// 清空控制台输出
class ClearConsoleEvent extends LuaScriptEvent {
  /// 创建清空控制台事件
  const ClearConsoleEvent();
}

/// 选择当前脚本
class SelectScriptEvent extends LuaScriptEvent {
  /// 创建选择脚本事件
  const SelectScriptEvent({this.scriptId});

  /// 选中的脚本ID
  final String? scriptId;

  @override
  List<Object?> get props => [scriptId];
}

/// 脚本执行完成（内部事件）
class ScriptExecutedEvent extends LuaScriptEvent {
  /// 创建脚本执行完成事件
  const ScriptExecutedEvent({
    required this.output,
    this.error,
  });

  /// 输出内容
  final String output;

  /// 错误信息
  final String? error;

  @override
  List<Object?> get props => [output, error];
}

/// 添加控制台输出
class AddConsoleOutputEvent extends LuaScriptEvent {
  /// 创建添加控制台输出事件
  const AddConsoleOutputEvent({required this.line});

  /// 输出行内容
  final String line;

  @override
  List<Object?> get props => [line];
}
