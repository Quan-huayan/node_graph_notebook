# Bug Report: feature_flags.dart

## 文件位置
`lib/core/config/feature_flags.dart`

---

## Bug 1: validateConfig() 方法返回值不一致

### 位置
第 120-141 行

### 问题描述
`validateConfig()` 方法在检测到配置问题时，返回值不一致：
- 第 122-125 行：当 `optimizationThreshold < 0` 时返回 `false`
- 第 127-133 行：当检测到其他阈值问题时，仅记录警告但不返回 `false`
- 第 140 行：方法最终总是返回 `true`

### 问题代码
```dart
static bool validateConfig() {
  // 检查阈值合理性
  if (optimizationThreshold < 0) {
    _log.info('WARNING: optimizationThreshold < 0');
    return false;  // 这里返回 false
  }

  if (multiThreadingThreshold < optimizationThreshold) {
    _log.info('WARNING: multiThreadingThreshold < optimizationThreshold');
    // 没有返回 false，继续执行
  }

  if (textureCacheThreshold > optimizationThreshold) {
    _log.info('WARNING: textureCacheThreshold > optimizationThreshold');
    // 没有返回 false，继续执行
  }

  // ...

  return true;  // 总是返回 true
}
```

### 影响
调用者无法通过返回值判断配置是否有效，验证方法形同虚设。

### 建议修复
当检测到任何配置问题时，应返回 `false`：
```dart
static bool validateConfig() {
  if (optimizationThreshold < 0) {
    _log.info('WARNING: optimizationThreshold < 0');
    return false;
  }

  if (multiThreadingThreshold < optimizationThreshold) {
    _log.info('WARNING: multiThreadingThreshold < optimizationThreshold');
    return false;
  }

  if (textureCacheThreshold > optimizationThreshold) {
    _log.info('WARNING: textureCacheThreshold > optimizationThreshold');
    return false;
  }

  if (maxTextureCacheSize < 10 * 1024 * 1024) {
    _log.info('WARNING: maxTextureCacheSize < 10MB');
    return false;
  }

  return true;
}
```

---

## Bug 2: textureCacheThreshold 阈值检查逻辑可能错误

### 位置
第 131-133 行

### 问题描述
当前检查 `textureCacheThreshold > optimizationThreshold` 时记录警告，但这个逻辑可能有问题：
- `textureCacheThreshold = 50`（纹理缓存阈值）
- `optimizationThreshold = 100`（优化阈值）

当 `textureCacheThreshold(50) < optimizationThreshold(100)` 时，意味着纹理缓存会在优化启用之前就启用，这可能是合理的。

但当 `textureCacheThreshold > optimizationThreshold` 时，意味着优化已启用但纹理缓存尚未启用，这反而可能是预期行为。

### 问题代码
```dart
if (textureCacheThreshold > optimizationThreshold) {
  _log.info('WARNING: textureCacheThreshold > optimizationThreshold');
}
```

### 影响
可能产生误导性的警告信息，或者真正的配置问题（纹理缓存阈值过小）没有被检测到。

### 建议
重新评估这个检查的逻辑，或者明确文档说明这个警告的含义。

---

## Bug 3: 静态可变状态导致测试污染

### 位置
第 146 行

### 问题描述
`runtimeConfig` 是一个静态可变变量：
```dart
static RuntimeConfig runtimeConfig = RuntimeConfig();
```

### 影响
1. **测试污染**：一个测试修改 `runtimeConfig` 后，会影响后续测试
2. **状态难以追踪**：全局可变状态使得应用状态难以预测
3. **并发问题**：在多线程环境下可能导致竞态条件

### 建议修复
考虑以下方案之一：
1. 使用依赖注入而非静态变量
2. 提供测试专用的重置方法
3. 使用 `late final` 配合工厂模式

---

## Bug 4: copyWith 方法实现方式可能导致问题

### 位置
第 175-186 行

### 问题描述
`copyWith` 方法创建新实例后使用级联操作符赋值：
```dart
RuntimeConfig copyWith({...}) => RuntimeConfig()
  ..forceEnableOptimization = forceEnableOptimization ?? this.forceEnableOptimization
  ..forceDisableOptimization = forceDisableOptimization ?? this.forceDisableOptimization
  ...
```

### 潜在问题
当传入参数为 `null` 时，使用 `this` 的值。但如果 `this` 的值也是 `null`（对于可空字段），行为是正确的。但对于 `bool` 类型字段，如果调用者想显式设置为 `false`，当前实现无法区分"不传参"和"传 false"。

### 示例
```dart
// 无法将 forceEnableOptimization 设置为 false
config.copyWith(forceEnableOptimization: false)  // 会被 ?? this.forceEnableOptimization 覆盖
```

### 建议
对于布尔类型，考虑使用包装类或三态逻辑来区分"不修改"和"设置为 false"。

---

## 总结

| Bug | 严重程度 | 影响范围 |
|-----|---------|---------|
| Bug 1 | 高 | 配置验证失效 |
| Bug 2 | 中 | 误导性警告 |
| Bug 3 | 中 | 测试可靠性 |
| Bug 4 | 低 | API 可用性 |
