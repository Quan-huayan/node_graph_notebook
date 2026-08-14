/// Lua脚本安全管理器
///
/// 负责Lua脚本的安全验证、权限控制和资源限制
library;

import 'package:flutter/foundation.dart';

/// Lua权限枚举
enum LuaPermission {
  /// 读取节点
  nodeRead,

  /// 写入节点
  nodeWrite,

  /// 删除节点
  nodeDelete,

  /// 系统操作
  systemAccess,

  /// 文件访问
  fileAccess,

  /// 网络访问
  networkAccess,
}

/// Lua沙箱配置
class LuaSandboxConfig {
  /// 构造函数
  const LuaSandboxConfig({
    this.maxExecutionTime = const Duration(seconds: 5),
    this.maxMemoryUsage = 10 * 1024 * 1024, // 10MB
    this.maxOutputLines = 1000,
    this.allowedPermissions = const [
      LuaPermission.nodeRead,
      LuaPermission.nodeWrite,
    ],
    this.enableSandbox = true,
    this.blockedPatterns = const [
      'os.execute',
      'io.popen',
      'io.open',
      'loadfile',
      'dofile',
      'require',
      'debug',
    ],
  });

  /// 创建宽松配置（开发环境）
  factory LuaSandboxConfig.permissive() => const LuaSandboxConfig(
      maxExecutionTime: Duration(minutes: 5),
      maxMemoryUsage: 100 * 1024 * 1024, // 100MB
      maxOutputLines: 10000,
      allowedPermissions: [
        LuaPermission.nodeRead,
        LuaPermission.nodeWrite,
        LuaPermission.nodeDelete,
        LuaPermission.systemAccess,
      ],
      enableSandbox: false,
      blockedPatterns: [],
    );

  /// 创建严格配置（生产环境）
  factory LuaSandboxConfig.strict() => const LuaSandboxConfig(
      maxExecutionTime: Duration(seconds: 3),
      maxMemoryUsage: 5 * 1024 * 1024, // 5MB
      maxOutputLines: 500,
      allowedPermissions: [
        LuaPermission.nodeRead,
      ],
      enableSandbox: true,
      blockedPatterns: [
        'os.execute',
        'io.popen',
        'io.open',
        'loadfile',
        'dofile',
        'require',
        'debug',
        'os.remove',
        'os.rename',
        'os.tmpname',
      ],
    );

  /// 最大执行时间
  final Duration maxExecutionTime;

  /// 最大内存使用（字节）
  final int maxMemoryUsage;

  /// 最大输出行数
  final int maxOutputLines;

  /// 允许的权限列表
  final List<LuaPermission> allowedPermissions;

  /// 是否启用沙箱
  final bool enableSandbox;

  /// 阻止的危险模式列表
  final List<String> blockedPatterns;
}

/// Lua安全异常
class LuaSecurityException implements Exception {
  /// 构造函数
  const LuaSecurityException(this.message, {this.reason});

  /// 错误消息
  final String message;

  /// 安全违规原因
  final LuaSecurityReason? reason;

  @override
  String toString() {
    if (reason != null) {
      return 'LuaSecurityException: $message (原因: ${reason?.description})';
    }
    return 'LuaSecurityException: $message';
  }
}

/// 安全违规原因
enum LuaSecurityReason {
  /// 超出最大执行时间
  timeout('脚本执行超时'),

  /// 超出内存限制
  outOfMemory('脚本内存使用超限'),

  /// 检测到危险操作
  dangerousOperation('检测到危险操作'),

  /// 权限不足
  permissionDenied('权限不足'),

  /// 输出过大
  outputTooLarge('脚本输出过大'),

  /// 语法错误
  syntaxError('脚本语法错误');
  
  const LuaSecurityReason(this.description);

  /// 原因描述
  final String description;
}

/// Lua脚本验证结果
class LuaScriptValidationResult {
  /// 构造函数
  const LuaScriptValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  /// 创建成功结果
  factory LuaScriptValidationResult.success() => const LuaScriptValidationResult(
      isValid: true,
      errors: [],
      warnings: [],
    );

  /// 创建失败结果
  factory LuaScriptValidationResult.failure(List<String> errors) => LuaScriptValidationResult(
      isValid: false,
      errors: errors,
    );

  /// 是否有效
  final bool isValid;

  /// 错误列表
  final List<String> errors;

  /// 警告列表
  final List<String> warnings;
}

/// Lua安全管理器
///
/// 负责脚本安全验证、权限控制和资源限制
class LuaSecurityManager {
  /// 构造函数
  LuaSecurityManager({LuaSandboxConfig? config})
      : config = config ?? const LuaSandboxConfig();

  /// 沙箱配置
  final LuaSandboxConfig config;

