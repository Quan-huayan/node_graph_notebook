import '../models/lua_execution_result.dart';

/// 简单脚本引擎
///
/// 一个轻量级的类Lua脚本解释器，用于演示和基本功能
/// 支持基本的语法：变量、函数、print、条件语句、循环
class SimpleScriptEngine {
  /// 构造函数
  SimpleScriptEngine({
    this.enableDebugOutput = false,
  });

  /// 是否启用调试输出
  final bool enableDebugOutput;

  /// 变量存储
  final Map<String, dynamic> _variables = {};

  /// 函数存储
  final Map<String, _FunctionDefinition> _functions = {};

  /// 当前正在跳过的行数（用于跳过函数体）
  int _skipLines = 0;

  /// 输出回调
  void Function(String)? _outputCallback;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 初始化引擎
  Future<void> initialize() async {
    if (_isInitialized) {
      throw StateError('引擎已经初始化');
    }
    _isInitialized = true;
    if (enableDebugOutput) {
      _outputCallback?.call('简单脚本引擎初始化成功');
    }
  }

  /// 执行脚本字符串
  Future<LuaExecutionResult> executeString(
    String script, {
    Map<String, dynamic>? context,
  }) async {
    if (!_isInitialized) {
      throw StateError('引擎未初始化');
    }

    final startTime = DateTime.now();
    final outputs = <String>[];

    try {
      // 设置输出回调
      _outputCallback = (String message) => outputs.add(message);

      // 设置上下文变量
      if (context != null) {
        _variables.addAll(context);
      }

      // 解析并执行脚本
      final lines = script.split('\n');
      for (var i = 0; i < lines.length; i++) {
        // 检查是否需要跳过当前行
        if (_skipLines > 0) {
          _skipLines--;
          continue;
        }

        final line = lines[i].trim();
        if (line.isEmpty || line.startsWith('--')) continue; // 跳过注释和空行

        await _executeLine(line, lines, i);
      }

      return LuaExecutionResult.success(
        output: outputs,
        executionTime: DateTime.now().difference(startTime),
      );
    } on _ReturnException catch (e) {
      // return语句不应该出现在顶层代码中
      return LuaExecutionResult.failure(
        error: 'return语句出现在函数外部',
        output: outputs,
        executionTime: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return LuaExecutionResult.failure(
        error: e.toString(),
        output: outputs,
        executionTime: DateTime.now().difference(startTime),
      );
    } finally {
      _outputCallback = null;
    }
  }

  /// 执行单行脚本
  Future<void> _executeLine(
    String line,
    List<String> allLines,
    int currentIndex,
  ) async {
    // 注释
    if (line.startsWith('--')) return;

    // return语句
    if (line.startsWith('return ')) {
      final value = _evaluateExpression(line.substring(7).trim());
      throw _ReturnException(value);
    }

    // print语句
    if (line.startsWith('print(')) {
      final content = line.substring(6, line.length - 1);
      final value = _evaluateExpression(content);
      _outputCallback?.call(value?.toString() ?? 'nil');
      return;
    }

    // log语句
    if (line.startsWith('log(')) {
      final content = line.substring(4, line.length - 1);
      final value = _evaluateExpression(content);
      _outputCallback?.call('[LOG] ${value?.toString() ?? 'nil'}');
      return;
    }

    // 函数定义（支持 function 和 local function）
    if (line.startsWith('function ') || line.startsWith('local function')) {
      // 移除"local "前缀（如果存在）
      String adjustedLine = line;
      if (line.startsWith('local function')) {
        // 移除"local "，保留"function"
        adjustedLine = line.substring(6); // 移除"local "
      }
      _parseFunctionDefinition(adjustedLine, allLines, currentIndex);
      return;
    }

    // 赋值语句
    if (line.contains('=') && !line.startsWith('if') && !line.startsWith('for')) {
      final parts = line.split('=');
      if (parts.length == 2) {
        var varName = parts[0].trim();
        // 移除local关键字
        if (varName.startsWith('local ')) {
          varName = varName.substring(6).trim();
        }
        final value = _evaluateExpression(parts[1].trim());
        _variables[varName] = value;
      }
      return;
    }

    // if语句
    if (line.startsWith('if ')) {
      _executeIfStatement(line, allLines, currentIndex);
      return;
    }

    // for循环
    if (line.startsWith('for ')) {
      await _executeForLoop(line, allLines, currentIndex);
      return;
    }

    // 函数调用
    if (line.contains('(') && line.endsWith(')')) {
      _executeFunctionCall(line);
      return;
    }
  }

  /// 计算表达式
  dynamic _evaluateExpression(String expr) {
    expr = expr.trim();

    // 字符串字面量
    if (expr.startsWith('"') && expr.endsWith('"')) {
      return expr.substring(1, expr.length - 1);
    }

    // 数字
    if (double.tryParse(expr) != null) {
      return double.tryParse(expr);
    }

    // 布尔值
    if (expr == 'true') return true;
    if (expr == 'false') return false;
    if (expr == 'nil') return null;

    // 变量
    if (_variables.containsKey(expr)) {
      return _variables[expr];
    }

    // 函数调用（如 add(5, 3)）
    if (expr.contains('(') && expr.endsWith(')')) {
      return _executeFunctionCall(expr);
    }

    // 字符串连接
    if (expr.contains(' .. ')) {
      final parts = expr.split(' .. ');
      final values = parts.map((p) => _evaluateExpression(p.trim()));
      return values.map((v) => v?.toString() ?? 'nil').join('');
    }

    // 算术运算
    if (expr.contains('+')) {
      final parts = expr.split('+');
      if (parts.length == 2) {
        final left = _evaluateExpression(parts[0].trim());
        final right = _evaluateExpression(parts[1].trim());
        if (left is num && right is num) {
          return left + right;
        }
      }
    }

    // 返回原始表达式
    return expr;
  }

  /// 解析函数定义
  void _parseFunctionDefinition(
    String line,
    List<String> allLines,
    int startIndex,
  ) {
    // function name(param1, param2)
    final funcDecl = line.substring(9); // 移除 "function "
    final parenIndex = funcDecl.indexOf('(');
    final funcName = funcDecl.substring(0, parenIndex).trim();
    final params = funcDecl
        .substring(parenIndex + 1, funcDecl.indexOf(')'))
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    // 查找函数体（简化版，假设函数以end结束）
    final body = <String>[];
    var i = startIndex + 1;
    var bodyLineCount = 0;
    while (i < allLines.length) {
      final currentLine = allLines[i].trim();
      bodyLineCount++;
      if (currentLine == 'end') {
        break;
      }
      body.add(currentLine);
      i++;
    }

    // 设置跳过的行数（包括函数定义行、函数体行和end行）
    _skipLines = bodyLineCount;

    _functions[funcName] = _FunctionDefinition(
      name: funcName,
      parameters: params,
      body: body,
    );
  }

  /// 执行if语句
  void _executeIfStatement(
    String line,
    List<String> allLines,
    int startIndex,
  ) {
    // if condition then
    final condition = line.substring(3, line.indexOf('then')).trim();
    final conditionValue = _evaluateExpression(condition);

    if (conditionValue == true || conditionValue != null && conditionValue != false && conditionValue != 0) {
      // 执行then块
      var i = startIndex + 1;
      while (i < allLines.length) {
        final currentLine = allLines[i].trim();
        if (currentLine == 'end' || currentLine.startsWith('else') || currentLine.startsWith('elseif')) break;
        _executeLine(currentLine, allLines, i);
        i++;
      }
    }
  }

  /// 执行for循环
  Future<void> _executeForLoop(
    String line,
    List<String> allLines,
    int startIndex,
  ) async {
    // for i = 1, 10 do
    final forContent = line.substring(4, line.indexOf(' do')).trim();
    final parts = forContent.split('=');
    if (parts.length != 2) return;

    final varName = parts[0].trim();
    final range = parts[1].trim().split(',');
    if (range.length != 2) return;

    final start = int.tryParse(_evaluateExpression(range[0].trim()).toString()) ?? 1;
    final end = int.tryParse(_evaluateExpression(range[1].trim()).toString()) ?? 1;

    // 查找循环体
    final body = <String>[];
    var i = startIndex + 1;
    while (i < allLines.length) {
      final currentLine = allLines[i].trim();
      if (currentLine == 'end') break;
      body.add(currentLine);
      i++;
    }

    // 执行循环
    for (var value = start; value <= end; value++) {
      _variables[varName] = value;
      for (final bodyLine in body) {
        await _executeLine(bodyLine, allLines, startIndex);
      }
    }

    _variables.remove(varName);
  }

  /// 执行if语句（同步版本，用于函数体）
  void _executeIfStatementSync(
    String line,
    List<String> allLines,
    int startIndex,
  ) {
    // if condition then
    final condition = line.substring(3, line.indexOf('then')).trim();
    final conditionValue = _evaluateExpression(condition);

    if (conditionValue == true || conditionValue != null && conditionValue != false && conditionValue != 0) {
      // 执行then块
      var i = startIndex + 1;
      while (i < allLines.length) {
        final currentLine = allLines[i].trim();
        if (currentLine == 'end' || currentLine.startsWith('else') || currentLine.startsWith('elseif')) break;
        _executeLineSync(currentLine, allLines, i);
        i++;
      }
    }
  }

  /// 执行函数调用
  dynamic _executeFunctionCall(String line) {
    final parenIndex = line.indexOf('(');
    final funcName = line.substring(0, parenIndex).trim();
    final argsStr = line.substring(parenIndex + 1, line.length - 1);

    final args = argsStr.isEmpty
        ? <dynamic>[]
        : argsStr.split(',').map((arg) => _evaluateExpression(arg.trim())).toList();

    if (_functions.containsKey(funcName)) {
      final func = _functions[funcName]!;

      // 如果是原生函数，直接调用
      if (func.nativeFunction != null) {
        return func.nativeFunction!(args);
      }

      // 设置参数
      for (var i = 0; i < func.parameters.length && i < args.length; i++) {
        _variables[func.parameters[i]] = args[i];
      }

      // 执行函数体，捕获返回值
      dynamic returnValue;
      try {
        for (final bodyLine in func.body) {
          // 由于_executeLine是async的，需要特殊处理
          // 但在这里我们同步执行，所以直接调用
          // 实际上_executeLine在函数体执行时应该是同步的
          _executeLineSync(bodyLine, func.body, 0);
        }
      } on _ReturnException catch (e) {
        returnValue = e.value;
      }

      // 清理参数
      for (final param in func.parameters) {
        _variables.remove(param);
      }

      return returnValue;
    } else {
      // 抛出异常而不是输出错误消息
      throw Exception('函数未找到: $funcName');
    }
  }

  /// 同步执行单行代码（用于函数体执行）
  void _executeLineSync(
    String line,
    List<String> allLines,
    int currentIndex,
  ) {
    // 注释
    if (line.startsWith('--')) return;

    // return语句
    if (line.startsWith('return ')) {
      final value = _evaluateExpression(line.substring(7).trim());
      throw _ReturnException(value);
    }

    // print语句
    if (line.startsWith('print(')) {
      final content = line.substring(6, line.length - 1);
      final value = _evaluateExpression(content);
      _outputCallback?.call(value?.toString() ?? 'nil');
      return;
    }

    // log语句
    if (line.startsWith('log(')) {
      final content = line.substring(4, line.length - 1);
      final value = _evaluateExpression(content);
      _outputCallback?.call('[LOG] ${value?.toString() ?? 'nil'}');
      return;
    }

    // 函数定义（在函数体中不支持嵌套定义）
    if (line.startsWith('function ')) {
      return; // 忽略嵌套函数定义
    }

    // 赋值语句
    if (line.contains('=') && !line.startsWith('if') && !line.startsWith('for')) {
      final parts = line.split('=');
      if (parts.length == 2) {
        var varName = parts[0].trim();
        // 移除local关键字
        if (varName.startsWith('local ')) {
          varName = varName.substring(6).trim();
        }
        final value = _evaluateExpression(parts[1].trim());
        _variables[varName] = value;
      }
      return;
    }

    // if语句
    if (line.startsWith('if ')) {
      _executeIfStatementSync(line, allLines, currentIndex);
      return;
    }

    // for循环（在函数体中简化处理）
    if (line.startsWith('for ')) {
      // 在函数体中不支持循环
      return;
    }

    // 函数调用
    if (line.contains('(') && line.endsWith(')')) {
      _executeFunctionCall(line);
      return;
    }
  }

  /// 注册函数
  void registerFunction(String name, dynamic Function(List<dynamic>) fn) {
    _functions[name] = _FunctionDefinition(
      name: name,
      parameters: [],
      body: [],
      nativeFunction: fn,
    );
  }

  /// 重置引擎
  Future<void> reset() async {
    _variables.clear();
    _functions.clear();
    if (enableDebugOutput) {
      _outputCallback?.call('引擎已重置');
    }
  }

  /// 释放资源
  Future<void> dispose() async {
    _variables.clear();
    _functions.clear();
    _isInitialized = false;
  }

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 是否启用沙箱模式
  bool get enableSandbox => false;
}

/// 函数定义
class _FunctionDefinition {
  const _FunctionDefinition({
    required this.name,
    required this.parameters,
    required this.body,
    this.nativeFunction,
  });

  final String name;
  final List<String> parameters;
  final List<String> body;
  final dynamic Function(List<dynamic>)? nativeFunction;
}

/// Return语句异常
class _ReturnException implements Exception {
  const _ReturnException(this.value);

  final dynamic value;
}
