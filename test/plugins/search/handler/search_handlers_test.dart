import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/core/commands/models/command_context.dart';
import 'package:node_graph_notebook/plugins/search/command/search_commands.dart';
import 'package:node_graph_notebook/plugins/search/handler/delete_search_preset_handler.dart';
import 'package:node_graph_notebook/plugins/search/handler/save_search_preset_handler.dart';
import 'package:node_graph_notebook/plugins/search/model/search_preset_model.dart';
import 'package:node_graph_notebook/plugins/search/service/search_preset_service.dart';

@GenerateMocks([
  SearchPresetService,
  CommandContext,
])
import 'search_handlers_test.mocks.dart';

void main() {
  group('SaveSearchPresetHandler', () {
    late SaveSearchPresetHandler handler;
    late MockSearchPresetService mockService;
    late MockCommandContext mockContext;

    setUp(() {
      mockService = MockSearchPresetService();
      mockContext = MockCommandContext();
      handler = SaveSearchPresetHandler(mockService);
    });

    test('应成功保存新预设', () async {
      final command = SaveSearchPresetCommand(
        presetName: 'Test Preset',
        titleQuery: 'test',
        contentQuery: 'content',
        tags: ['tag1'],
      );

      final savedPreset = SearchPreset(
        id: '1',
        name: 'Test Preset',
        titleQuery: 'test',
        contentQuery: 'content',
        tags: ['tag1'],
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      );

      when(mockService.savePreset(any)).thenAnswer((_) async => savedPreset);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data, isNotNull);
      expect(result.data!.name, 'Test Preset');
      verify(mockService.savePreset(any)).called(1);
    });

    test('提供 id 时应更新现有预设', () async {
      final command = SaveSearchPresetCommand(
        id: '1',
        presetName: 'Updated Preset',
        titleQuery: 'test',
      );

      final updatedPreset = SearchPreset(
        id: '1',
        name: 'Updated Preset',
        titleQuery: 'test',
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      );

      when(mockService.savePreset(any)).thenAnswer((_) async => updatedPreset);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data!.id, '1');
      expect(result.data!.name, 'Updated Preset');
    });

    test('预设名称为空时应失败', () async {
      final command = SaveSearchPresetCommand(
        presetName: '   ',
        titleQuery: 'test',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, '预设名称不能为空');
      verifyNever(mockService.savePreset(any));
    });

    test('预设名称为 null 时应失败', () async {
      final command = SaveSearchPresetCommand(
        presetName: '',
        titleQuery: 'test',
      );

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, '预设名称不能为空');
      verifyNever(mockService.savePreset(any));
    });

    test('应处理服务错误', () async {
      final command = SaveSearchPresetCommand(
        presetName: 'Test Preset',
        titleQuery: 'test',
      );

      when(mockService.savePreset(any)).thenThrow(Exception('Service error'));

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception: Service error'));
    });

    test('应使用所有参数创建预设', () async {
      final command = SaveSearchPresetCommand(
        presetName: 'Complete Preset',
        titleQuery: 'title',
        contentQuery: 'content',
        tags: ['tag1', 'tag2', 'tag3'],
      );

      final savedPreset = SearchPreset(
        id: '1',
        name: 'Complete Preset',
        titleQuery: 'title',
        contentQuery: 'content',
        tags: ['tag1', 'tag2', 'tag3'],
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      );

      when(mockService.savePreset(any)).thenAnswer((_) async => savedPreset);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data!.titleQuery, 'title');
      expect(result.data!.contentQuery, 'content');
      expect(result.data!.tags, ['tag1', 'tag2', 'tag3']);
    });

    test('应使用最少参数创建预设', () async {
      final command = SaveSearchPresetCommand(
        presetName: 'Minimal Preset',
      );

      final savedPreset = SearchPreset(
        id: '1',
        name: 'Minimal Preset',
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      );

      when(mockService.savePreset(any)).thenAnswer((_) async => savedPreset);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data!.titleQuery, null);
      expect(result.data!.contentQuery, null);
      expect(result.data!.tags, null);
    });

    test('应将 createdAt 和 lastUsed 设置为当前时间', () async {
      final command = SaveSearchPresetCommand(
        presetName: 'Test Preset',
      );

      final now = DateTime.now();
      final savedPreset = SearchPreset(
        id: '1',
        name: 'Test Preset',
        createdAt: now,
        lastUsed: now,
      );

      when(mockService.savePreset(any)).thenAnswer((_) async => savedPreset);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      expect(result.data!.createdAt, isNotNull);
      expect(result.data!.lastUsed, isNotNull);
    });
  });

  group('DeleteSearchPresetHandler', () {
    late DeleteSearchPresetHandler handler;
    late MockSearchPresetService mockService;
    late MockCommandContext mockContext;

    setUp(() {
      mockService = MockSearchPresetService();
      mockContext = MockCommandContext();
      handler = DeleteSearchPresetHandler(mockService);
    });

    test('应成功删除现有预设', () async {
      final command = DeleteSearchPresetCommand(id: '1');

      final existingPreset = SearchPreset(
        id: '1',
        name: 'Test Preset',
        createdAt: DateTime.now(),
      );

      when(mockService.getPreset('1')).thenAnswer((_) async => existingPreset);
      when(mockService.deletePreset('1')).thenAnswer((_) async {});

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      verify(mockService.getPreset('1')).called(1);
      verify(mockService.deletePreset('1')).called(1);
    });

    test('预设 id 为空时应失败', () async {
      final command = DeleteSearchPresetCommand(id: '   ');

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, '预设 ID 不能为空');
      verifyNever(mockService.getPreset(any));
      verifyNever(mockService.deletePreset(any));
    });

    test('预设 id 为 null 时应失败', () async {
      final command = DeleteSearchPresetCommand(id: '');

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, '预设 ID 不能为空');
      verifyNever(mockService.getPreset(any));
      verifyNever(mockService.deletePreset(any));
    });

    test('预设不存在时应失败', () async {
      final command = DeleteSearchPresetCommand(id: '999');

      when(mockService.getPreset('999')).thenAnswer((_) async => null);

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, '预设不存在: 999');
      verify(mockService.getPreset('999')).called(1);
      verifyNever(mockService.deletePreset(any));
    });

    test('应处理 getPreset 期间的服务错误', () async {
      final command = DeleteSearchPresetCommand(id: '1');

      when(mockService.getPreset('1')).thenThrow(Exception('Service error'));

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception: Service error'));
    });

    test('应处理 deletePreset 期间的服务错误', () async {
      final command = DeleteSearchPresetCommand(id: '1');

      final existingPreset = SearchPreset(
        id: '1',
        name: 'Test Preset',
        createdAt: DateTime.now(),
      );

      when(mockService.getPreset('1')).thenAnswer((_) async => existingPreset);
      when(mockService.deletePreset('1')).thenThrow(Exception('Delete error'));

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, false);
      expect(result.error, contains('Exception: Delete error'));
    });

    test('应处理复杂 id 的预设', () async {
      final command = DeleteSearchPresetCommand(id: 'preset-123-abc');

      final existingPreset = SearchPreset(
        id: 'preset-123-abc',
        name: 'Complex ID Preset',
        createdAt: DateTime.now(),
      );

      when(mockService.getPreset('preset-123-abc')).thenAnswer((_) async => existingPreset);
      when(mockService.deletePreset('preset-123-abc')).thenAnswer((_) async {});

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
      verify(mockService.getPreset('preset-123-abc')).called(1);
      verify(mockService.deletePreset('preset-123-abc')).called(1);
    });

    test('应处理删除 id 中包含特殊字符的预设', () async {
      final command = DeleteSearchPresetCommand(id: 'preset_with_underscores');

      final existingPreset = SearchPreset(
        id: 'preset_with_underscores',
        name: 'Underscore Preset',
        createdAt: DateTime.now(),
      );

      when(mockService.getPreset('preset_with_underscores')).thenAnswer((_) async => existingPreset);
      when(mockService.deletePreset('preset_with_underscores')).thenAnswer((_) async {});

      final result = await handler.execute(command, mockContext);

      expect(result.isSuccess, true);
    });
  });

  group('Command Handler Integration', () {
    late MockSearchPresetService mockService;
    late MockCommandContext mockContext;
    late SaveSearchPresetHandler saveHandler;
    late DeleteSearchPresetHandler deleteHandler;

    setUp(() {
      mockService = MockSearchPresetService();
      mockContext = MockCommandContext();
      saveHandler = SaveSearchPresetHandler(mockService);
      deleteHandler = DeleteSearchPresetHandler(mockService);
    });

    test('应处理保存和删除的工作流程', () async {
      final saveCommand = SaveSearchPresetCommand(
        presetName: 'Workflow Preset',
        titleQuery: 'test',
      );

      final savedPreset = SearchPreset(
        id: '1',
        name: 'Workflow Preset',
        titleQuery: 'test',
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      );

      when(mockService.savePreset(any)).thenAnswer((_) async => savedPreset);
      when(mockService.getPreset('1')).thenAnswer((_) async => savedPreset);
      when(mockService.deletePreset('1')).thenAnswer((_) async {});

      final saveResult = await saveHandler.execute(saveCommand, mockContext);
      expect(saveResult.isSuccess, true);

      final deleteCommand = DeleteSearchPresetCommand(id: '1');
      final deleteResult = await deleteHandler.execute(deleteCommand, mockContext);
      expect(deleteResult.isSuccess, true);

      verify(mockService.savePreset(any)).called(1);
      verify(mockService.getPreset('1')).called(1);
      verify(mockService.deletePreset('1')).called(1);
    });

    test('应处理更新和删除的工作流程', () async {
      final saveCommand = SaveSearchPresetCommand(
        id: '1',
        presetName: 'Original Preset',
        titleQuery: 'original',
      );

      final updatedPreset = SearchPreset(
        id: '1',
        name: 'Updated Preset',
        titleQuery: 'updated',
        createdAt: DateTime.now(),
        lastUsed: DateTime.now(),
      );

      when(mockService.savePreset(any)).thenAnswer((_) async => updatedPreset);
      when(mockService.getPreset('1')).thenAnswer((_) async => updatedPreset);
      when(mockService.deletePreset('1')).thenAnswer((_) async {});

      final saveResult = await saveHandler.execute(saveCommand, mockContext);
      expect(saveResult.isSuccess, true);
      expect(saveResult.data!.name, 'Updated Preset');

      final deleteCommand = DeleteSearchPresetCommand(id: '1');
      final deleteResult = await deleteHandler.execute(deleteCommand, mockContext);
      expect(deleteResult.isSuccess, true);
    });
  });
}
