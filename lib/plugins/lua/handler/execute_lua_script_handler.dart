import 'dart:io';
import '../../../core/commands/models/command.dart';
import '../../../core/commands/models/command_context.dart';
import '../../../core/commands/models/command_handler.dart';
import '../command/execute_lua_script_command.dart';
import '../models/lua_execution_result.dart';
import '../service/lua_engine_service.dart';
import '../service/lua_script_service.dart';

/// 执行Lua脚本命令处理器
///
/// 负责处理Lua脚本执行请求，是Command Bus模式中的Handler实现。
/// 协调LuaEngineService和LuaScriptService完成脚本执行。
///
/// ## 职责
/// - 验证Lua引擎初始化状态
/// - 检查脚本文件存在性和可读性
/// - 执行Lua脚本（文件或字符串）
/// - 返回格式化的执行结果
/// - 统一的错误处理和日志记录
///
/// ## 架构位置
/// ```
/// UI/BLoC
///   ↓
/// CommandBus.dispatch(ExecuteLuaScriptCommand)
///   ↓
/// ExecuteLuaScriptHandler (本类)
///   ↓
/// LuaEngineService / LuaScriptService
/// ```
///
/// ## 错误处理策略
/// - 引擎未初始化：返回失败结果
/// - 文件不存在：返回失败结果
/// - 文件不可读：返回失败结果
/// - 执行异常：捕获并返回失败结果
///
/// ## 示例
/// ```dart
/// final handler = ExecuteLuaScriptHandler(
///   engineService: engineService,
///   scriptService: scriptService,
/// );
///
/// final command = ExecuteLuaScriptCommand(
///   scriptPath: '/path/to/script.lua',
/// );
///
/// final result = await handler.execute(command, context);
/// if (result.isSuccess) {
///   print('脚本执行成功');
/// }
/// ```
class ExecuteLuaScriptHandler implements CommandHandler<ExecuteLuaScriptCommand> {
  /// 构造函数
  ///
  /// 创建Lua脚本执行处理器
  ///
  /// 参数：
  /// - [engineService]: Lua引擎服务，用于执行脚本
  /// - [scriptService]: Lua脚本管理服务，用于脚本元数据
  ///
  /// 示例：
  /// ```dart
  /// final handler = ExecuteLuaScriptHandler(
  ///   engineService: myEngineService,
  ///   scriptService: myScriptService,
  /// );
  /// ```
  ExecuteLuaScriptHandler({
    required this.engineService,
    required this.scriptService,
  });

  /// Lua引擎服务
  final LuaEngineService engineService;

  /// 脚本管理服务
  final LuaScriptService scriptService;

  /// 执行Lua脚本命令
  ///
  /// 根据命令类型执行Lua脚本文件或脚本字符串。
  ///
  /// ## 执行流程
  /// 1. 验证Lua引擎初始化状态
  /// 2. 判断执行类型（文件或字符串）
  /// 3. 执行前验证（文件存在性、可读性）
  /// 4. 调用LuaEngineService执行
  /// 5. 格式化并返回执行结果
  ///
  /// ## 参数
  /// - [command]: 执行命令，包含脚本路径或内容
  /// - [context]: 命令上下文（暂未使用）
  ///
  /// ## 返回值
  /// - 成功：CommandResult.success(LuaExecutionResult)
  /// - 失败：CommandResult.failure(error)
  ///
  /// ## 错误处理
  /// 所有错误都被捕获并转换为失败的CommandResult，
  /// 不会抛出异常，确保Command Bus稳定运行。
  ///
  /// ## 示例
  /// ```dart
  /// // 执行文件
  /// final command1 = ExecuteLuaScriptCommand(
  ///   scriptPath: '/path/to/script.lua',
  /// );
  /// final result1 = await handler.execute(command1, context);
  ///
  /// // 执行字符串
  /// final command2 = ExecuteLuaScriptCommand(
  ///   scriptPath: '',  // 空路径表示执行字符串
  ///   scriptContent: 'print("Hello")',
  /// );
  /// final result2 = await handler.execute(command2, context);
  /// ```
  @override
  Future<CommandResult<LuaExecutionResult>> execute(
    ExecuteLuaScriptCommand command,
    CommandContext context,
  ) async {
    try {
      // 检查引擎是否初始化
      if (!engineService.isInitialized) {
        return CommandResult.failureTyped<LuaExecutionResult>(
          'Lua引擎未初始化，请先初始化引擎',
        );
      }

      LuaExecutionResult result;

      // 判断是执行文件还是执行代码字符串
      if (command.scriptContent != null) {
        // 执行代码字符串
        result = await engineService.executeString(
          command.scriptContent!,
          context: command.context,
        );
      } else {
        // 执行文件
        final file = File(command.scriptPath);

        // 检查文件是否存在（使用同步方法避免警告）
        if (!file.existsSync()) {
          return CommandResult.failureTyped<LuaExecutionResult>(
            '脚本文件不存在: ${command.scriptPath}',
          );
        }

        // 检查文件是否可读
        try {
          file.readAsStringSync();
        } catch (e) {
          return CommandResult.failureTyped<LuaExecutionResult>(
            '无法读取脚本文件: $e',
          );
        }

        result = await engineService.executeFile(
          command.scriptPath,
          context: command.context,
        );
      }

      // 返回执行结果
      if (result.success) {
        return CommandResult.success(result);
      } else {
        return CommandResult.failureTyped<LuaExecutionResult>(
          result.error ?? '未知错误',
        );
      }
    } catch (e, stackTrace) {
      return CommandResult.failureTyped<LuaExecutionResult>(
        '执行Lua脚本失败: $e\n${stackTrace.toString()}',
      );
    }
  }
}
