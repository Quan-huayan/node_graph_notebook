# 统一坐标系统设计文档

## 1. 概述

### 1.1 职责
统一坐标系统负责在 Canvas 渲染和 WebGL 渲染之间提供一致的坐标变换，实现：
- 统一的世界坐标系
- 屏幕坐标系转换
- 视口坐标系管理
- 缩放和平移支持

### 1.2 目标
- **一致性**: 两种渲染模式使用相同的坐标系统
- **精度**: 保证坐标变换的精度
- **性能**: 高效的坐标转换
- **易用性**: 简单的 API 接口

### 1.3 关键挑战
- **坐标系差异**: Canvas 和 WebGL 的坐标系差异
- **变换矩阵**: 正确的矩阵变换
- **精度问题**: 浮点数精度累积
- **视口变换**: 视口变化的正确处理

## 2. 架构设计

### 2.1 组件结构

```
CoordinateSystem
    │
    ├── WorldCoordinate (世界坐标)
    │   ├── x (X 坐标)
    │   ├── y (Y 坐标)
    │   └── toScreen() (转换为屏幕坐标)
    │
    ├── ScreenCoordinate (屏幕坐标)
    │   ├── x (X 坐标)
    │   ├── y (Y 坐标)
    │   └── toWorld() (转换为世界坐标)
    │
    ├── ViewportCoordinate (视口坐标)
    │   ├── x (X 坐标)
    │   ├── y (Y 坐标)
    │   └── toWorld() (转换为世界坐标)
    │
    ├── TransformMatrix (变换矩阵)
    │   ├── projection (投影矩阵)
    │   ├── view (视图矩阵)
    │   └── model (模型矩阵)
    │
    └── CoordinateConverter (坐标转换器)
        ├── worldToScreen() (世界转屏幕)
        ├── screenToWorld() (屏幕转世界)
        └── applyTransform() (应用变换)
```

### 2.2 接口定义

#### 坐标类型

```dart
/// 世界坐标
class WorldCoordinate {
  final double x;
  final double y;

  const WorldCoordinate(this.x, this.y);

  /// 转换为 Vector2
  Vector2 toVector2() => Vector2(x, y);

  /// 转换为 Offset
  Offset toOffset() => Offset(x, y);

  /// 转换为屏幕坐标
  ScreenCoordinate toScreen(CoordinateConverter converter) {
    return converter.worldToScreen(this);
  }

  /// 坐标运算
  WorldCoordinate operator +(WorldCoordinate other) {
    return WorldCoordinate(x + other.x, y + other.y);
  }

  WorldCoordinate operator -(WorldCoordinate other) {
    return WorldCoordinate(x - other.x, y - other.y);
  }

  WorldCoordinate operator *(double scalar) {
    return WorldCoordinate(x * scalar, y * scalar);
  }

  /// 距离计算
  double distanceTo(WorldCoordinate other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return sqrt(dx * dx + dy * dy);
  }

  @override
  String toString() => 'WorldCoordinate($x, $y)';
}

/// 屏幕坐标
class ScreenCoordinate {
  final double x;
  final double y;

  const ScreenCoordinate(this.x, this.y);

  /// 转换为 Vector2
  Vector2 toVector2() => Vector2(x, y);

  /// 转换为 Offset
  Offset toOffset() => Offset(x, y);

  /// 转换为世界坐标
  WorldCoordinate toWorld(CoordinateConverter converter) {
    return converter.screenToWorld(this);
  }

  @override
  String toString() => 'ScreenCoordinate($x, $y)';
}

/// 视口坐标（归一化坐标，0-1）
class ViewportCoordinate {
  final double x; // 0-1
  final double y; // 0-1

  const ViewportCoordinate(this.x, this.y);

  /// 转换为屏幕坐标
  ScreenCoordinate toScreen(Size screenSize) {
    return ScreenCoordinate(
      x * screenSize.width,
      y * screenSize.height,
    );
  }

  /// 转换为世界坐标
  WorldCoordinate toWorld(
    CoordinateConverter converter,
    Size screenSize,
  ) {
    return toScreen(screenSize).toWorld(converter);
  }

  @override
  String toString() => 'ViewportCoordinate($x, $y)';
}
```

#### 坐标转换器