  /// 验证脚本安全性
  ///
  /// 检查脚本是否包含危险操作
  LuaScriptValidationResult validateScript(String script) {
    final errors = <String>[];
    final warnings = <String>[];

    try {
      // 检查危险模式
      if (config.enableSandbox) {
        for (final pattern in config.blockedPatterns) {
          if (script.contains(pattern)) {
            errors.add(
              '检测到危险操作: "$pattern" 已被沙箱阻止',
            );
          }
        }
      }

      // 检查脚本长度
      if (script.length > 100000) {
        warnings.add('脚本长度超过100KB，可能影响性能');
      }

      // 检查无限循环风险
      if (_hasInfiniteLoopRisk(script)) {
        warnings.add('检测到可能的无限循环风险');
      }

      // 检查递归调用
      if (_hasDeepRecursion(script)) {
        warnings.add('检测到深度递归调用，可能导致栈溢出');
      }

      return LuaScriptValidationResult(
        isValid: errors.isEmpty,
        errors: errors,
        warnings: warnings,
      );
    } catch (e) {
      return LuaScriptValidationResult.failure([
        '脚本验证失败: $e',
      ]);
    }
  }

  /// 检查权限
  ///
  /// 验证脚本是否有执行某操作的权限
  void checkPermission(LuaPermission requiredPermission) {
    if (!config.allowedPermissions.contains(requiredPermission)) {
      throw LuaSecurityException(
        '权限不足: ${requiredPermission.name}',
        reason: LuaSecurityReason.permissionDenied,
      );
    }
  }

  /// 检查执行时间
  ///
  /// 验证脚本执行时间是否超限
  void checkExecutionTime(Duration executionTime) {
    if (executionTime > config.maxExecutionTime) {
      throw LuaSecurityException(
        '脚本执行超时: ${executionTime.inSeconds}s > ${config.maxExecutionTime.inSeconds}s',
        reason: LuaSecurityReason.timeout,
      );
    }
  }

  /// 检查输出大小
  ///
  /// 验证脚本输出是否过大
  void checkOutputSize(int outputLines) {
    if (outputLines > config.maxOutputLines) {
      throw LuaSecurityException(
        '脚本输出过大: $outputLines 行 > ${config.maxOutputLines} 行',
        reason: LuaSecurityReason.outputTooLarge,
      );
    }
  }

  /// 过滤输出
  ///
  /// 限制输出行数，防止内存溢出
  List<String> filterOutput(List<String> output) {
    if (output.length <= config.maxOutputLines) {
      return output;
    }

    debugPrint(
      '[LUA SECURITY] 输出被截断: ${output.length} -> ${config.maxOutputLines}',
    );

    return output.sublist(0, config.maxOutputLines);
  }

  /// 检测无限循环风险
  bool _hasInfiniteLoopRisk(String script) {
    // 检查是否有while true但没有break
    final hasWhileTrue = RegExp(r'while\s+true\s+do').hasMatch(script);
    final hasBreak = RegExp(r'\bbreak\b').hasMatch(script);

    return hasWhileTrue && !hasBreak;
  }

  /// 检测深度递归
  bool _hasDeepRecursion(String script) {
    // 简单的递归检测：检查函数是否调用自身
    final functionDefinitions = RegExp(r'function\s+(\w+)').allMatches(script);
    final functionNames = functionDefinitions.map((m) => m.group(1)).toSet();

    for (final name in functionNames) {
      if (name != null && RegExp(r'\b$name\s*\(').allMatches(script).length > 2) {
        return true;
      }
    }

    return false;
  }

  /// 创建安全报告
  Map<String, dynamic> createSecurityReport() => {
      'sandboxEnabled': config.enableSandbox,
      'maxExecutionTime': config.maxExecutionTime.inSeconds,
      'maxMemoryUsage': config.maxMemoryUsage,
      'maxOutputLines': config.maxOutputLines,
      'allowedPermissions': config.allowedPermissions.map((p) => p.name).toList(),
      'blockedPatterns': config.blockedPatterns,
    };

  /// 验证API调用权限
  ///
  /// 根据API名称检查权限
  void validateAPIAccess(String apiName) {
    switch (apiName) {
      case 'createNode':
      case 'updateNode':
        checkPermission(LuaPermission.nodeWrite);
        break;
      case 'deleteNode':
        checkPermission(LuaPermission.nodeDelete);
        break;
      case 'getNode':
      case 'getAllNodes':
      case 'getChildNodes':
        checkPermission(LuaPermission.nodeRead);
        break;
      case 'os.execute':
      case 'io.open':
        checkPermission(LuaPermission.systemAccess);
        break;
      default:
        // 未知API，默认允许
        break;
    }
  }
}
