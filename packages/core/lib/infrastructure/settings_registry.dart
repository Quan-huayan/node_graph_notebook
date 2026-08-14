import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置定义
///
/// 描述一个设置项的结构和行为
/// 插件通过此类注册自定义设置项
class SettingDefinition<T> {
  /// 创建设置定义
  const SettingDefinition({
    required this.key,
    required this.defaultValue,
    required this.displayName,
    required this.description,
    this.validator,
    this.onChanged,
    this.isSensitive = false,
    required this.category,
  });

  /// 设置键（全局唯一，建议使用插件前缀，如 "ai.provider"）
  final String key;

  /// 默认值
  final T defaultValue;

  /// 显示名称（用于设置 UI）
  final String displayName;

  /// 描述（用于设置 UI 的帮助文本）
  final String description;

  /// 验证函数（可选）
  ///
  /// 在设置值之前调用，如果验证失败应返回默认值或抛出异常
  final T Function(T value)? validator;

  /// 值变化回调（可选）
  ///
  /// 当设置值改变时调用
  final void Function(T value)? onChanged;

  /// 是否敏感信息（如 API Key，存储时加密）
  final bool isSensitive;

  /// 设置分组（用于 UI 分组显示）
  final String category;
}

/// 设置注册表
///
/// 允许插件注册自己的设置项
/// 统一管理所有设置的持久化和访问
///
/// ### 设计理念
///
/// 1. **插件可扩展性**：插件通过 `register()` 方法注册自定义设置
/// 2. **类型安全**：通过泛型 `get<T>()` 和 `set<T>()` 提供类型安全
/// 3. **响应式更新**：继承 `ChangeNotifier`，设置变化时通知监听器
/// 4. **敏感数据保护**：支持敏感信息加密存储
/// 5. **验证机制**：支持自定义验证函数
///
/// ### 使用示例
///
/// ```dart
/// // 在插件的 onLoad() 中注册设置
/// context.settingsRegistry.register(SettingDefinition<String>(
///   key: 'myPlugin.featureEnabled',
///   defaultValue: 'true',
///   displayName: '启用功能',
///   description: '是否启用此功能',
///   category: '我的插件',
///   validator: (value) => ['true', 'false'].contains(value) ? value : 'true',
/// ));
///
/// // 在代码中读取设置
/// final enabled = context.settingsRegistry.get<bool>('myPlugin.featureEnabled');
///
/// // 在代码中更新设置
/// await context.settingsRegistry.set('myPlugin.featureEnabled', false);
/// ```
class SettingsRegistry with ChangeNotifier {
  /// 创建设置注册表
  SettingsRegistry(this._prefs);

  /// SharedPreferences 实例
  final SharedPreferences _prefs;

  /// 所有已注册的设置定义
  final Map<String, SettingDefinition> _definitions = {};

  /// 设置值缓存
  ///
  /// 用于快速访问和监听变化
  final Map<String, dynamic> _cache = {};

  /// 加密密钥（用于敏感信息）
  ///
  /// 注意：这是一个简单的实现，生产环境应使用更安全的密钥管理
  static const String _encryptionKey = 'node_graph_notebook_encryption_key';

  /// 注册设置项
  ///
  /// 插件在 `onLoad()` 时调用此方法注册其设置
  ///
  /// ### 参数
  /// - `definition` - 设置定义，包含键、默认值、验证器等
  ///
  /// ### 注意事项
  /// - 设置键必须全局唯一，建议使用插件前缀（如 "ai.provider"）
  /// - 如果键已存在，将抛出 `ArgumentError`
  /// - 注册后会立即从 SharedPreferences 加载值（如果存在）
  void register<T>(SettingDefinition<T> definition) {
    if (_definitions.containsKey(definition.key)) {
      throw ArgumentError('Setting already registered: ${definition.key}');
    }

    _definitions[definition.key] = definition;

    // 从 SharedPreferences 加载值，如果没有则使用默认值
    final value = _loadValue(definition.key, definition.defaultValue);
    _cache[definition.key] = value;
  }

  /// 批量注册设置项
  ///
  /// 用于一次性注册多个设置
  void registerAll(List<SettingDefinition> definitions) {
    definitions.forEach(register);
  }