```dart
/// 坐标转换器
class CoordinateConverter {
  /// 视口中心（世界坐标）
  WorldCoordinate viewportCenter;

  /// 缩放级别
  double zoom;

  /// 屏幕大小
  Size screenSize;

  /// 视口旋转（弧度）
  double rotation;

  CoordinateConverter({
    required this.viewportCenter,
    this.zoom = 1.0,
    required this.screenSize,
    this.rotation = 0.0,
  });

  /// 世界坐标转屏幕坐标
  ScreenCoordinate worldToScreen(WorldCoordinate worldPos) {
    // 1. 平移到视口中心
    final translated = worldPos - viewportCenter;

    // 2. 缩放
    final scaled = translated * zoom;

    // 3. 旋转
    final rotated = _rotate(scaled, rotation);

    // 4. 转换到屏幕坐标
    final screenX = rotated.x + screenSize.width / 2;
    final screenY = rotated.y + screenSize.height / 2;

    return ScreenCoordinate(screenX, screenY);
  }

  /// 屏幕坐标转世界坐标
  WorldCoordinate screenToWorld(ScreenCoordinate screenPos) {
    // 1. 从屏幕中心转换
    final centeredX = screenPos.x - screenSize.width / 2;
    final centeredY = screenPos.y - screenSize.height / 2;

    // 2. 反向旋转
    final unrotated = _rotate(
      WorldCoordinate(centeredX, centeredY),
      -rotation,
    );

    // 3. 反向缩放
    final unscaled = unrotated * (1.0 / zoom);

    // 4. 反向平移
    final worldX = unscaled.x + viewportCenter.x;
    final worldY = unscaled.y + viewportCenter.y;

    return WorldCoordinate(worldX, worldY);
  }

  /// 世界坐标转视口坐标
  ViewportCoordinate worldToViewport(WorldCoordinate worldPos) {
    final screenPos = worldToScreen(worldPos);
    return ViewportCoordinate(
      screenPos.x / screenSize.width,
      screenPos.y / screenSize.height,
    );
  }

  /// 视口坐标转世界坐标
  WorldCoordinate viewportToWorld(ViewportCoordinate viewportPos) {
    final screenPos = viewportPos.toScreen(screenSize);
    return screenToWorld(screenPos);
  }

  /// 获取当前视口边界（世界坐标）
  Rect getWorldViewportBounds() {
    final topLeft = screenToWorld(const ScreenCoordinate(0, 0));
    final bottomRight = screenToWorld(
      ScreenCoordinate(screenSize.width, screenSize.height),
    );

    return Rect.fromPoints(
      topLeft.toOffset(),
      bottomRight.toOffset(),
    );
  }

  /// 应用缩放
  void applyZoom(double newZoom, {WorldCoordinate? focusPoint}) {
    final focus = focusPoint ?? viewportCenter;

    // 计算缩放前的屏幕位置
    final oldScreenPos = worldToScreen(focus);

    // 更新缩放
    zoom = newZoom.clamp(0.1, 10.0);

    // 计算缩放后的世界位置，保持焦点不变
    final newWorldPos = screenToWorld(oldScreenPos);

    // 调整视口中心
    final dx = focus.x - newWorldPos.x;
    final dy = focus.y - newWorldPos.y;
    viewportCenter = WorldCoordinate(
      viewportCenter.x + dx,
      viewportCenter.y + dy,
    );
  }

  /// 应用平移
  void applyPan(ScreenCoordinate delta) {
    // 将屏幕平移转换为世界平移
    final worldDelta = WorldCoordinate(
      delta.x / zoom,
      delta.y / zoom,
    );

    // 反向旋转平移向量
    final rotatedDelta = _rotate(worldDelta, -rotation);

    // 更新视口中心
    viewportCenter = viewportCenter - rotatedDelta;
  }

  /// 应用旋转
  void applyRotation(double deltaRotation) {
    rotation += deltaRotation;
  }

  /// 重置变换
  void reset() {
    viewportCenter = const WorldCoordinate(0, 0);
    zoom = 1.0;
    rotation = 0.0;
  }

  /// 旋转向量
  WorldCoordinate _rotate(WorldCoordinate vec, double angle) {
    final cosA = cos(angle);
    final sinA = sin(angle);

    return WorldCoordinate(
      vec.x * cosA - vec.y * sinA,
      vec.x * sinA + vec.y * cosA,
    );
  }

  /// 获取变换矩阵（用于 WebGL）
  Matrix4 getTransformMatrix() {
    final matrix = Matrix4.identity();

    // 1. 视口中心平移
    matrix.translate(
      viewportCenter.x,
      viewportCenter.y,
      0.0,
    );

    // 2. 缩放
    matrix.scale(zoom, zoom, 1.0);

    // 3. 旋转
    matrix.rotateZ(rotation);

    return matrix;
  }

  /// 获取投影矩阵（用于 WebGL）
  Matrix4 getProjectionMatrix() {
    return Matrix4.identity()
      ..setEntry(0, 0, 2.0 / screenSize.width)
      ..setEntry(1, 1, 2.0 / screenSize.height)
      ..setEntry(0, 3, -1.0)
      ..setEntry(1, 3, -1.0);
  }
}
```

