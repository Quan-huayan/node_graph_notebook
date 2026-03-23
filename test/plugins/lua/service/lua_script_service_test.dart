import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_script_service.dart';
import 'package:node_graph_notebook/plugins/lua/models/lua_script.dart';
import 'dart:io';

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
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('初始化服务', () async {
      expect(service.getAllScripts(), isEmpty);
    });

    test('保存脚本', () async {
      final script = LuaScript(
        id: 'test-id',
        name: 'test-script',
        content: 'print("Hello, World!")',
        enabled: true,
      );

      await service.saveScript(script);

      final file = File('${tempDir.path}/test-script.lua');
      expect(await file.exists(), true);

      final content = await file.readAsString();
      expect(content, contains('print("Hello, World!")'));
    });

    test('加载脚本', () async {
      // 创建测试脚本
      final file = File('${tempDir.path}/test.lua');
      await file.writeAsString('''
-- id: test-id
-- name: test
-- enabled: true
print("Hello")
''');

      await service.loadAllScripts();

      final scripts = service.getAllScripts();
      expect(scripts, hasLength(1));
      expect(scripts.first.name, equals('test'));
    });

    test('删除脚本', () async {
      final script = LuaScript(
        id: 'test-id',
        name: 'test-script',
        content: 'print("test")',
        enabled: true,
      );

      await service.saveScript(script);
      await service.deleteScript('test-id');

      final file = File('${tempDir.path}/test-script.lua');
      expect(await file.exists(), false);
    });

    test('启用脚本', () async {
      final script = LuaScript(
        id: 'test-id',
        name: 'test-script',
        content: 'print("test")',
        enabled: false,
      );

      await service.saveScript(script);
      await service.enableScript('test-id');

      final updated = service.getScriptInfo('test-id');
      expect(updated?.enabled, true);
    });

    test('禁用脚本', () async {
      final script = LuaScript(
        id: 'test-id',
        name: 'test-script',
        content: 'print("test")',
        enabled: true,
      );

      await service.saveScript(script);
      await service.disableScript('test-id');

      final updated = service.getScriptInfo('test-id');
      expect(updated?.enabled, false);
    });

    test('获取启用的脚本', () async {
      final script1 = LuaScript(
        id: 'id1',
        name: 'script1',
        content: 'print("1")',
        enabled: true,
      );

      final script2 = LuaScript(
        id: 'id2',
        name: 'script2',
        content: 'print("2")',
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
