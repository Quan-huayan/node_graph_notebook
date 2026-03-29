import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:node_graph_notebook/plugins/search/model/search_preset_model.dart';
import 'package:node_graph_notebook/plugins/search/service/search_preset_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateMocks([
  SharedPreferencesAsync,
])
import 'search_preset_service_test.mocks.dart';

void main() {
  group('SearchPresetServiceImpl', () {
    late SearchPresetServiceImpl service;
    late MockSharedPreferencesAsync mockPrefs;

    setUp(() {
      mockPrefs = MockSharedPreferencesAsync();
      service = SearchPresetServiceImpl(mockPrefs);
    });

    group('getAllPresets', () {
      test('没有存储预设时应返回空列表', () async {
        when(mockPrefs.getString(any)).thenAnswer((_) async => null);

        final result = await service.getAllPresets();

        expect(result, isEmpty);
        verify(mockPrefs.getString('search_presets')).called(1);
      });

      test('应返回预设列表', () async {
        final now = DateTime.now();
        final preset1 = SearchPreset(
          id: '1',
          name: 'Preset 1',
          createdAt: now,
        );
        final preset2 = SearchPreset(
          id: '2',
          name: 'Preset 2',
          createdAt: now,
        );

        final jsonList = [preset1.toJson(), preset2.toJson()];
        when(mockPrefs.getString(any)).thenAnswer(
          (_) async => jsonEncode(jsonList),
        );

        final result = await service.getAllPresets();

        expect(result.length, 2);
        expect(result[0].id, '1');
        expect(result[1].id, '2');
      });

      test('应按 lastUsed 然后 createdAt 排序预设', () async {
        final now = DateTime.now();
        final preset1 = SearchPreset(
          id: '1',
          name: 'Preset 1',
          createdAt: now.subtract(const Duration(days: 2)),
          lastUsed: now.subtract(const Duration(days: 1)),
        );
        final preset2 = SearchPreset(
          id: '2',
          name: 'Preset 2',
          createdAt: now,
          lastUsed: now,
        );
        final preset3 = SearchPreset(
          id: '3',
          name: 'Preset 3',
          createdAt: now.subtract(const Duration(days: 3)),
        );

        final jsonList = [preset1.toJson(), preset2.toJson(), preset3.toJson()];
        when(mockPrefs.getString(any)).thenAnswer(
          (_) async => jsonEncode(jsonList),
        );

        final result = await service.getAllPresets();

        expect(result[0].id, '2');
        expect(result[1].id, '1');
        expect(result[2].id, '3');
      });

      test('应优雅地处理无效 JSON', () async {
        when(mockPrefs.getString(any)).thenAnswer((_) async => 'invalid json');

        final result = await service.getAllPresets();

        expect(result, isEmpty);
      });

      test('应优雅地处理 JSON 解码错误', () async {
        when(mockPrefs.getString(any)).thenAnswer((_) async => '{invalid}');

        final result = await service.getAllPresets();

        expect(result, isEmpty);
      });
    });

    group('getPreset', () {
      test('找到预设时应返回预设', () async {
        final now = DateTime.now();
        final preset1 = SearchPreset(
          id: '1',
          name: 'Preset 1',
          createdAt: now,
        );
        final preset2 = SearchPreset(
          id: '2',
          name: 'Preset 2',
          createdAt: now,
        );

        final jsonList = [preset1.toJson(), preset2.toJson()];
        when(mockPrefs.getString(any)).thenAnswer(
          (_) async => jsonEncode(jsonList),
        );

        final result = await service.getPreset('1');

        expect(result, isNotNull);
        expect(result!.id, '1');
        expect(result.name, 'Preset 1');
      });

      test('未找到预设时应返回 null', () async {
        final now = DateTime.now();
        final preset1 = SearchPreset(
          id: '1',
          name: 'Preset 1',
          createdAt: now,
        );

        final jsonList = [preset1.toJson()];
        when(mockPrefs.getString(any)).thenAnswer(
          (_) async => jsonEncode(jsonList),
        );

        final result = await service.getPreset('999');

        expect(result, isNull);
      });

      test('没有存储预设时应返回 null', () async {
        when(mockPrefs.getString(any)).thenAnswer((_) async => null);

        final result = await service.getPreset('1');

        expect(result, isNull);
      });
    });

    group('savePreset', () {
      test('应保存新预设', () async {
        final now = DateTime.now();
        final preset = SearchPreset(
          id: '1',
          name: 'New Preset',
          createdAt: now,
        );

        when(mockPrefs.getString(any)).thenAnswer((_) async => null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final result = await service.savePreset(preset);

        expect(result.id, '1');
        expect(result.lastUsed, isNotNull);
        verify(mockPrefs.setString('search_presets', any)).called(1);
      });

      test('应更新现有预设', () async {
        final now = DateTime.now();
        final preset1 = SearchPreset(
          id: '1',
          name: 'Old Preset',
          createdAt: now,
        );
        final preset2 = SearchPreset(
          id: '1',
          name: 'Updated Preset',
          createdAt: now,
        );

        final jsonList = [preset1.toJson()];
        when(mockPrefs.getString(any)).thenAnswer(
          (_) async => jsonEncode(jsonList),
        );
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final result = await service.savePreset(preset2);

        expect(result.name, 'Updated Preset');
        expect(result.lastUsed, isNotNull);
        verify(mockPrefs.setString('search_presets', any)).called(1);
      });

      test('应将 lastUsed 设置为当前时间', () async {
        final now = DateTime.now();
        final preset = SearchPreset(
          id: '1',
          name: 'Preset',
          createdAt: now,
          lastUsed: now.subtract(const Duration(days: 1)),
        );

        when(mockPrefs.getString(any)).thenAnswer((_) async => null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final result = await service.savePreset(preset);

        expect(result.lastUsed!.isAfter(now.subtract(const Duration(seconds: 1))), true);
      });

      test('添加新预设时应保留其他预设', () async {
        final now = DateTime.now();
        final preset1 = SearchPreset(
          id: '1',
          name: 'Preset 1',
          createdAt: now,
        );
        final preset2 = SearchPreset(
          id: '2',
          name: 'Preset 2',
          createdAt: now,
        );

        final jsonList = [preset1.toJson()];
        when(mockPrefs.getString(any)).thenAnswer(
          (_) async => jsonEncode(jsonList),
        );
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        await service.savePreset(preset2);

        final captured = verify(mockPrefs.setString('search_presets', captureAny)).captured;
        final savedJson = captured[0] as String;
        final savedList = jsonDecode(savedJson) as List;

        expect(savedList.length, 2);
      });
    });

    group('deletePreset', () {
      test('应删除现有预设', () async {
        final now = DateTime.now();
        final preset1 = SearchPreset(
          id: '1',
          name: 'Preset 1',
          createdAt: now,
        );
        final preset2 = SearchPreset(
          id: '2',
          name: 'Preset 2',
          createdAt: now,
        );

        final jsonList = [preset1.toJson(), preset2.toJson()];
        when(mockPrefs.getString(any)).thenAnswer(
          (_) async => jsonEncode(jsonList),
        );
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        await service.deletePreset('1');

        final captured = verify(mockPrefs.setString('search_presets', captureAny)).captured;
        final savedJson = captured[0] as String;
        final savedList = jsonDecode(savedJson) as List<dynamic>;

        expect(savedList.length, 1);
        final firstPreset = savedList[0] as Map<String, dynamic>;
        expect(firstPreset['id'], '2');
      });

      test('应处理删除不存在的预设', () async {
        final now = DateTime.now();
        final preset1 = SearchPreset(
          id: '1',
          name: 'Preset 1',
          createdAt: now,
        );

        final jsonList = [preset1.toJson()];
        when(mockPrefs.getString(any)).thenAnswer(
          (_) async => jsonEncode(jsonList),
        );
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        await service.deletePreset('999');

        final captured = verify(mockPrefs.setString('search_presets', captureAny)).captured;
        final savedJson = captured[0] as String;
        final savedList = jsonDecode(savedJson) as List;

        expect(savedList.length, 1);
      });

      test('应处理没有预设时的删除操作', () async {
        when(mockPrefs.getString(any)).thenAnswer((_) async => null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        await service.deletePreset('1');

        final captured = verify(mockPrefs.setString('search_presets', captureAny)).captured;
        final savedJson = captured[0] as String;
        final savedList = jsonDecode(savedJson) as List;

        expect(savedList.length, 0);
      });
    });

    group('updateLastUsed', () {
      test('应更新现有预设的 lastUsed 时间', () async {
        final now = DateTime.now();
        final preset1 = SearchPreset(
          id: '1',
          name: 'Preset 1',
          createdAt: now,
          lastUsed: now.subtract(const Duration(days: 1)),
        );
        final preset2 = SearchPreset(
          id: '2',
          name: 'Preset 2',
          createdAt: now,
        );

        final jsonList = [preset1.toJson(), preset2.toJson()];
        when(mockPrefs.getString(any)).thenAnswer(
          (_) async => jsonEncode(jsonList),
        );
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        await service.updateLastUsed('1');

        final captured = verify(mockPrefs.setString('search_presets', captureAny)).captured;
        final savedJson = captured[0] as String;
        final savedList = jsonDecode(savedJson) as List<dynamic>;

        final updatedPreset = savedList.firstWhere((p) => p is Map<String, dynamic> && p['id'] == '1') as Map<String, dynamic>;
        final lastUsed = DateTime.parse(updatedPreset['lastUsed'] as String);

        expect(lastUsed.isAfter(now.subtract(const Duration(seconds: 1))), true);
      });

      test('应处理更新不存在的预设', () async {
        final now = DateTime.now();
        final preset1 = SearchPreset(
          id: '1',
          name: 'Preset 1',
          createdAt: now,
        );

        final jsonList = [preset1.toJson()];
        when(mockPrefs.getString(any)).thenAnswer(
          (_) async => jsonEncode(jsonList),
        );
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        await service.updateLastUsed('999');

        verifyNever(mockPrefs.setString('search_presets', any));
      });

      test('应处理没有预设时的更新操作', () async {
        when(mockPrefs.getString(any)).thenAnswer((_) async => null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        await service.updateLastUsed('1');

        verifyNever(mockPrefs.setString('search_presets', any));
      });
    });

    group('integration tests', () {
      test('应处理完整的工作流程', () async {
        final now = DateTime.now();

        final preset1 = SearchPreset(
          id: '1',
          name: 'Preset 1',
          createdAt: now,
        );

        final preset2 = SearchPreset(
          id: '2',
          name: 'Preset 2',
          createdAt: now,
        );

        when(mockPrefs.getString(any)).thenAnswer((_) async => jsonEncode([preset1.toJson(), preset2.toJson()]));
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        final loaded = await service.getPreset('1');
        expect(loaded, isNotNull);
        expect(loaded!.id, '1');

        final presets = await service.getAllPresets();
        expect(presets.length, 2);

        await service.deletePreset('1');

        when(mockPrefs.getString(any)).thenAnswer((_) async => jsonEncode([preset2.toJson()]));

        final afterDelete = await service.getPreset('1');
        expect(afterDelete, isNull);
      });
    });
  });
}