## 3. 核心算法

### 3.1 坐标转换

**问题描述**:
在世界坐标、屏幕坐标和视口坐标之间进行高效转换。

**算法描述**:
使用平移、缩放、旋转矩阵进行坐标变换。

**伪代码**:
```
function worldToScreen(worldPos, viewport):
    // 平移
    translated = worldPos - viewport.center

    // 缩放
    scaled = translated * viewport.zoom

    // 旋转
    rotated = rotate(scaled, viewport.rotation)

    // 转换到屏幕坐标
    screenX = rotated.x + screenWidth / 2
    screenY = rotated.y + screenHeight / 2

    return ScreenCoordinate(screenX, screenY)
```

**复杂度分析**:
- 时间复杂度: O(1)
- 空间复杂度: O(1)

### 3.2 变换矩阵构建

**问题描述**:
构建用于 WebGL 渲染的变换矩阵。

**算法描述**:
按照平移、缩放、旋转的顺序构建矩阵。

**伪代码**:
```
function buildTransformMatrix(viewport):
    matrix = IdentityMatrix()

    // 平移
    matrix.translate(viewport.center.x, viewport.center.y, 0)

    // 缩放
    matrix.scale(viewport.zoom, viewport.zoom, 1)

    // 旋转
    matrix.rotateZ(viewport.rotation)

    return matrix
```

**实现**:

```dart
/// 矩阵构建器
class MatrixBuilder {
  /// 构建模型矩阵
  static Matrix4 buildModelMatrix({
    required Vector2 position,
    required Vector2 size,
    required double rotation,
  }) {
    final matrix = Matrix4.identity();

    // 平移到位置
    matrix.translate(position.x, position.y, 0.0);

    // 旋转
    matrix.rotateZ(rotation);

    // 缩放
    matrix.scale(size.x, size.y, 1.0);

    return matrix;
  }

  /// 构建视图矩阵
  static Matrix4 buildViewMatrix(CoordinateConverter converter) {
    final matrix = Matrix4.identity();

    // 反向旋转
    matrix.rotateZ(-converter.rotation);

    // 反向缩放
    matrix.scale(
      1.0 / converter.zoom,
      1.0 / converter.zoom,
      1.0,
    );

    // 反向平移
    matrix.translate(
      -converter.viewportCenter.x,
      -converter.viewportCenter.y,
      0.0,
    );

    return matrix;
  }

  /// 构建投影矩阵（正交投影）
  static Matrix4 buildOrthoProjection({
    required double left,
    required double right,
    required double bottom,
    required double top,
    required double near,
    required double far,
  }) {
    final matrix = Matrix4.identity();

    matrix.setEntry(0, 0, 2.0 / (right - left));
    matrix.setEntry(1, 1, 2.0 / (top - bottom));
    matrix.setEntry(2, 2, -2.0 / (far - near));
    matrix.setEntry(0, 3, -(right + left) / (right - left));
    matrix.setEntry(1, 3, -(top + bottom) / (top - bottom));
    matrix.setEntry(2, 3, -(far + near) / (far - near));

    return matrix;
  }

  /// 构建投影矩阵（屏幕坐标）
  static Matrix4 buildScreenProjection(Size screenSize) {
    return Matrix4.identity()
      ..setEntry(0, 0, 2.0 / screenSize.width)
      ..setEntry(1, 1, -2.0 / screenSize.height) // Canvas Y 轴向下
      ..setEntry(0, 3, -1.0)
      ..setEntry(1, 3, 1.0);
  }
}
```

