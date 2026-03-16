import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../model/search_preset_model.dart';

/// 搜索预设服务接口
abstract class SearchPresetService {
  /// 获取所有预设
  Future<List<SearchPreset>> getAllPresets();

  /// 获取预设
  Future<SearchPreset?> getPreset(String id);

  /// 保存预设
  Future<SearchPreset> savePreset(SearchPreset preset);

  /// 删除预设
  Future<void> deletePreset(String id);

  /// 更新最后使用时间
  Future<void> updateLastUsed(String id);
}

/// 搜索预设服务实现
class SearchPresetServiceImpl implements SearchPresetService {
  /// 创建搜索预设服务实现
  /// 
  /// [prefs] - 异步 SharedPreferences 实例
  SearchPresetServiceImpl(SharedPreferencesAsync prefs) : _prefs = prefs;

  final SharedPreferencesAsync _prefs;
  static const String _key = 'search_presets';

  @override
  Future<List<SearchPreset>> getAllPresets() async {
    final jsonString = await _prefs.getString(_key);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => SearchPreset.fromJson(json as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          // 按最后使用时间排序，如果有则按时间倒序，否则按创建时间倒序
          final aTime = a.lastUsed ?? a.createdAt;
          final bTime = b.lastUsed ?? b.createdAt;
          return bTime.compareTo(aTime);
        });
    } catch (e) {
      return [];
    }
  }

  @override
  Future<SearchPreset?> getPreset(String id) async {
    final presets = await getAllPresets();
    try {
      return presets.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<SearchPreset> savePreset(SearchPreset preset) async {
    final presets = await getAllPresets();
    final index = presets.indexWhere((p) => p.id == preset.id);

    final updatedPreset = preset.copyWith(lastUsed: DateTime.now());

    List<SearchPreset> updatedPresets;
    if (index >= 0) {
      // 更新现有预设
      updatedPresets = [...presets];
      updatedPresets[index] = updatedPreset;
    } else {
      // 添加新预设
      updatedPresets = [...presets, updatedPreset];
    }

    await _savePresets(updatedPresets);
    return updatedPreset;
  }

  @override
  Future<void> deletePreset(String id) async {
    final presets = await getAllPresets();
    final updatedPresets = presets.where((p) => p.id != id).toList();
    await _savePresets(updatedPresets);
  }

  @override
  Future<void> updateLastUsed(String id) async {
    final presets = await getAllPresets();
    final index = presets.indexWhere((p) => p.id == id);

    if (index >= 0) {
      final updatedPresets = [...presets];
      updatedPresets[index] = presets[index].copyWith(lastUsed: DateTime.now());
      await _savePresets(updatedPresets);
    }
  }

  Future<void> _savePresets(List<SearchPreset> presets) async {
    final jsonString = json.encode(presets.map((p) => p.toJson()).toList());
    await _prefs.setString(_key, jsonString);
  }
}
