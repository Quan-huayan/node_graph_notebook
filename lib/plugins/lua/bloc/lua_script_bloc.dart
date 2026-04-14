import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/cqrs/commands/command_bus.dart';
import '../command/create_lua_script_command.dart';
import '../command/delete_lua_script_command.dart';
import '../command/execute_lua_script_command.dart';
import '../command/toggle_lua_script_command.dart';
import '../service/lua_engine_service.dart';
import '../service/lua_script_service.dart';
import 'lua_script_event.dart';
import 'lua_script_state.dart';

/// Lua脚本管理BLoC
///
/// 负责管理Lua脚本的状态和UI逻辑
/// 遵循CQRS模式：写操作通过CommandBus，读操作通过Service
class LuaScriptBloc extends Bloc<LuaScriptEvent, LuaScriptState> {
  /// 构造函数
  LuaScriptBloc({
    required this.scriptService,
    required this.engineService,
    required this.commandBus,
  }) : super(LuaScriptState.initial) {
    // 初始化引擎
    _initializeEngine();

    // 注册事件处理器
    on<LoadScriptsEvent>(_onLoadScripts);
    on<SaveScriptEvent>(_onSaveScript);
    on<DeleteScriptEvent>(_onDeleteScript);
    on<ToggleScriptEvent>(_onToggleScript);
    on<ExecuteScriptEvent>(_onExecuteScript);
    on<ClearConsoleEvent>(_onClearConsole);
    on<SelectScriptEvent>(_onSelectScript);
    on<ScriptExecutedEvent>(_onScriptExecuted);
    on<AddConsoleOutputEvent>(_onAddConsoleOutput);

    // 添加初始事件
    add(const LoadScriptsEvent());
  }

  /// Lua脚本服务
  final LuaScriptService scriptService;

  /// Lua引擎服务
  final LuaEngineService engineService;

  /// Command Bus
  final CommandBus commandBus;

  /// 当前引擎实例
  LuaEngineService? _currentEngine;

  /// 初始化Lua引擎
  Future<void> _initializeEngine() async {
    try {
      if (!engineService.isInitialized) {
        await engineService.initialize();
        _currentEngine = engineService;
        debugPrint('[LUA BLOC] 引擎初始化成功');
      }
    } catch (e) {
      debugPrint('[LUA BLOC] 引擎初始化失败: $e');
    }
  }

  /// 加载所有脚本
  Future<void> _onLoadScripts(
    LoadScriptsEvent event,
    Emitter<LuaScriptState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final scripts = await scriptService.loadAllScripts();
      emit(state.copyWith(
        scripts: scripts,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: '加载脚本失败: $e',
      ));
    }
  }

  /// 保存脚本
  Future<void> _onSaveScript(
    SaveScriptEvent event,
    Emitter<LuaScriptState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      // ✅ 使用CommandBus执行写操作
      final result = await commandBus.dispatch(
        CreateLuaScriptCommand(script: event.script),
      );

      if (result.isSuccess) {
        // 重新加载脚本列表
        final scripts = await scriptService.loadAllScripts();
        emit(state.copyWith(
          scripts: scripts,
          isLoading: false,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          error: result.error ?? '保存脚本失败',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: '保存脚本失败: $e',
      ));
    }
  }

  /// 删除脚本
  Future<void> _onDeleteScript(
    DeleteScriptEvent event,
    Emitter<LuaScriptState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      // ✅ 使用CommandBus执行写操作
      final result = await commandBus.dispatch(
        DeleteLuaScriptCommand(scriptId: event.scriptId),
      );

      if (result.isSuccess) {
        // 重新加载脚本列表
        final scripts = await scriptService.loadAllScripts();
        emit(state.copyWith(
          scripts: scripts,
          isLoading: false,
          selectedScriptId: state.selectedScriptId == event.scriptId
              ? null
              : state.selectedScriptId,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          error: result.error ?? '删除脚本失败',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: '删除脚本失败: $e',
      ));
    }
  }

  /// 切换脚本启用状态
  Future<void> _onToggleScript(
    ToggleScriptEvent event,
    Emitter<LuaScriptState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      // ✅ 使用CommandBus执行写操作
      final result = await commandBus.dispatch(
        ToggleLuaScriptCommand(
          scriptId: event.scriptId,
          enabled: event.enabled,
        ),
      );

      if (result.isSuccess) {
        // 重新加载脚本列表
        final scripts = await scriptService.loadAllScripts();
        emit(state.copyWith(
          scripts: scripts,
          isLoading: false,
        ));
      } else {
        emit(state.copyWith(
          isLoading: false,
          error: result.error ?? '切换脚本状态失败',
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: '切换脚本状态失败: $e',
      ));
    }
  }

  /// 执行脚本
  Future<void> _onExecuteScript(
    ExecuteScriptEvent event,
    Emitter<LuaScriptState> emit,
  ) async {
    if (_currentEngine == null) {
      emit(state.copyWith(
        error: 'Lua引擎未初始化',
      ));
      return;
    }

    emit(state.copyWith(
      isExecuting: true,
      clearError: true,
      clearConsole: true,
    ));

    try {
      add(const AddConsoleOutputEvent(line: '--- 开始执行脚本 ---'));

      // ✅ 使用CommandBus执行脚本
      final result = await commandBus.dispatch(
        ExecuteLuaScriptCommand(
          scriptPath: '',  // 空路径表示执行字符串
          scriptContent: event.script.content,
        ),
      );

      // 添加输出
      if (result.data != null) {
        for (final line in result.data!.output) {
          add(AddConsoleOutputEvent(line: line));
        }
      }

      // 处理结果
      if (result.isSuccess) {
        add(const AddConsoleOutputEvent(line: '--- 脚本执行成功 ---'));
        add(ScriptExecutedEvent(
          output: result.data?.output.join('\n') ?? '',
        ));
      } else {
        add(AddConsoleOutputEvent(line: '错误: ${result.error ?? "未知错误"}'));
        add(const AddConsoleOutputEvent(line: '--- 脚本执行失败 ---'));
        add(ScriptExecutedEvent(
          output: result.data?.output.join('\n') ?? '',
          error: result.error,
        ));
      }

      emit(state.copyWith(isExecuting: false));
    } catch (e) {
      add(AddConsoleOutputEvent(line: '异常: $e'));
      emit(state.copyWith(
        isExecuting: false,
        error: '执行脚本失败: $e',
      ));
    }
  }

  /// 清空控制台
  void _onClearConsole(
    ClearConsoleEvent event,
    Emitter<LuaScriptState> emit,
  ) {
    emit(state.copyWith(clearConsole: true));
  }

  /// 选择脚本
  void _onSelectScript(
    SelectScriptEvent event,
    Emitter<LuaScriptState> emit,
  ) {
    emit(state.copyWith(selectedScriptId: event.scriptId));
  }

  /// 脚本执行完成
  void _onScriptExecuted(
    ScriptExecutedEvent event,
    Emitter<LuaScriptState> emit,
  ) {
    emit(state.copyWith(lastExecutionResult: event.output));
  }

  /// 添加控制台输出
  void _onAddConsoleOutput(
    AddConsoleOutputEvent event,
    Emitter<LuaScriptState> emit,
  ) {
    final newOutput = List<String>.from(state.consoleOutput)..add(event.line);
    emit(state.copyWith(consoleOutput: newOutput));
  }

  @override
  Future<void> close() async {
    await _currentEngine?.dispose();
    await super.close();
  }
}
