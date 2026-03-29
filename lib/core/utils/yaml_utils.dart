/// YAML 解析工具类
///
/// 提供简单的 YAML 解析功能，用于解析 Markdown frontmatter 和配置文件。
///
/// ## 功能特性
///
/// - 支持嵌套对象解析
/// - 支持列表解析（包括对象列表）
/// - 自动类型转换（布尔值、数字、字符串、数组）
/// - 处理缩进和层级关系
/// - 跳过空行和注释
///
/// ## 使用示例
///
/// ```dart
/// final yaml = '''
/// name: My Project
/// version: 1.0.0
/// tags:
///   - important
///   - work
/// settings:
///   enabled: true
///   count: 42
/// ''';
///
/// final result = YamlUtils.parse(yaml);
/// print(result['name']); // 'My Project'
/// print(result['settings']['enabled']); // true
/// ```
///
/// ## 限制
///
/// 这是一个简化的 YAML 解析器，不支持：
/// - 多行字符串
/// - 锚点和别名
/// - 复杂的流式语法
/// - 自定义类型标签
///
/// 对于复杂的 YAML 文件，建议使用完整的 YAML 库。
library;

/// YAML 解析工具类
class YamlUtils {
  YamlUtils._();

  /// 解析 YAML 字符串为 Map
  ///
  /// [yaml] YAML 格式的字符串
  ///
  /// 返回解析后的键值对 Map
  ///
  /// ## 示例
  /// ```dart
  /// final yaml = '''
  /// key1: value1
  /// key2: 123
  /// nested:
  ///   subkey: value
  /// ''';
  /// final result = YamlUtils.parse(yaml);
  /// ```
  static Map<String, dynamic> parse(String yaml) {
    final result = <String, dynamic>{};
    final lines = yaml.split('\n');
    _parseYamlBlock(lines, 0, result);
    return result;
  }

  /// 递归解析 YAML 块
  ///
  /// [lines] YAML 内容的行列表
  /// [startIndex] 开始解析的行索引
  /// [output] 输出结果的 Map
  ///
  /// 返回处理到的行索引（用于递归调用）
  static int _parseYamlBlock(
    List<String> lines,
    int startIndex,
    Map<String, dynamic> output,
  ) {
    var i = startIndex;
    int? baseIndent;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Skip empty lines and comments
      if (trimmed.isEmpty || trimmed.startsWith('#')) {
        i++;
        continue;
      }

      // Stop at frontmatter delimiter
      if (trimmed == '---') {
        break;
      }

      final indent = line.length - line.trimLeft().length;
      baseIndent ??= indent;

      // 如果缩进小于基础缩进，说明到了上一层
      if (indent < baseIndent) {
        break;
      }

      final match = RegExp(r'^([^:]+):\s*(.*)$').firstMatch(trimmed);

      if (match != null) {
        final key = match.group(1)!.trim();
        final valueStr = match.group(2)!.trim();

        if (valueStr.isEmpty) {
          // 可能是嵌套对象或列表，需要向前看
          i++;
          if (i >= lines.length) break;

          final nextLine = lines[i];
          if (nextLine.trim().startsWith('-')) {
            // 这是一个列表
            final list = <dynamic>[];
            while (i < lines.length) {
              if (lines[i].trim().isEmpty || lines[i].trim().startsWith('#')) {
                i++;
                continue;
              }
              final nextIndent = lines[i].length - lines[i].trimLeft().length;
              if (nextIndent <= baseIndent) break;

              final itemTrimmed = lines[i].trim();
              if (!itemTrimmed.startsWith('-')) break;

              final itemContent = itemTrimmed.substring(1).trim();
              final itemMatch = RegExp(
                r'^([^:]+):\s*(.*)$',
              ).firstMatch(itemContent);

              if (itemMatch != null) {
                // 列表项是对象
                final itemMap = <String, dynamic>{};
                final itemKey = itemMatch.group(1)!.trim();
                final itemValue = itemMatch.group(2)!.trim();
                itemMap[itemKey] = _parseYamlValue(itemValue);

                // 检查是否有更多属性
                i++;
                while (i < lines.length) {
                  if (lines[i].trim().isEmpty) {
                    i++;
                    continue;
                  }
                  final attrIndent =
                      lines[i].length - lines[i].trimLeft().length;
                  if (attrIndent <= nextIndent) break;

                  final attrMatch = RegExp(
                    r'^([^:]+):\s*(.*)$',
                  ).firstMatch(lines[i].trim());
                  if (attrMatch != null) {
                    final attrKey = attrMatch.group(1)!.trim();
                    final attrValue = attrMatch.group(2)!.trim();
                    itemMap[attrKey] = _parseYamlValue(attrValue);
                  }
                  i++;
                }
                list.add(itemMap);
              } else {
                // 简单值
                list.add(_parseYamlValue(itemContent));
                i++;
              }
            }
            output[key] = list;
          } else {
            // 这是一个嵌套对象
            final nestedMap = <String, dynamic>{};
            i = _parseYamlBlock(lines, i, nestedMap);
            output[key] = nestedMap;
          }
        } else {
          // 简单值
          output[key] = _parseYamlValue(valueStr);
          i++;
        }
      } else {
        i++;
      }
    }

    return i;
  }

  /// 解析 YAML 值的类型
  ///
  /// 支持的类型：
  /// - 布尔值: true/false
  /// - 数字: 整数和浮点数
  /// - 带引号的字符串: "string" 或 'string'
  /// - 数组: [a, b, c]
  /// - 普通字符串
  ///
  /// [value] 要解析的值字符串
  /// 返回解析后的值（布尔、数字、列表或字符串）
  static dynamic _parseYamlValue(String value) {
    // 布尔值
    if (value == 'true') return true;
    if (value == 'false') return false;

    // 数字
    final parsedNum = num.tryParse(value);
    if (parsedNum != null) return parsedNum;

    // 带引号的字符串
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      return value.substring(1, value.length - 1);
    }

    // 数组格式 [a, b, c]
    if (value.startsWith('[') && value.endsWith(']')) {
      final items = value.substring(1, value.length - 1).split(',');
      return items.map((e) => e.trim()).toList();
    }

    // 默认返回字符串
    return value;
  }
}
