import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/logger.dart';
import 'infrastructure/storage_path_service.dart';

/// Logger for SettingsService
const _log = AppLogger('SettingsService');

/// 应用设置服务
class SettingsService with ChangeNotifier {
  /// 工厂构造函数
  factory SettingsService() => _instance;

  /// 私有构造函数
  SettingsService._internal();
  
  /// 单例实例
  static final SettingsService _instance = SettingsService._internal();

  // 存储键常量
  static const String _storagePathKey = 'storage_path';
  static const String _themeModeKey = 'theme_mode';
  static const String _defaultViewModeKey = 'default_view_mode';
  static const String _aiProviderKey = 'ai_provider';
  static const String _aiBaseUrlKey = 'ai_base_url';
  static const String _aiModelKey = 'ai_model';
  static const String _aiApiKeyKey = 'ai_api_key';

  /// 自定义存储路径
  String? _customStoragePath;
  
  /// 主题模式
  ThemeMode _themeMode = ThemeMode.system;
  
  /// 默认视图模式
  String? _defaultViewMode;
  
  /// AI 提供商
  String _aiProvider = 'openai'; // openai or anthropic
  
  /// AI API 基础 URL
  String _aiBaseUrl = 'https://api.openai.com/v1';
  
  /// AI 模型
  String _aiModel = 'gpt-4';
  
  /// AI API 密钥
  String? _aiApiKey;

  /// 初始化设置
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _customStoragePath = prefs.getString(_storagePathKey);
    _defaultViewMode = prefs.getString(_defaultViewModeKey);
    _aiProvider = prefs.getString(_aiProviderKey) ?? 'openai';
    _aiBaseUrl = prefs.getString(_aiBaseUrlKey) ?? 'https://api.openai.com/v1';
    _aiModel = prefs.getString(_aiModelKey) ?? 'gpt-4';
    _aiApiKey = prefs.getString(_aiApiKeyKey);

    final themeModeStr = prefs.getString(_themeModeKey);
    if (themeModeStr != null) {
      _themeMode = _parseThemeMode(themeModeStr);
    }