## 4. Canvas 和 WebGL 坐标系差异

### 4.1 坐标系对比

```dart
/// 坐标系说明
class CoordinateSystemInfo {
  /// Canvas 坐标系
  ///
  /// - 原点在左上角
  /// - X 轴向右为正
  /// - Y 轴向下为正
  static const String canvas = '''
    Canvas 坐标系:
    (0, 0) --------→ X
      |
      |
      ↓
      Y
  ''';

  /// WebGL 坐标系
  ///
  /// - 原点在中心
  /// - X 轴向右为正
  /// - Y 轴向上为正
  /// - Z 轴向外为正
  static const String webgl = '''
    WebGL 坐标系:
         Y
         ↑
         |
         |
    ←-----+-----→ X
         |
         |
         Z (向外)
  ''';

  /// 世界坐标系
  ///
  /// - 原点在用户定义的位置
  /// - X 轴向右为正
  /// - Y 轴向上为正（数学坐标系）
  static const String world = '''
    世界坐标系:
         Y
         ↑
         |
         |
    ←-----+-----→ X
         |
         |
  (0, 0)
  ''';
}
```

### 4.2 坐标系转换

```dart
/// Canvas 到 WebGL 坐标转换
class CanvasToWebGLConverter {
  /// 将 Canvas 坐标转换为 WebGL 坐标
  static Vector2 convert(Vector2 canvasPos, Size canvasSize) {
    // Canvas: 原点在左上角，Y 向下
    // WebGL: 原点在中心，Y 向上

    // 1. 将原点移到左下角（翻转 Y）
    final y = canvasSize.height - canvasPos.y;

    // 2. 将原点移到中心
    final x = canvasPos.x - canvasSize.width / 2;
    final centeredY = y - canvasSize.height / 2;

    // 3. 归一化到 -1 到 1
    final normalizedX = x / (canvasSize.width / 2);
    final normalizedY = centeredY / (canvasSize.height / 2);

    return Vector2(normalizedX, normalizedY);
  }

  /// 将 WebGL 坐标转换为 Canvas 坐标
  static Vector2 convertBack(Vector2 webglPos, Size canvasSize) {
    // 1. 反归一化
    final x = webglPos.x * (canvasSize.width / 2);
    final y = webglPos.y * (canvasSize.height / 2);

    // 2. 将原点移回左上角
    final canvasX = x + canvasSize.width / 2;
    final canvasY = canvasSize.height / 2 - y;

    return Vector2(canvasX, canvasY);
  }
}
```

## 5. 性能优化

### 5.1 缓存机制

```dart
/// 缓存的坐标转换器
class CachedCoordinateConverter extends CoordinateConverter {
  /// 缓存的变换矩阵
  Matrix4? _cachedTransformMatrix;

  /// 缓存的投影矩阵
  Matrix4? _cachedProjectionMatrix;

  /// 缓存失效标志
  bool _cacheInvalid = true;

  CachedCoordinateConverter({
    required WorldCoordinate viewportCenter,
    required double zoom,
    required Size screenSize,
    double rotation = 0.0,
  }) : super(
          viewportCenter: viewportCenter,
          zoom: zoom,
          screenSize: screenSize,
          rotation: rotation,
        );

  @override
  void applyZoom(double newZoom, {WorldCoordinate? focusPoint}) {
    super.applyZoom(newZoom, focusPoint: focusPoint);
    _cacheInvalid = true;
  }

  @override
  void applyPan(ScreenCoordinate delta) {
    super.applyPan(delta);
    _cacheInvalid = true;
  }

  @override
  void applyRotation(double deltaRotation) {
    super.applyRotation(deltaRotation);
    _cacheInvalid = true;
  }

  @override
  Matrix4 getTransformMatrix() {
    if (_cacheInvalid || _cachedTransformMatrix == null) {
      _cachedTransformMatrix = super.getTransformMatrix();
      _cacheInvalid = false;
    }
    return _cachedTransformMatrix!;
  }

  @override
  Matrix4 getProjectionMatrix() {
    if (_cacheInvalid || _cachedProjectionMatrix == null) {
      _cachedProjectionMatrix = super.getProjectionMatrix();
      _cacheInvalid = false;
    }
    return _cachedProjectionMatrix!;
  }
}
```

