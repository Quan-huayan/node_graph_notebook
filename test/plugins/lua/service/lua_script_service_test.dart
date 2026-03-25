import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/plugins/lua/models/lua_script.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_script_service.dart';

void main() {
  group('LuaScriptService', () {
    late LuaScriptService service;
    late Directory tempDir;

    setUp(() async {
      // 创建临时目录
      tempDir = await Directory.systemTemp.createTemp('lua_test_');
      service = LuaScriptService(
        scriptsDirectory: tempDir.path,
      );
      await service.initialize();
    });

    tearDown(() async {
      await service.dispose();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('初始化服务', () async {
      expect(service.getAllScripts(), isEmpty);
    });

    test('保存脚本', () async {
      const script = LuaScript(
        id: 'test-id',
        name: 'test-script',
        content: 'debugPrint("Hello, World!")',
        enabled: true,
      );

      await service.saveScript(script);

      final file = File('${tempDir.path}/test-script.lua');
      expect(file.existsSync(), true);

      final content = await file.readAsString();
      expect(content, contains('debugPrint("Hello, World!")'));
    });

    test('加载脚本', () async {
      // 创建测试脚本
      final file = File('${tempDir.path}/test.lua');
      await file.writeAsString('''
-- id: test-id
-- name: test
-- enabled: true
debugPrint("Hello")
''');

      await service.loadAllScripts();

      final scripts = service.getAllScripts();
      expect(scripts, hasLength(1));
      expect(scripts.first.name, equals('test'));
    });

    test('删除脚本', () async {
      const script = LuaScript(
        id: 'test-id',
        name: 'test-script',
        content: 'debugPrint("test")',
        enabled: true,
      );

      await service.saveScript(script);
      await service.deleteScript('test-id');

      final file = File('${tempDir.path}/test-script.lua');
      expect(file.existsSync(), false);
    });

    test('启用脚本', () async {
      const script = LuaScript(
        id: 'test-id',
        name: 'test-script',
        content: 'debugPrint("test")',
        enabled: false,
      );

      await service.saveScript(script);
      await service.enableScript('test-id');

      final updated = service.getScriptInfo('test-id');
      expect(updated?.enabled, true);
    });

    test('禁用脚本', () async {
      const script = LuaScript(
        id: 'test-id',
        name: 'test-script',
        content: 'debugPrint("test")',
        enabled: true,
      );

      await service.saveScript(script);
      await service.disableScript('test-id');

      final updated = service.getScriptInfo('test-id');
      expect(updated?.enabled, false);
    });

    test('获取启用的脚本', () async {
      const script1 = LuaScript(
        id: 'id1',
        name: 'script1',
        content: 'debugPrint("1")',
        enabled: true,
      );

      const script2 = LuaScript(
        id: 'id2',
        name: 'script2',
        content: 'debugPrint("2")',
        enabled: false,
      );

      await service.saveScript(script1);
      await service.saveScript(script2);

      final enabled = service.getEnabledScripts();
      expect(enabled, hasLength(1));
      expect(enabled.first.id, equals('id1'));
    });
  });
}