    notifyListeners();
  }

  /// 获取当前存储路径
  Future<String> getStoragePath() async {
    if (_customStoragePath != null && _customStoragePath!.isNotEmpty) {
      final dir = Directory(_customStoragePath!);
      if (dir.existsSync()) {
        return _customStoragePath!;
      }
    }

    // 返回默认路径
    final appDir = await getApplicationDocumentsDirectory();
    final defaultPath = '${appDir.path}/node_graph_notebook/data';
    return defaultPath;
  }

  /// 获取节点目录路径
  Future<String> getNodesPath() async {
    final basePath = await getStoragePath();
    return '$basePath/nodes';
  }

  /// 获取图目录路径
  Future<String> getGraphsPath() async {
    final basePath = await getStoragePath();
    return '$basePath/graphs';
  }

  /// 获取设置目录路径
  Future<String> getSettingsPath() async {
    final basePath = await getStoragePath();
    return '$basePath/settings';
  }

  /// 获取插件目录路径
  Future<String> getPluginsPath() async {
    final basePath = await getStoragePath();
    return '$basePath/plugins';
  }

  /// 设置自定义存储路径
  Future<bool> setCustomStoragePath(String? path) async {
    if (path == null || path.isEmpty) {
      _customStoragePath = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storagePathKey);
      notifyListeners();
      return true;
    }

    // 验证路径
    final dir = Directory(path);
    if (!dir.existsSync()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        _log.warning('Failed to create directory: $e');
        return false;
      }
    }

    _customStoragePath = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storagePathKey, path);
    notifyListeners();
    return true;
  }

  /// 通过文件选择器选择存储路径
  Future<String?> selectStoragePath() async {
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Storage Location',
    );

    if (result != null) {
      final success = await setCustomStoragePath(result);
      if (success) {
        return result;
      }
    }

    return null;
  }

  /// 获取主题模式
  ThemeMode get themeMode => _themeMode;

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.toString());
    notifyListeners();
  }

  /// 获取默认视图模式
  String? get defaultViewMode => _defaultViewMode;

  /// 设置默认视图模式
  Future<void> setDefaultViewMode(String? mode) async {
    _defaultViewMode = mode;
    final prefs = await SharedPreferences.getInstance();
    if (mode == null) {
      await prefs.remove(_defaultViewModeKey);
    } else {
      await prefs.setString(_defaultViewModeKey, mode);
    }
    notifyListeners();
  }

  /// 验证存储路径是否有效
  Future<bool> validateStoragePath(String path) async {
    try {
      final dir = Directory(path);
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }

      // 测试写入权限
      final testFile = File('$path/.write_test');
      await testFile.writeAsString('test');
      await testFile.delete();

      return true;
    } catch (e) {
      _log.warning('Path validation failed: $e');
      return false;
    }
  }

  /// 获取存储使用情况
  Future<StorageUsage> getStorageUsage() async {
    final basePath = await getStoragePath();
    final totalSize = await _calculateDirectorySize(Directory(basePath));

    var nodesCount = 0;
    var graphsCount = 0;

    try {
      final nodesDir = Directory(await getNodesPath());
      if (nodesDir.existsSync()) {
        await for (final entity in nodesDir.list()) {
          if (entity is File && entity.path.endsWith('.md')) {
            nodesCount++;
          }
        }
      }

      final graphsDir = Directory(await getGraphsPath());
      if (graphsDir.existsSync()) {
        await for (final entity in graphsDir.list()) {
          if (entity is File && entity.path.endsWith('.json')) {
            graphsCount++;
          }
        }
      }
    } catch (e) {
      _log.warning('Failed to count files: $e');
    }

    return StorageUsage(
      totalSize: totalSize,
      nodesCount: nodesCount,
      graphsCount: graphsCount,
    );
  }

  /// 计算目录大小
  Future<int> _calculateDirectorySize(Directory dir) async {
    var size = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    } catch (e) {
      _log.warning('Failed to calculate directory size: $e');
    }
    return size;
  }

  /// 解析主题模式
  ThemeMode _parseThemeMode(String modeStr) {
    switch (modeStr) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 重置所有设置为默认值
  Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storagePathKey);
    await prefs.remove(_themeModeKey);
    await prefs.remove(_defaultViewModeKey);
    await prefs.remove(_aiProviderKey);
    await prefs.remove(_aiBaseUrlKey);
    await prefs.remove(_aiModelKey);
    await prefs.remove(_aiApiKeyKey);

    _customStoragePath = null;
    _themeMode = ThemeMode.system;
    _defaultViewMode = null;
    _aiProvider = 'openai';
    _aiBaseUrl = 'https://api.openai.com/v1';
    _aiModel = 'gpt-4';
    _aiApiKey = null;

    notifyListeners();
  }

  /// 检查是否使用默认路径
  bool get isUsingDefaultPath => _customStoragePath == null;

  /// 获取当前自定义路径（如果有的话）
  String? get customStoragePath => _customStoragePath;

  // ============ AI 配置相关 ============

  /// 获取 AI 提供商
  String get aiProvider => _aiProvider;

  /// 设置 AI 提供商
  Future<void> setAIProvider(String provider) async {
    _aiProvider = provider;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiProviderKey, provider);
    notifyListeners();
  }

  /// 获取 AI Base URL
  String get aiBaseUrl => _aiBaseUrl;

  /// 设置 AI Base URL
  Future<void> setAIBaseUrl(String baseUrl) async {
    _aiBaseUrl = baseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiBaseUrlKey, baseUrl);
    notifyListeners();
  }

  /// 获取 AI Model
  String get aiModel => _aiModel;

  /// 设置 AI Model
  Future<void> setAIModel(String model) async {
    _aiModel = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_aiModelKey, model);
    notifyListeners();
  }

  /// 获取 AI API Key
  String? get aiApiKey => _aiApiKey;

  /// 设置 AI API Key
  Future<void> setAIApiKey(String? apiKey) async {
    _aiApiKey = apiKey;
    final prefs = await SharedPreferences.getInstance();
    if (apiKey == null || apiKey.isEmpty) {
      await prefs.remove(_aiApiKeyKey);
    } else {
      await prefs.setString(_aiApiKeyKey, apiKey);
    }
    notifyListeners();
  }

  /// 是否已配置 AI
  bool get isAIConfigured => _aiApiKey != null && _aiApiKey!.isNotEmpty;
}
