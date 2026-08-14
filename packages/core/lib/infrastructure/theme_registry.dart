import 'package:flutter/material.dart';

/// 主题扩展定义
///
/// 插件可以注册额外的主题颜色或样式
/// 这些扩展将与基础主题合并，形成最终的主题
class ThemeExtension {
  /// 创建主题扩展
  const ThemeExtension({
    required this.id,
    required this.displayName,
    this.lightColors = const {},
    this.darkColors = const {},
    this.customData = const {},
  });

  /// 从 JSON 创建
  factory ThemeExtension.fromJson(Map<String, dynamic> json) => ThemeExtension(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        lightColors: (json['lightColors'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, Color(value as int)),
        ),
        darkColors: (json['darkColors'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, Color(value as int)),
        ),
        customData: json['customData'] as Map<String, dynamic>? ?? {},
      );

  /// 主题扩展 ID（如 "ai", "graph"）
  ///
  /// 必须全局唯一，建议使用插件前缀
  final String id;

  /// 显示名称（用于主题设置 UI）
  final String displayName;

  /// 亮色主题颜色
  ///
  /// 键为颜色名称（如 "primary", "secondary"），值为颜色
  final Map<String, Color> lightColors;

  /// 暗色主题颜色
  ///
  /// 键为颜色名称（如 "primary", "secondary"），值为颜色
  final Map<String, Color> darkColors;

  /// 自定义主题数据
  ///
  /// 插件可以存储任意自定义数据
  final Map<String, dynamic> customData;

  /// 获取亮色主题的颜色
  Color? getLightColor(String key) => lightColors[key];

  /// 获取暗色主题的颜色
  Color? getDarkColor(String key) => darkColors[key];

  /// 根据亮度获取颜色
  Color? getColor(String key, {bool isDark = false}) => isDark ? getDarkColor(key) : getLightColor(key);

  /// 获取自定义数据
  T? getCustomData<T>(String key) => customData[key] as T?;

  /// 复制并修改属性
  ThemeExtension copyWith({
    String? id,
    String? displayName,
    Map<String, Color>? lightColors,
    Map<String, Color>? darkColors,
    Map<String, dynamic>? customData,
  }) => ThemeExtension(
        id: id ?? this.id,
        displayName: displayName ?? this.displayName,
        lightColors: lightColors ?? this.lightColors,
        darkColors: darkColors ?? this.darkColors,
        customData: customData ?? this.customData,
      );

  /// 转换为 JSON（用于序列化）
  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'lightColors': lightColors.map(
          (key, value) => MapEntry(key, value.toARGB32()),
        ),
        'darkColors': darkColors.map(
          (key, value) => MapEntry(key, value.toARGB32()),
        ),
        'customData': customData,
      };
}

/// 主题注册表
///
/// 允许插件注册主题扩展，自定义应用外观
///
/// ### 设计理念
///
/// 1. **插件可扩展性**：插件通过 `register()` 方法注册主题扩展
/// 2. **响应式更新**：继承 `ChangeNotifier`，主题变化时通知监听器
/// 3. **类型安全**：通过 `getExtensions()` 和 `getExtension()` 提供类型安全访问
/// 4. **亮色/暗色支持**：分别管理亮色和暗色主题的颜色
///
/// ### 使用示例
///
/// ```dart
/// // 在插件的 onLoad() 中注册主题扩展
/// context.themeRegistry.register(ThemeExtension(
///   id: 'myPlugin',
///   displayName: '我的插件主题',
///   lightColors: {
///     'primary': Color(0xFF2196F3),
///     'secondary': Color(0xFF64B5F6),
///   },
///   darkColors: {
///     'primary': Color(0xFF1976D2),
///     'secondary': Color(0xFF42A5F5),
///   },
/// ));
///
/// // 在代码中获取扩展
/// final extension = context.themeRegistry.getExtension('myPlugin');
/// final primaryColor = extension?.getLightColor('primary');
/// ```
class ThemeRegistry with ChangeNotifier {
  /// 所有已注册的主题扩展
  ///
  /// 键为扩展 ID
  final Map<String, ThemeExtension> _extensions = {};

  /// 注册主题扩展
  ///
  /// ### 参数
  /// - `extension` - 主题扩展
  ///
  /// ### 注意事项
  /// - 扩展 ID 必须全局唯一，建议使用插件前缀（如 "ai", "graph"）
  /// - 如果 ID 已存在，将覆盖现有的扩展
  void register(ThemeExtension extension) {
    _extensions[extension.id] = extension;
    notifyListeners();
  }

  /// 批量注册主题扩展
  ///
  /// 用于一次性注册多个扩展
  void registerAll(List<ThemeExtension> extensions) {
    for (final extension in extensions) {
      _extensions[extension.id] = extension;
    }
    notifyListeners();
  }

  /// 注销主题扩展
  ///
  /// ### 参数
  /// - `id` - 扩展 ID
  ///
  /// 如果扩展不存在，什么都不做
  void unregister(String id) {
    if (_extensions.remove(id) != null) {
      notifyListeners();
    }
  }

  /// 获取主题扩展
  ///
  /// ### 参数
  /// - `id` - 扩展 ID
  ///
  /// ### 返回
  /// 主题扩展，如果不存在返回 `null`
  ThemeExtension? getExtension(String id) => _extensions[id];

  /// 检查扩展是否已注册
  bool isRegistered(String id) => _extensions.containsKey(id);

