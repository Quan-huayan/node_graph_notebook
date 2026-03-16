import 'dart:io';
import 'package:file_picker/file_picker.dart' show FilePicker;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 存储路径服务
///
/// 仅负责应用数据存储路径的配置和管理
/// 不包含领域特定的配置（如 AI、插件配置等）
///
/// ### 职责
/// - 管理存储路径（默认路径或自定义路径）
/// - 提供子目录路径访问器（nodes、graphs、settings、plugins）
/// - 路径验证和选择
/// - 存储使用情况统计
class StoragePathService with ChangeNotifier {
  /// 创建存储路径服务
  StoragePathService(this._prefs) {
    _loadCustomPath();
  }

  /// 自定义存储路径存储键
  static const String _storagePathKey = 'storage_path';

  /// SharedPreferences 实例
  final SharedPreferences _prefs;

  /// 自定义存储路径
  ///
  /// 如果为 null，则使用默认路径
  String? _customStoragePath;

  /// 初始化服务
  ///
  /// 从 SharedPreferences 加载自定义路径
  void _loadCustomPath() {
    _customStoragePath = _prefs.getString(_storagePathKey);
  }

  /// 获取当前存储路径
  ///
  /// 优先返回自定义路径（如果存在且有效）
  /// 否则返回默认路径（应用文档目录/node_graph_notebook/data）
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
  ///
  /// 返回 {存储路径}/nodes
  Future<String> getNodesPath() async {
    final basePath = await getStoragePath();
    return '$basePath/nodes';
  }

  /// 获取图目录路径
  ///
  /// 返回 {存储路径}/graphs
  Future<String> getGraphsPath() async {
    final basePath = await getStoragePath();
    return '$basePath/graphs';
  }

  /// 获取设置目录路径
  ///
  /// 返回 {存储路径}/settings
  Future<String> getSettingsPath() async {
    final basePath = await getStoragePath();
    return '$basePath/settings';
  }

  /// 获取插件目录路径
  ///
  /// 返回 {存储路径}/plugins
  Future<String> getPluginsPath() async {
    final basePath = await getStoragePath();
    return '$basePath/plugins';
  }

  /// 设置自定义存储路径
  ///
  /// ### 参数
  /// - `path` - 新的存储路径，如果为 null 则重置为默认路径
  ///
  /// ### 返回
  /// 是否成功设置路径
  ///
  /// ### 失败条件
  /// - 路径无效
  /// - 无法创建目录
  Future<bool> setCustomStoragePath(String? path) async {
    if (path == null || path.isEmpty) {
      _customStoragePath = null;
      await _prefs.remove(_storagePathKey);
      notifyListeners();
      return true;
    }

    // 验证路径
    final dir = Directory(path);
    if (!dir.existsSync()) {
      try {
        await dir.create(recursive: true);
      } catch (e) {
        debugPrint('Failed to create directory: $e');
        return false;
      }
    }

    _customStoragePath = path;
    await _prefs.setString(_storagePathKey, path);
    notifyListeners();
    return true;
  }

  /// 通过文件选择器选择存储路径
  ///
  /// ### 返回
  /// 选择的路径，如果取消选择返回 null
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

  /// 验证存储路径是否有效
  ///
  /// ### 参数
  /// - `path` - 要验证的路径
  ///
  /// ### 返回
  /// 路径是否有效
  ///
  /// ### 验证内容
  /// - 目录是否存在（不存在则尝试创建）
  /// - 是否有写入权限
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
      debugPrint('Path validation failed: $e');
      return false;
    }
  }

  /// 计算目录大小
  ///
  /// ### 参数
  /// - `dir` - 要计算的目录
  ///
  /// ### 返回
  /// 目录大小（字节）
  Future<int> _calculateDirectorySize(Directory dir) async {
    var size = 0;
    try {
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          size += await entity.length();
        }
      }
    } catch (e) {
      debugPrint('Failed to calculate directory size: $e');
    }
    return size;
  }

  /// 获取存储使用情况
  ///
  /// 返回存储路径的总大小、节点数量、图数量等统计信息
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
      debugPrint('Failed to count files: $e');
    }

    return StorageUsage(
      totalSize: totalSize,
      nodesCount: nodesCount,
      graphsCount: graphsCount,
    );
  }

  /// 检查是否使用默认路径
  bool get isUsingDefaultPath => _customStoragePath == null;

  /// 获取当前自定义路径（如果有的话）
  String? get customStoragePath => _customStoragePath;
}

/// 存储使用情况
///
/// 表示存储路径的使用统计信息
class StorageUsage {
  /// 创建存储使用情况
  ///
  /// ### 参数
  /// - `totalSize` - 总大小（字节）
  /// - `nodesCount` - 节点数量
  /// - `graphsCount` - 图数量
  const StorageUsage({
    required this.totalSize,
    required this.nodesCount,
    required this.graphsCount,
  });

  /// 从 JSON 创建
  factory StorageUsage.fromJson(Map<String, dynamic> json) => StorageUsage(
        totalSize: json['totalSize'] as int,
        nodesCount: json['nodesCount'] as int,
        graphsCount: json['graphsCount'] as int,
      );

  /// 总大小（字节）
  final int totalSize;

  /// 节点数量
  final int nodesCount;

  /// 图数量
  final int graphsCount;

  /// 格式化大小显示
  ///
  /// 将字节数转换为人类可读的格式（B、KB、MB、GB）
  String get formattedSize {
    if (totalSize < 1024) {
      return '$totalSize B';
    } else if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    } else if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }

  /// 转换为 JSON（用于序列化）
  Map<String, dynamic> toJson() => {
        'totalSize': totalSize,
        'nodesCount': nodesCount,
        'graphsCount': graphsCount,
        'formattedSize': formattedSize,
      };
}