### 5.2 批量转换

```dart
/// 批量坐标转换
class BatchCoordinateConverter {
  final CoordinateConverter _converter;

  BatchCoordinateConverter(this._converter);

  /// 批量世界坐标转屏幕坐标
  List<ScreenCoordinate> worldToScreenBatch(
    List<WorldCoordinate> worldPositions,
  ) {
    return worldPositions.map((pos) => pos.toScreen(_converter)).toList();
  }

  /// 批量屏幕坐标转世界坐标
  List<WorldCoordinate> screenToWorldBatch(
    List<ScreenCoordinate> screenPositions,
  ) {
    return screenPositions.map((pos) => pos.toWorld(_converter)).toList();
  }

  /// 批量转换（SIMD 优化）
  List<ScreenCoordinate> worldToScreenBatchSIMD(
    List<WorldCoordinate> worldPositions,
  ) {
    // 使用 Float32List 进行批量计算
    final result = List<ScreenCoordinate>.filled(worldPositions.length, const ScreenCoordinate(0, 0));

    // 提取所有 X 和 Y 坐标
    final xCoords = Float32List(worldPositions.length);
    final yCoords = Float32List(worldPositions.length);

    for (int i = 0; i < worldPositions.length; i++) {
      xCoords[i] = worldPositions[i].x;
      yCoords[i] = worldPositions[i].y;
    }

    // 批量平移
    for (int i = 0; i < worldPositions.length; i++) {
      xCoords[i] -= _converter.viewportCenter.x;
      yCoords[i] -= _converter.viewportCenter.y;
    }

    // 批量缩放
    final zoom = _converter.zoom;
    for (int i = 0; i < worldPositions.length; i++) {
      xCoords[i] *= zoom;
      yCoords[i] *= zoom;
    }

    // 批量旋转（如果有）
    if (_converter.rotation != 0) {
      final cosA = cos(_converter.rotation);
      final sinA = sin(_converter.rotation);

      for (int i = 0; i < worldPositions.length; i++) {
        final x = xCoords[i];
        final y = yCoords[i];
        xCoords[i] = x * cosA - y * sinA;
        yCoords[i] = x * sinA + y * cosA;
      }
    }

    // 批量转换到屏幕坐标
    final halfWidth = _converter.screenSize.width / 2;
    final halfHeight = _converter.screenSize.height / 2;

    for (int i = 0; i < worldPositions.length; i++) {
      result[i] = ScreenCoordinate(
        xCoords[i] + halfWidth,
        yCoords[i] + halfHeight,
      );
    }

    return result;
  }
}
```

## 6. 关键文件清单

```
lib/flame/rendering/coordinates/
├── coordinate_system.dart          # 坐标系统定义
├── world_coordinate.dart           # 世界坐标
├── screen_coordinate.dart          # 屏幕坐标
├── viewport_coordinate.dart        # 视口坐标
├── coordinate_converter.dart       # 坐标转换器
├── cached_converter.dart           # 缓存转换器
├── batch_converter.dart            # 批量转换器
├── matrix_builder.dart             # 矩阵构建器
└── canvas_webgl_converter.dart     # Canvas-WebGL 转换器
```

## 7. 使用示例

### 7.1 基本使用

```dart
// 创建坐标转换器
final converter = CoordinateConverter(
  viewportCenter: WorldCoordinate(0, 0),
  zoom: 1.0,
  screenSize: Size(1920, 1080),
);

// 世界坐标转屏幕坐标
final worldPos = WorldCoordinate(100, 200);
final screenPos = converter.worldToScreen(worldPos);
print('屏幕坐标: ${screenPos.x}, ${screenPos.y}');

// 屏幕坐标转世界坐标
final mousePos = ScreenCoordinate(960, 540);
final worldMousePos = converter.screenToWorld(mousePos);
print('世界坐标: ${worldMousePos.x}, ${worldMousePos.y}');

// 应用缩放
converter.applyZoom(2.0);

// 应用平移
converter.applyPan(ScreenCoordinate(100, 50));

// 应用旋转
converter.applyRotation(pi / 4);
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