  /// 获取所有扩展
  List<ThemeExtension> get extensions => _extensions.values.toList();

  /// 获取所有扩展 ID
  List<String> get extensionIds => _extensions.keys.toList();

  /// 获取所有亮色主题的颜色
  ///
  /// 合并所有扩展的亮色主题颜色
  ///
  /// ### 返回
  /// 键为颜色名称，值为颜色的映射
  Map<String, Color> getAllLightColors() {
    final allColors = <String, Color>{};
    for (final extension in _extensions.values) {
      allColors.addAll(extension.lightColors);
    }
    return allColors;
  }

  /// 获取所有暗色主题的颜色
  ///
  /// 合并所有扩展的暗色主题颜色
  ///
  /// ### 返回
  /// 键为颜色名称，值为颜色的映射
  Map<String, Color> getAllDarkColors() {
    final allColors = <String, Color>{};
    for (final extension in _extensions.values) {
      allColors.addAll(extension.darkColors);
    }
    return allColors;
  }

  /// 根据亮度获取所有颜色
  ///
  /// ### 参数
  /// - `isDark` - 是否为暗色主题
  Map<String, Color> getAllColors({bool isDark = false}) => isDark ? getAllDarkColors() : getAllLightColors();

  /// 获取特定颜色的值
  ///
  /// ### 参数
  /// - `key` - 颜色名称
  /// - `isDark` - 是否为暗色主题
  ///
  /// ### 返回
  /// 颜色值，如果不存在返回 `null`
  Color? getColor(String key, {bool isDark = false}) {
    for (final extension in _extensions.values) {
      final color = extension.getColor(key, isDark: isDark);
      if (color != null) {
        return color;
      }
    }
    return null;
  }

  /// 合并所有扩展到基础 ThemeData
  ///
  /// ### 参数
  /// - `base` - 基础主题数据
  /// - `isDark` - 是否为暗色主题
  ///
  /// ### 返回
  /// 合并后的主题数据
  ///
  /// ### 注意
  /// 此方法会复制基础主题，并添加所有扩展的颜色
  /// 扩展颜色通过 `Theme.of(context).extensions` 访问
  ThemeData mergeExtensions(ThemeData base, {bool isDark = false}) {
    var theme = base;

    // 合并颜色到 ColorScheme
    final allColors = getAllColors(isDark: isDark);
    if (allColors.isNotEmpty) {
      theme = theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          // 插件可以定义自己的颜色槽位
          // 这里使用 copyWith 的扩展机制
        ),
      );
    }

    // 注意：当前的自定义 ThemeExtension 类与 Flutter 的 ThemeExtension<T> 系统不兼容
    // 这里暂时不合并扩展到 ThemeData.extensions 中
    //
    // 未来改进：重构 ThemeExtension 以继承 Flutter 的 ThemeExtension<T> 基类
    // 这需要：
    // 1. 为每个插件创建具体的 ThemeExtension 子类
    // 2. 实现 lerp、copyWith 和 == 方法
    // 3. 更新 ThemeRegistry 以支持泛型扩展
    //
    // 如果需要使用注册的扩展颜色，请使用：
    // - registry.getColor(key, isDark: true/false) - 获取单个颜色
    // - registry.getAllColors(isDark: true/false) - 获取所有颜色
    // 然后手动将颜色应用到主题的 colorScheme 中

    return theme;
  }

  /// 导出所有扩展为 JSON
  ///
  /// 用于备份或调试
  Map<String, dynamic> exportToJson() {
    final json = <String, dynamic>{};
    for (final entry in _extensions.entries) {
      json[entry.key] = entry.value.toJson();
    }
    return json;
  }

  /// 从 JSON 导入扩展
  ///
  /// ### 参数
  /// - `json` - JSON 对象
  ///
  /// ### 注意
  /// - 只导入格式正确的扩展
  /// - 如果 ID 已存在，将覆盖现有的扩展
  void importFromJson(Map<String, dynamic> json) {
    for (final entry in json.entries) {
      try {
        final extension = ThemeExtension.fromJson(
          entry.value as Map<String, dynamic>,
        );
        register(extension);
      } catch (_) {
        // 忽略格式错误的扩展
      }
    }
  }

  /// 清除所有扩展
  void clear() {
    _extensions.clear();
    notifyListeners();
  }

  /// 获取扩展统计信息
  ///
  /// 返回注册表的统计信息，用于调试
  Map<String, dynamic> get statistics => {
      'totalExtensions': _extensions.length,
      'extensionIds': extensionIds,
      'totalLightColors': getAllLightColors().length,
      'totalDarkColors': getAllDarkColors().length,
    };

  /// 根据插件 ID 获取扩展
  ///
  /// 假设扩展 ID 使用插件前缀（如 "ai.primary"）
  /// 返回属于特定插件的所有扩展
  List<ThemeExtension> getExtensionsByPlugin(String pluginId) => _extensions.values
        .where((ext) => ext.id.startsWith('$pluginId.'))
        .toList();

  /// 移除插件的所有扩展
  ///
  /// ### 参数
  /// - `pluginId` - 插件 ID
  ///
  /// 移除所有以 "{pluginId}." 开头的扩展
  void removePluginExtensions(String pluginId) {
    final toRemove = getExtensionsByPlugin(pluginId);
    for (final ext in toRemove) {
      _extensions.remove(ext.id);
    }
    if (toRemove.isNotEmpty) {
      notifyListeners();
    }
  }
}
