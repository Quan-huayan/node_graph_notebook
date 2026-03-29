import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/command_bus.dart';
import 'package:node_graph_notebook/plugins/lua/bloc/lua_script_bloc.dart';
import 'package:node_graph_notebook/plugins/lua/bloc/lua_script_event.dart';
import 'package:node_graph_notebook/plugins/lua/models/lua_script.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_engine_service.dart';
import 'package:node_graph_notebook/plugins/lua/service/lua_script_service.dart';

@GenerateMocks([LuaScriptService, LuaEngineService])
import 'lua_script_bloc_test.mocks.dart';

void main() {
  group('LuaScriptBloc', () {
    late LuaScriptBloc bloc;
    late MockLuaScriptService mockScriptService;
    late MockLuaEngineService mockEngineService;
    late CommandBus commandBus;

    setUp(() {
      mockScriptService = MockLuaScriptService();
      mockEngineService = MockLuaEngineService();
      commandBus = CommandBus();

      // Mock engine service properties
      when(mockEngineService.isInitialized).thenReturn(true);

      // Mock script service loadAllScripts (called in constructor)
      when(mockScriptService.loadAllScripts()).thenAnswer((_) async => []);

      bloc = LuaScriptBloc(
        scriptService: mockScriptService,
        engineService: mockEngineService,
        commandBus: commandBus,
      );
    });

    tearDown(() {
      bloc.close();
    });

    test('初始状态正确', () async {
      // 等待初始加载完成
      await Future.delayed(const Duration(milliseconds: 100));

      expect(bloc.state.scripts, isEmpty);
      expect(bloc.state.isLoading, false);
    });

    test('加载脚本列表', () async {
      // 等待初始加载完成
      await Future.delayed(const Duration(milliseconds: 100));

      final scripts = [
        const LuaScript(
          id: '1',
          name: 'script1',
          content: 'debugPrint("1")',
          enabled: true,
        ),
      ];

      when(mockScriptService.loadAllScripts())
          .thenAnswer((_) async => scripts);

      bloc.add(const LoadScriptsEvent());

      await Future.delayed(const Duration(milliseconds: 100));

      // 被调用了2次：一次在构造函数，一次在测试中
      verify(mockScriptService.loadAllScripts()).called(2);
    });

    test('清空控制台', () async {
      // 先添加一些输出
      bloc.add(const AddConsoleOutputEvent(line: 'line1'));
      await Future.delayed(const Duration(milliseconds: 50));

      // 清空
      bloc.add(const ClearConsoleEvent());
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.consoleOutput, isEmpty);
    });

    test('保存脚本', () async {
      const script = LuaScript(
        id: '1',
        name: 'test',
        content: 'debugPrint("test")',
        enabled: true,
      );

      when(mockScriptService.saveScript(any))
          .thenAnswer((_) async {});
      when(mockScriptService.loadAllScripts())
          .thenAnswer((_) async => [script]);

      bloc.add(const SaveScriptEvent(script: script));

      await Future.delayed(const Duration(milliseconds: 100));

      verify(mockScriptService.saveScript(script)).called(1);
    });

    test('删除脚本', () async {
      when(mockScriptService.deleteScript('1'))
          .thenAnswer((_) async {});
      when(mockScriptService.loadAllScripts())
          .thenAnswer((_) async => []);

      bloc.add(const DeleteScriptEvent(scriptId: '1'));

      await Future.delayed(const Duration(milliseconds: 100));

      verify(mockScriptService.deleteScript('1')).called(1);
    });

    test('切换脚本启用状态', () async {
      when(mockScriptService.enableScript('1'))
          .thenAnswer((_) async {});
      when(mockScriptService.loadAllScripts())
          .thenAnswer((_) async => []);

      bloc.add(const ToggleScriptEvent(
        scriptId: '1',
        enabled: true,
      ));

      await Future.delayed(const Duration(milliseconds: 100));

      verify(mockScriptService.enableScript('1')).called(1);
    });

    test('选择脚本', () async {
      bloc.add(const SelectScriptEvent(scriptId: '1'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.selectedScriptId, equals('1'));
    });

    test('添加控制台输出', () async {
      bloc.add(const AddConsoleOutputEvent(line: 'Test output'));
      await Future.delayed(const Duration(milliseconds: 50));

      expect(bloc.state.consoleOutput, contains('Test output'));
    });
  });
}
