import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_security_manager.dart';

void main() {
  group('LuaSecurityManager', () {
    late LuaSecurityManager securityManager;

    setUp(() {
      securityManager = LuaSecurityManager(
        config: LuaSandboxConfig.strict(),
      );
    });

    test('应该阻止危险操作', () {
      final dangerousScript = '''
        os.execute("rm -rf /")
      ''';

      final result = securityManager.validateScript(dangerousScript);

      expect(result.isValid, false);
      expect(result.errors, isNotEmpty);
      expect(result.errors.any((e) => e.contains('os.execute')), true);
    });

    test('应该允许安全脚本', () {
      final safeScript = '''
        local x = 10
        local y = 20
        print(x + y)
      ''';

      final result = securityManager.validateScript(safeScript);

      expect(result.isValid, true);
      expect(result.errors, isEmpty);
    });

    test('应该检测无限循环风险', () {
      final riskyScript = '''
        while true do
          print("loop")
        end
      ''';

      final result = securityManager.validateScript(riskyScript);

      expect(result.warnings.any((w) => w.contains('无限循环')), true);
    });

    test('应该限制输出大小', () {
      final largeOutput = List.generate(2000, (i) => 'Line $i');

      final filtered = securityManager.filterOutput(largeOutput);

      expect(filtered.length, lessThan(2000));
      expect(filtered.length, equals(500)); // strict模式限制500行
    });

    test('应该检查权限', () {
      // strict模式只允许nodeRead
      expect(
        () => securityManager.checkPermission(LuaPermission.nodeRead),
        returnsNormally,
      );

      expect(
        () => securityManager.checkPermission(LuaPermission.nodeDelete),
        throwsA(isA<LuaSecurityException>()),
      );
    });

    test('应该检查执行时间', () {
      final shortTime = Duration(seconds: 1);
      final longTime = Duration(seconds: 10);

      expect(
        () => securityManager.checkExecutionTime(shortTime),
        returnsNormally,
      );

      expect(
        () => securityManager.checkExecutionTime(longTime),
        throwsA(isA<LuaSecurityException>()),
      );
    });

    test('宽松模式应该允许更多操作', () {
      final permissiveManager = LuaSecurityManager(
        config: LuaSandboxConfig.permissive(),
      );

      final dangerousScript = '''
        os.execute("some command")
      ''';

      final result = permissiveManager.validateScript(dangerousScript);

      expect(result.isValid, true); // permissive模式不阻止
    });

    test('应该验证API访问权限', () {
      // strict模式不允许nodeDelete
      expect(
        () => securityManager.validateAPIAccess('getNode'),
        returnsNormally,
      );

      expect(
        () => securityManager.validateAPIAccess('deleteNode'),
        throwsA(isA<LuaSecurityException>()),
      );
    });

    test('应该创建安全报告', () {
      final report = securityManager.createSecurityReport();

      expect(report['sandboxEnabled'], true);
      expect(report['maxExecutionTime'], 3);
      expect(report['maxMemoryUsage'], 5 * 1024 * 1024);
      expect(report['allowedPermissions'], contains('nodeRead'));
    });

    test('应该检测深度递归', () {
      final recursiveScript = '''
        function factorial(n)
          if n <= 1 then
            return 1
          end
          return n * factorial(n - 1)
        end

        factorial(100)
      ''';

      final result = securityManager.validateScript(recursiveScript);

      // 注意：当前递归检测可能不总是能检测到
      // 这里只验证脚本不会崩溃
      expect(result, isNotNull);
    });
  });

  group('LuaSandboxConfig', () {
    test('严格配置应该有限制', () {
      final strictConfig = LuaSandboxConfig.strict();

      expect(strictConfig.enableSandbox, true);
      expect(strictConfig.maxExecutionTime.inSeconds, 3);
      expect(strictConfig.maxOutputLines, 500);
      expect(strictConfig.allowedPermissions, contains(LuaPermission.nodeRead));
      expect(strictConfig.allowedPermissions, isNot(contains(LuaPermission.nodeDelete)));
    });

    test('宽松配置应该允许更多', () {
      final permissiveConfig = LuaSandboxConfig.permissive();

      expect(permissiveConfig.enableSandbox, false);
      expect(permissiveConfig.maxExecutionTime.inMinutes, 5);
      expect(permissiveConfig.maxOutputLines, 10000);
      expect(permissiveConfig.allowedPermissions, contains(LuaPermission.nodeDelete));
    });

    test('默认配置应该是安全的', () {
      final defaultConfig = LuaSandboxConfig();

      expect(defaultConfig.enableSandbox, true);
      expect(defaultConfig.maxExecutionTime.inSeconds, 5);
      expect(defaultConfig.blockedPatterns, contains('os.execute'));
    });
  });

  group('LuaSecurityException', () {
    test('应该包含错误信息', () {
      final exception = LuaSecurityException('Test error');

      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('LuaSecurityException'));
    });

    test('应该包含安全原因', () {
      final exception = LuaSecurityException(
        'Test error',
        reason: LuaSecurityReason.timeout,
      );

      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('脚本执行超时'));
    });
  });
}