  /// 获取设置值
  ///
  /// ### 泛型参数
  /// - `T` - 设置值的类型
  ///
  /// ### 参数
  /// - `key` - 设置键
  ///
  /// ### 返回
  /// 当前设置值
  ///
  /// ### 抛出
  /// - `ArgumentError` 如果设置未注册
  T get<T>(String key) {
    if (!_definitions.containsKey(key)) {
      throw ArgumentError('Setting not registered: $key');
    }
    return _cache[key] as T;
  }

  /// 获取设置值（带默认值）
  ///
  /// 如果设置未注册或不存在，返回默认值
  T getOrElse<T>(String key, T defaultValue) {
    try {
      return get<T>(key);
    } catch (_) {
      return defaultValue;
    }
  }

  /// 设置值
  ///
  /// ### 参数
  /// - `key` - 设置键
  /// - `value` - 新值
  ///
  /// ### 抛出
  /// - `ArgumentError` 如果设置未注册
  /// - 任何验证器抛出的异常
  Future<void> set<T>(String key, T value) async {
    final definition = _definitions[key] as SettingDefinition<T>?;

    if (definition == null) {
      throw ArgumentError('Setting not registered: $key');
    }

    // 验证值
    final validatedValue = definition.validator != null
        ? definition.validator!(value)
        : value;

    // 更新缓存
    final oldValue = _cache[key];
    _cache[key] = validatedValue;

    // 持久化
    if (definition.isSensitive) {
      // 加密存储敏感信息
      await _prefs.setString('secure_$key', _encrypt(validatedValue.toString()));
    } else {
      await _saveValue(key, validatedValue);
    }

    // 触发回调（仅当值真正改变时）
    if (oldValue != validatedValue) {
      definition.onChanged?.call(validatedValue);
      notifyListeners();
    }
  }

  /// 检查设置是否已注册
  bool isRegistered(String key) => _definitions.containsKey(key);

  /// 获取所有注册的设置定义
  List<SettingDefinition> get definitions => _definitions.values.toList();

  /// 获取特定分组的设置
  ///
  /// ### 参数
  /// - `category` - 分组名称
  ///
  /// ### 返回
  /// 该分组下的所有设置定义
  List<SettingDefinition> getByCategory(String category) => _definitions.values
        .where((d) => d.category == category)
        .toList();

  /// 获取所有分组名称
  ///
  /// 返回已注册设置的所有分组名称列表（去重）
  List<String> get categories {
    final cats = _definitions.values
        .map((d) => d.category)
        .toSet()
        .toList()
    ..sort();
    return cats;
  }

  /// 重置设置为默认值
  ///
  /// ### 参数
  /// - `key` - 设置键
  ///
  /// 如果设置未注册，什么都不做
  Future<void> reset(String key) async {
    final definition = _definitions[key];
    if (definition == null) return;

    await set(key, definition.defaultValue);
  }

  /// 重置所有设置为默认值
  Future<void> resetAll() async {
    for (final key in _definitions.keys) {
      await reset(key);
    }
  }

  /// 清除设置值（从持久化存储中删除）
  ///
  /// ### 参数
  /// - `key` - 设置键
  ///
  /// 下次访问将返回默认值
  Future<void> clear(String key) async {
    if (!_definitions.containsKey(key)) return;

    final definition = _definitions[key];
    await _prefs.remove(key);
    if (definition!.isSensitive) {
      await _prefs.remove('secure_$key');
    }

    final defaultValue = definition.defaultValue;
    _cache[key] = defaultValue;
    notifyListeners();
  }

  /// 从 SharedPreferences 加载值
  ///
  /// ### 参数
  /// - `key` - 设置键
  /// - `defaultValue` - 默认值（用于推断类型）
  ///
  /// ### 返回
  /// 加载的值或默认值
  T _loadValue<T>(String key, T defaultValue) {
    final definition = _definitions[key];
    if (definition != null && definition.isSensitive) {
      // 加载敏感信息
      final encrypted = _prefs.getString('secure_$key');
      if (encrypted != null && encrypted.isNotEmpty) {
        final decrypted = _decrypt(encrypted);
        return _parseValue<T>(decrypted, defaultValue);
      }
      return defaultValue;
    }

    // 加载普通值
    if (defaultValue is String) {
      return (_prefs.getString(key) ?? defaultValue) as T;
    } else if (defaultValue is int) {
      return (_prefs.getInt(key) ?? defaultValue) as T;
    } else if (defaultValue is double) {
      return (_prefs.getDouble(key) ?? defaultValue) as T;
    } else if (defaultValue is bool) {
      return (_prefs.getBool(key) ?? defaultValue) as T;
    } else if (defaultValue is List<String>) {
      return (_prefs.getStringList(key) ?? defaultValue) as T;
    }

    return defaultValue;
  }

