# Bug Report: utils 文件夹

## 文件位置
`lib/core/utils/`

---

## Bug 1: SafeCallback 类型转换掩盖真实错误

### 文件
`lib/core/utils/safe_callback.dart`

### 位置
第 33、67、104、141 行

### 问题描述
`SafeCallback` 的所有方法中使用 `result as T?` 进行类型转换。当回调返回的类型与泛型 `T` 不兼容时，会抛出 `TypeError`，但这个异常会被 `catch` 块捕获，导致返回 `fallbackValue` 而不是暴露类型错误。

### 问题代码
```dart
static T? call<T>({
  dynamic Function()? callback,
  void Function(dynamic error)? onError,
  T? fallbackValue,
}) {
  if (callback == null) {
    return fallbackValue;
  }

  try {
    final result = callback();
    return result as T?;  // 类型转换失败会被 catch 捕获
  } catch (e) {
    const AppLogger('SafeCallback').warning('Callback failed', error: e);
    onError?.call(e);
    return fallbackValue;  // 返回 fallbackValue 而不是暴露类型错误
  }
}
```

### 影响
1. **掩盖类型错误**：开发者无法在开发阶段发现类型不匹配问题
2. **调试困难**：运行时得到的是 fallbackValue 而不是明确的类型错误
3. **潜在数据丢失**：类型转换失败时静默返回 fallbackValue

### 示例
```dart
// 回调返回 int，但泛型声明为 String
final result = SafeCallback.call<String>(
  callback: () => 42,  // 返回 int
  fallbackValue: 'default',
);
print(result);  // 输出 'default'，而不是抛出类型错误
```

### 建议修复
区分类型错误和其他运行时错误：
```dart
static T? call<T>({
  dynamic Function()? callback,
  void Function(dynamic error)? onError,
  T? fallbackValue,
}) {
  if (callback == null) {
    return fallbackValue;
  }

  try {
    final result = callback();
    if (result is T?) {
      return result;
    } else {
      throw TypeError();
    }
  } on TypeError {
    rethrow;  // 类型错误应该暴露给调用者
  } catch (e) {
    const AppLogger('SafeCallback').warning('Callback failed', error: e);
    onError?.call(e);
    return fallbackValue;
  }
}
```

---

## Bug 2: YAML 列表解析时空行/注释导致错误解析

### 文件
`lib/core/utils/yaml_utils.dart`

### 位置
第 115-179 行

### 问题描述
当解析列表时，如果键后面第一个列表项前面有空行或注释，解析器会错误地将其判断为嵌套对象而非列表。

### 问题代码
```dart
if (valueStr.isEmpty) {
  i++;
  if (i >= lines.length) break;

  final nextLine = lines[i];
  if (nextLine.trim().startsWith('-')) {
    // 列表解析...
  } else {
    // 嵌套对象解析
    final nestedMap = <String, dynamic>{};
    i = _parseYamlBlock(lines, i, nestedMap);
    output[key] = nestedMap;
  }
}
```

### 影响
以下 YAML 会被错误解析：
```yaml
items:

  - item1
  - item2
```
会被错误解析为嵌套对象而非列表。

### 建议修复
在判断列表前先跳过空行和注释：
```dart
if (valueStr.isEmpty) {
  i++;
  if (i >= lines.length) break;

  // 跳过空行和注释
  while (i < lines.length && 
         (lines[i].trim().isEmpty || lines[i].trim().startsWith('#'))) {
    i++;
  }
  if (i >= lines.length) break;

  final nextLine = lines[i];
  if (nextLine.trim().startsWith('-')) {
    // 列表解析...
  } else {
    // 嵌套对象解析...
  }
}
```

---

## Bug 3: YAML 键值对在文件末尾时丢失

### 文件
`lib/core/utils/yaml_utils.dart`

### 位置
第 115-117 行

### 问题描述
当键后面没有值且已经到达文件末尾时，`output[key]` 不会被设置，导致键值对丢失。

### 问题代码
```dart
if (valueStr.isEmpty) {
  i++;
  if (i >= lines.length) break;  // 直接 break，output[key] 未设置
  // ...
}
```

### 影响
以下 YAML 会丢失 `items` 键：
```yaml
name: test
items:
```
解析结果中不会有 `items` 键。

### 建议修复
在 break 前设置默认值：
```dart
if (valueStr.isEmpty) {
  i++;
  if (i >= lines.length) {
    output[key] = null;  // 或 output[key] = <String, dynamic>{};
    break;
  }
  // ...
}
```

---

## Bug 4: YAML 列表项属性解析不跳过注释

### 文件
`lib/core/utils/yaml_utils.dart`

### 位置
第 148-166 行

