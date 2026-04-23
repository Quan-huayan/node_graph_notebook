# Bug Report: lib/utils 文件夹

## 文件位置
`lib/utils/`

---

## Bug 1: Vector2 缺少 `==` 运算符和 `hashCode` 重写

### 文件
`lib/utils/types.dart`

### 位置
第 6-60 行（整个 `Vector2` 类）

### 问题描述
`Vector2` 作为值类型类，没有重写 `==` 运算符和 `hashCode`。Dart 默认使用引用相等性（`identical`），导致两个具有相同坐标值的 `Vector2` 实例不相等。

### 问题代码
```dart
class Vector2 {
  final double x;
  final double y;
  const Vector2(this.x, this.y);
  // ... 没有 operator == 和 hashCode 重写
}
```

### 影响
1. **值比较失败**：`Vector2(1, 2) == Vector2(1, 2)` 返回 `false`
2. **静态常量比较失败**：`Vector2.zero == Vector2(0, 0)` 返回 `false`
3. **Map 和 Set 行为异常**：以 `Vector2` 为键的 Map 或 Set 无法正确去重和查找
4. **项目中大量使用**：`Vector2` 在项目中被广泛用于节点位置计算（如 `graph_world.dart`、`layout_service.dart`、`node_component.dart` 等），任何依赖值相等的逻辑都会出错

### 示例
```dart
final a = Vector2(100, 200);
final b = Vector2(100, 200);
print(a == b);           // false，应为 true
print({a}.contains(b));  // false，应为 true
```

### 建议修复
```dart
class Vector2 {
  final double x;
  final double y;
  const Vector2(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vector2 && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  // ... 其余代码
}
```

---

## Bug 2: `normalized()` 使用浮点数精确相等比较

### 文件
`lib/utils/types.dart`

### 位置
第 46-50 行

### 问题描述
`normalized()` 方法使用 `len == 0` 进行浮点数相等比较。由于浮点数精度问题，当向量长度极小但不为零时（如 `1e-300`），该比较不会触发零向量保护，导致除以极小数产生极大的结果向量。

### 问题代码
```dart
Vector2 normalized() {
  final len = length;
  if (len == 0) return Vector2.zero;  // 浮点数精确比较不可靠
  return Vector2(x / len, y / len);
}
```

### 影响
1. **力导向布局计算异常**：在 `layout_service.dart` 第 254-255 行和第 270 行，`normalized()` 被用于计算排斥力和吸引力。当两个节点极其接近时，`diff.length` 可能非常小但不等于 0，此时 `normalized()` 会返回一个方向正确但模极大的向量，导致节点被弹射到极远处
2. **连接渲染方向计算异常**：在 `connection_renderer.dart` 第 150 行，箭头绘制使用 `normalized()` 计算方向，极端情况下箭头方向可能异常

### 示例
```dart
final v = Vector2(1e-300, 1e-300);
print(v.length);            // 1.414e-300，不等于 0
final n = v.normalized();
print(n.x);                 // 极大值（约 7.07e+299），而非预期的零向量
```

### 建议修复
使用 epsilon 比较代替精确相等：
```dart
Vector2 normalized() {
  final len = length;
  if (len < 1e-10) return Vector2.zero;
  return Vector2(x / len, y / len);
}
```

---

## Bug 3: `openFile` 异常类型丢失

### 文件
`lib/utils/files.dart`

### 位置
第 19-21 行

### 问题描述
`catch (e)` 块捕获所有异常并重新包装为通用 `Exception`，丢失了原始异常的类型和堆栈信息。特别地，第 17 行抛出的 `UnsupportedError` 也会被捕获并重新包装，调用者无法区分"不支持的平台"和"打开文件失败"。

### 问题代码
```dart
try {
  // ... 平台判断逻辑
  if (...) {
    throw UnsupportedError('Unsupported platform');  // 第 17 行
  }
} catch (e) {
  throw Exception('Failed to open file: $e');  // 丢失原始异常类型
}
```

### 影响
1. **异常类型丢失**：调用者无法通过 `on UnsupportedError` 捕获特定异常
2. **堆栈信息丢失**：原始异常的堆栈跟踪被替换为新的 `Exception` 堆栈
3. **调试困难**：在 `export_dialog.dart` 第 117 行的调用处，catch 块只能得到一个通用错误消息，无法判断具体失败原因

### 示例
```dart
try {
  await openFile('/path/to/file');
} on UnsupportedError {
  // 永远不会执行，因为 UnsupportedError 被包装为 Exception
}
```

### 建议修复
让 `UnsupportedError` 直接传播，仅捕获进程执行相关的异常：
```dart
Future<void> openFile(String filePath) async {
  ProcessResult result;
  if (Platform.isWindows) {
    result = await Process.run('cmd', ['/c', 'start', '', filePath]);
  } else if (Platform.isMacOS) {
    result = await Process.run('open', [filePath]);
  } else if (Platform.isLinux) {
    result = await Process.run('xdg-open', [filePath]);
  } else {
    throw UnsupportedError('Unsupported platform');
  }

  if (result.exitCode != 0) {
    throw Exception(
      'Failed to open file: exit code ${result.exitCode}, '
      '${result.stderr}',
    );
  }
}
```

---

## Bug 4: `openFile` 未校验文件是否存在

### 文件
`lib/utils/files.dart`

### 位置
第 4-21 行（整个函数）

### 问题描述
`openFile` 函数在调用系统命令打开文件前，没有检查文件路径是否存在。如果文件不存在，系统命令会失败并产生平台相关的错误信息，用户难以理解。