  /// 保存值到 SharedPreferences
  ///
  /// ### 参数
  /// - `key` - 设置键
  /// - `value` - 要保存的值
  Future<void> _saveValue<T>(String key, T value) async {
    if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    } else if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is List<String>) {
      await _prefs.setStringList(key, value);
    } else {
      // 其他类型转换为字符串存储
      await _prefs.setString(key, value.toString());
    }
  }

  /// 解析字符串值为目标类型
  ///
  /// ### 参数
  /// - `value` - 字符串值
  /// - `defaultValue` - 默认值（用于推断类型）
  ///
  /// ### 返回
  /// 解析后的值
  T _parseValue<T>(String value, T defaultValue) {
    if (defaultValue is String) {
      return value as T;
    } else if (defaultValue is int) {
      return int.tryParse(value) as T? ?? defaultValue;
    } else if (defaultValue is double) {
      return double.tryParse(value) as T? ?? defaultValue;
    } else if (defaultValue is bool) {
      return (value.toLowerCase() == 'true') as T;
    }
    return defaultValue;
  }

  /// 加密字符串
  ///
  /// 使用简单的 XOR 加密（生产环境应使用更安全的加密方式）
  ///
  /// ### 参数
  /// - `value` - 要加密的字符串
  ///
  /// ### 返回
  /// Base64 编码的加密字符串
  String _encrypt(String value) {
    final keyBytes = utf8.encode(_encryptionKey);
    final valueBytes = utf8.encode(value);

    final encrypted = List<int>.generate(
      valueBytes.length,
      (i) => valueBytes[i] ^ keyBytes[i % keyBytes.length],
    );

    return base64.encode(encrypted);
  }

  /// 解密字符串
  ///
  /// ### 参数
  /// - `encrypted` - Base64 编码的加密字符串
  ///
  /// ### 返回
  /// 解密后的原始字符串
  String _decrypt(String encrypted) {
    try {
      final keyBytes = utf8.encode(_encryptionKey);
      final encryptedBytes = base64.decode(encrypted);

      final decrypted = List<int>.generate(
        encryptedBytes.length,
        (i) => encryptedBytes[i] ^ keyBytes[i % keyBytes.length],
      );

      return utf8.decode(decrypted);
    } catch (_) {
      // 解密失败，返回空字符串
      return '';
    }
  }

  /// 导出所有设置为 JSON
  ///
  /// 用于备份或调试
  Map<String, dynamic> exportToJson() {
    final json = <String, dynamic>{};

    for (final entry in _cache.entries) {
      final definition = _definitions[entry.key];
      if (definition != null && !definition.isSensitive) {
        json[entry.key] = entry.value;
      } else {
        // 敏感信息不导出实际值
        json[entry.key] = '[REDACTED]';
      }
    }

    return json;
  }

  /// 从 JSON 导入设置
  ///
  /// ### 参数
  /// - `json` - JSON 对象
  ///
  /// ### 注意
  /// - 只导入已注册的设置
  /// - 敏感信息不会被导入
  Future<void> importFromJson(Map<String, dynamic> json) async {
    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;

      if (_definitions.containsKey(key) && value != '[REDACTED]') {
        final definition = _definitions[key];
        if (definition != null && !definition.isSensitive) {
          try {
            await set(key, value);
          } catch (_) {
            // 忽略类型不匹配或验证失败
          }
        }
      }
    }
  }

  /// 获取设置统计信息
  ///
  /// 返回注册表的统计信息，用于调试
  Map<String, dynamic> get statistics => {
      'totalSettings': _definitions.length,
      'categories': categories.length,
      'sensitiveSettings': _definitions.values
          .where((d) => d.isSensitive)
          .length,
      'categoryBreakdown': {
        for (final category in categories)
          category: getByCategory(category).length,
      },
    };
}
