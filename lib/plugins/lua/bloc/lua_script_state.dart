import 'package:equatable/equatable.dart';
import '../models/lua_script.dart';

/// Lua脚本状态
class LuaScriptState extends Equatable {
  /// 创建Lua脚本状态
  const LuaScriptState({
    this.scripts = const [],
    this.selectedScriptId,
    this.consoleOutput = const [],
    this.isLoading = false,
    this.isExecuting = false,
    this.error,
    this.lastExecutionResult,
  });

  /// 所有脚本列表
  final List<LuaScript> scripts;

  /// 当前选中的脚本ID
  final String? selectedScriptId;

  /// 控制台输出行
  final List<String> consoleOutput;

  /// 是否正在加载
  final bool isLoading;

  /// 是否正在执行脚本
  final bool isExecuting;

  /// 错误信息
  final String? error;

  /// 最后执行的结果
  final String? lastExecutionResult;

  /// 初始状态
  static const initial = LuaScriptState();

  /// 获取当前选中的脚本
  LuaScript? get selectedScript {
    if (selectedScriptId == null) return null;
    try {
      return scripts.firstWhere((script) => script.id == selectedScriptId);
    } catch (e) {
      return null;
    }
  }

  /// 获取已启用的脚本
  List<LuaScript> get enabledScripts =>
      scripts.where((script) => script.enabled).toList();

  /// 复制并更新状态
  LuaScriptState copyWith({
    List<LuaScript>? scripts,
    String? selectedScriptId,
    List<String>? consoleOutput,
    bool? isLoading,
    bool? isExecuting,
    String? error,
    String? lastExecutionResult,
    bool clearSelectedScript = false,
    bool clearConsole = false,
    bool clearError = false,
  }) => LuaScriptState(
      scripts: scripts ?? this.scripts,
      selectedScriptId: clearSelectedScript ? null : (selectedScriptId ?? this.selectedScriptId),
      consoleOutput: clearConsole ? [] : (consoleOutput ?? this.consoleOutput),
      isLoading: isLoading ?? this.isLoading,
      isExecuting: isExecuting ?? this.isExecuting,
      error: clearError ? null : (error ?? this.error),
      lastExecutionResult: lastExecutionResult ?? this.lastExecutionResult,
    );

  @override
  List<Object?> get props => [
        scripts,
        selectedScriptId,
        consoleOutput,
        isLoading,
        isExecuting,
        error,
        lastExecutionResult,
      ];
}