### 影响
1. **错误信息不友好**：Windows 上 `start` 命令对不存在的文件会弹出系统错误对话框或返回模糊的错误码
2. **调试困难**：在 `export_dialog.dart` 第 116 行的调用场景中，用户点击"Open"按钮后如果文件已被移动或删除，只会看到"Failed to open file"的通用提示

### 建议修复
在打开文件前检查文件是否存在：
```dart
Future<void> openFile(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw FileNotFoundException('File not found: $filePath');
  }
  // ... 其余逻辑
}
```

---

## Bug 5: `openFile` 在 Windows 上路径含空格时可能失败

### 文件
`lib/utils/files.dart`

### 位置
第 8 行

### 问题描述
Windows 的 `start` 命令在处理含空格的路径时需要特殊处理。虽然当前代码传入了空字符串作为窗口标题参数（这是正确的），但当路径本身包含空格时，`Process.run` 的参数传递方式可能导致路径被错误分割。

### 问题代码
```dart
await Process.run('cmd', ['/c', 'start', '', filePath]);
```

### 影响
当文件路径包含空格时（如 `C:\Users\My User\Documents\file.md`），`start` 命令可能无法正确识别完整路径，导致打开失败。

### 示例
```dart
// 路径含空格
await openFile('C:\\Users\\My User\\Documents\\report.md');
// start 命令可能将 "C:\Users\My" 和 "User\Documents\report.md" 分开处理
```

### 建议修复
对路径添加引号保护：
```dart
await Process.run('cmd', ['/c', 'start', '""', '"$filePath"']);
```
或使用 `Process.run` 的 `runInShell` 选项：
```dart
await Process.run('start', ['', filePath], runInShell: true);
```

---

## Bug 6: Vector2 缺少 `/`（标量除法）运算符

### 文件
`lib/utils/types.dart`

### 位置
第 38 行之后

### 问题描述
`Vector2` 定义了 `*`（标量乘法）运算符，但缺少对应的 `/`（标量除法）运算符。这导致除法需要使用 `vector * (1.0 / scalar)` 的变通写法，既不直观又可能引入额外的浮点精度损失。

### 影响
1. **API 不对称**：有乘法无除法，违反最小惊讶原则
2. **精度损失**：`vector * (1.0 / scalar)` 先计算 `1.0 / scalar` 再乘以向量分量，比直接 `vector.x / scalar` 多一次浮点运算，可能引入精度误差
3. **代码可读性降低**：项目中可能存在 `vector * (1.0 / damping)` 这样的变通写法

### 建议修复
```dart
Vector2 operator /(double scalar) => Vector2(x / scalar, y / scalar);
```

---

## Bug 7: Vector2 缺少一元取负运算符

### 文件
`lib/utils/types.dart`

### 位置
第 32 行之后

### 问题描述
`Vector2` 定义了二元 `-`（向量减法）运算符，但缺少一元 `-`（取负）运算符。在力导向布局等算法中，经常需要对力向量取反方向。

### 影响
取反向量需要使用 `Vector2(-v.x, -v.y)` 或 `v * -1.0`，不够直观且容易遗漏某个分量。

### 建议修复
```dart
Vector2 operator -() => Vector2(-x, -y);
```

---

## Bug 8: `clamp` 方法对两个维度使用相同范围

### 文件
`lib/utils/types.dart`

### 位置
第 57-60 行

### 问题描述
`clamp` 方法接受单一的 `min` 和 `max` 参数，将 x 和 y 限制在相同范围内。但在实际使用中，x 和 y 通常需要不同的限制范围（如画布宽度和高度不同）。

### 问题代码
```dart
Vector2 clamp(double min, double max) => Vector2(
  x.clamp(min, max),
  y.clamp(min, max),
);
```

### 影响
1. **实用性差**：项目中 `layout_service.dart` 第 291-294 行没有使用此 `clamp` 方法，而是手动对 x 和 y 分别调用 `clamp`，说明当前签名无法满足实际需求
2. **误导性**：方法签名暗示可以对向量进行范围限制，但实际上无法对不同维度设置不同范围

### 示例
```dart
// 无法表达 "x 限制在 [0, 1200]，y 限制在 [0, 800]"
final pos = Vector2(1500, 900).clamp(0, 1200);
// 结果: Vector2(1200, 900) — y 未被正确限制
```

### 建议修复
提供接受 `Vector2` 参数的重载：
```dart
Vector2 clamp(double min, double max) => Vector2(
  x.clamp(min, max),
  y.clamp(min, max),
);

Vector2 clampTo(Vector2 min, Vector2 max) => Vector2(
  x.clamp(min.x, max.x),
  y.clamp(min.y, max.y),
);
```

---

## 总结

| Bug | 文件 | 严重程度 | 影响范围 |
|-----|------|---------|---------|
| Bug 1 | types.dart | **高** | 值相等性比较、Map/Set 查找 |
| Bug 2 | types.dart | **高** | 力导向布局计算、方向计算 |
| Bug 3 | files.dart | **中** | 异常处理、调试体验 |
| Bug 4 | files.dart | **中** | 用户体验、错误提示 |
| Bug 5 | files.dart | **中** | Windows 平台文件打开 |
| Bug 6 | types.dart | **低** | API 完整性、精度 |
| Bug 7 | types.dart | **低** | API 完整性、代码可读性 |
| Bug 8 | types.dart | **低** | API 实用性 |
