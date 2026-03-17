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
      test('should return empty list when no presets stored', () async {
        when(mockPrefs.getString(any)).thenAnswer((_) async => null);

        final result = await service.getAllPresets();

        expect(result, isEmpty);
        verify(mockPrefs.getString('search_presets')).called(1);
      });

      test('should return list of presets', () async {
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

      test('should sort presets by lastUsed then createdAt', () async {
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

      test('should handle invalid JSON gracefully', () async {
        when(mockPrefs.getString(any)).thenAnswer((_) async => 'invalid json');

        final result = await service.getAllPresets();

        expect(result, isEmpty);
      });

      test('should handle JSON decode error gracefully', () async {
        when(mockPrefs.getString(any)).thenAnswer((_) async => '{invalid}');

        final result = await service.getAllPresets();

        expect(result, isEmpty);
      });
    });

    group('getPreset', () {
      test('should return preset when found', () async {
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

      test('should return null when preset not found', () async {
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

      test('should return null when no presets stored', () async {
        when(mockPrefs.getString(any)).thenAnswer((_) async => null);

        final result = await service.getPreset('1');

        expect(result, isNull);
      });
    });

    group('savePreset', () {
      test('should save new preset', () async {
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

      test('should update existing preset', () async {
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

      test('should set lastUsed to current time', () async {
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

      test('should preserve other presets when adding new one', () async {
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
      test('should delete existing preset', () async {
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

      test('should handle deleting non-existent preset', () async {
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

      test('should handle deleting when no presets exist', () async {
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
      test('should update lastUsed time for existing preset', () async {
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

      test('should handle updating non-existent preset', () async {
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

      test('should handle updating when no presets exist', () async {
        when(mockPrefs.getString(any)).thenAnswer((_) async => null);
        when(mockPrefs.setString(any, any)).thenAnswer((_) async => true);

        await service.updateLastUsed('1');

        verifyNever(mockPrefs.setString('search_presets', any));
      });
    });

    group('integration tests', () {
      test('should handle complete workflow', () async {
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