### 问题描述
在解析列表项的额外属性时，只跳过空行但不跳过注释行，与列表项解析逻辑不一致。

### 问题代码
```dart
// 检查是否有更多属性
i++;
while (i < lines.length) {
  if (lines[i].trim().isEmpty) {  // 只检查空行
    i++;
    continue;
  }
  // ...
}
```

### 影响
以下 YAML 会解析失败：
```yaml
items:
  - name: John
    # 这是注释
    age: 30
```
`age: 30` 可能不会被正确解析为 `name: John` 的属性。

### 建议修复
与第 124-127 行保持一致，跳过注释行：
```dart
while (i < lines.length) {
  if (lines[i].trim().isEmpty || lines[i].trim().startsWith('#')) {
    i++;
    continue;
  }
  // ...
}
```

---

## Bug 5: YAML 空数组解析错误

### 文件
`lib/core/utils/yaml_utils.dart`

### 位置
第 220-224 行

### 问题描述
空数组 `[]` 会被错误地解析为 `['']`（包含一个空字符串的列表），而不是空列表 `[]`。

### 问题代码
```dart
if (value.startsWith('[') && value.endsWith(']')) {
  final items = value.substring(1, value.length - 1).split(',');
  return items.map((e) => e.trim()).toList();
}
```

### 影响
```dart
final result = YamlUtils.parse('items: []');
print(result['items']);  // 输出 [''] 而不是 []
```

### 建议修复
```dart
if (value.startsWith('[') && value.endsWith(']')) {
  final content = value.substring(1, value.length - 1).trim();
  if (content.isEmpty) {
    return <dynamic>[];
  }
  final items = content.split(',');
  return items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
}
```

---

## Bug 6: YAML 数组中引号内的逗号被错误分割

### 文件
`lib/core/utils/yaml_utils.dart`

### 位置
第 220-224 行

### 问题描述
当数组元素包含引号内的逗号时，解析器会在逗号处错误分割。

### 问题代码
```dart
if (value.startsWith('[') && value.endsWith(']')) {
  final items = value.substring(1, value.length - 1).split(',');
  return items.map((e) => e.trim()).toList();
}
```

### 影响
```yaml
items: ["a, b", "c, d"]
```
会被错误解析为 `['"a', 'b"', '"c', 'd"']` 而不是 `['a, b', 'c, d']`。

### 建议修复
实现更智能的分割逻辑，考虑引号内的内容：
```dart
static List<dynamic> _parseArray(String value) {
  final content = value.substring(1, value.length - 1).trim();
  if (content.isEmpty) return <dynamic>[];
  
  final items = <String>[];
  var current = StringBuffer();
  var inQuotes = false;
  var quoteChar = '';
  
  for (var i = 0; i < content.length; i++) {
    final char = content[i];
    if ((char == '"' || char == "'") && !inQuotes) {
      inQuotes = true;
      quoteChar = char;
    } else if (char == quoteChar && inQuotes) {
      inQuotes = false;
    }
    
    if (char == ',' && !inQuotes) {
      items.add(current.toString().trim());
      current = StringBuffer();
    } else {
      current.write(char);
    }
  }
  items.add(current.toString().trim());
  
  return items.where((e) => e.isNotEmpty).toList();
}
```

---

## Bug 7: YAML 数组末尾逗号产生空元素

### 文件
`lib/core/utils/yaml_utils.dart`

### 位置
第 220-224 行

### 问题描述
数组末尾的逗号会被视为空元素，产生意外的空字符串。

### 问题代码
```dart
if (value.startsWith('[') && value.endsWith(']')) {
  final items = value.substring(1, value.length - 1).split(',');
  return items.map((e) => e.trim()).toList();
}
```

### 影响
```yaml
items: [a, b, c,]
```
会被解析为 `['a', 'b', 'c', '']` 而不是 `['a', 'b', 'c']`。

### 建议修复
在 Bug 5 的修复中已包含过滤空元素的逻辑：
```dart
return items.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
```

---

## 总结

| Bug | 文件 | 严重程度 | 影响范围 |
|-----|------|---------|---------|
| Bug 1 | safe_callback.dart | 高 | 类型安全 |
| Bug 2 | yaml_utils.dart | 高 | YAML 解析正确性 |
| Bug 3 | yaml_utils.dart | 中 | 数据完整性 |
| Bug 4 | yaml_utils.dart | 中 | YAML 解析一致性 |
| Bug 5 | yaml_utils.dart | 中 | YAML 解析正确性 |
| Bug 6 | yaml_utils.dart | 中 | YAML 解析正确性 |
| Bug 7 | yaml_utils.dart | 低 | YAML 解析正确性 |
