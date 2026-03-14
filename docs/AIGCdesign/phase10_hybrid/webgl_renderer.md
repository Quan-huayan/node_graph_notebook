# WebGL 渲染器设计文档

## 1. 概述

### 1.1 职责
WebGL 渲染器负责使用 WebGL 进行硬件加速渲染，实现：
- 高性能节点渲染
- 硬件加速的连接线绘制
- GPU 加速的特效
- 大规模场景渲染

### 1.2 目标
- **性能**: 支持 10000+ 节点流畅渲染（60 FPS）
- **质量**: 保持与 Canvas 渲染相同的视觉质量
- **兼容性**: 支持主流浏览器和平台
- **稳定性**: 优雅降级到 Canvas 模式

### 1.3 关键挑战
- **着色器编写**: 编写高效的 GLSL 着色器
- **资源管理**: WebGL 资源的正确分配和释放
- **状态同步**: 与 Canvas 渲染器的状态同步
- **调试困难**: WebGL 调试的复杂性

## 2. 架构设计

### 2.1 组件结构

```
WebGLRenderer
    │
    ├── WebGLContext (WebGL 上下文)
    │   ├── gl (GL 上下文)
    │   ├── canvas (Canvas 元素)
    │   └── extensions (扩展)
    │
    ├── ShaderManager (着色器管理器)
    │   ├── vertexShaders (顶点着色器)
    │   ├── fragmentShaders (片段着色器)
    │   └── programs (程序对象)
    │
    ├── BufferManager (缓冲区管理器)
    │   ├── vertexBuffers (顶点缓冲)
    │   ├── indexBuffers (索引缓冲)
    │   └── textureBuffers (纹理缓冲)
    │
    ├── BatchRenderer (批量渲染器)
    │   ├── batchQueue (批次队列)
    │   ├── batchSize (批次大小)
    │   └── flush() (刷新批次)
    │
    └── TextureManager (纹理管理器)
        ├── textures (纹理缓存)
        ├── loadTexture() (加载纹理)
        └── releaseTexture() (释放纹理)
```

### 2.2 接口定义

#### WebGL 上下文

```dart
/// WebGL 上下文包装器
class WebGLContext {
  /// GL 上下文
  final gl = WebGLRenderingContext;

  /// Canvas 元素
  final html.CanvasElement canvas;

  /// 视口大小
  Size get viewportSize => Size(canvas.width.toDouble(), canvas.height.toDouble());

  /// 设置视口
  void setViewport(int x, int y, int width, int height) {
    gl.viewport(x, y, width, height);
  }

  /// 清空缓冲区
  void clear(Color color) {
    gl.clearColor(color.red, color.green, color.blue, color.alpha);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
  }

  /// 检查错误
  void checkError() {
    final error = gl.getError();
    if (error != gl.NO_ERROR) {
      throw WebGLException('WebGL Error: $error');
    }
  }
}
```

#### 着色器管理器

```dart
/// 着色器管理器
class ShaderManager {
  final WebGLContext _context;
  final Map<String, ShaderProgram> _programs = {};

  ShaderManager(this._context);

  /// 创建着色器程序
  ShaderProgram createProgram(
    String vertexShaderSource,
    String fragmentShaderSource,
    String name,
  ) {
    // 编译顶点着色器
    final vertexShader = _compileShader(
      gl.VERTEX_SHADER,
      vertexShaderSource,
      '$name-vertex',
    );

    // 编译片段着色器
    final fragmentShader = _compileShader(
      gl.FRAGMENT_SHADER,
      fragmentShaderSource,
      '$name-fragment',
    );

    // 创建程序
    final program = gl.createProgram();
    gl.attachShader(program, vertexShader);
    gl.attachShader(program, fragmentShader);
    gl.linkProgram(program);

    // 检查链接状态
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      final error = gl.getProgramInfoLog(program);
      throw ShaderException('着色器程序链接失败: $error');
    }

    final shaderProgram = ShaderProgram(
      name: name,
      program: program,
      context: _context,
    );

    _programs[name] = shaderProgram;
    return shaderProgram;
  }

  /// 编译着色器
  gl.Shader _compileShader(int type, String source, String name) {
    final shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);

    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      final error = gl.getShaderInfoLog(shader);
      throw ShaderException('着色器编译失败 ($name): $error');
    }

    return shader;
  }

  /// 获取着色器程序
  ShaderProgram? getProgram(String name) {
    return _programs[name];
  }

  /// 释放着色器程序
  void releaseProgram(String name) {
    final program = _programs.remove(name);
    if (program != null) {
      program.dispose();
    }
  }

  /// 清空所有程序
  void clear() {
    for (final program in _programs.values) {
      program.dispose();
    }
    _programs.clear();
  }
}

/// 着色器程序
class ShaderProgram {
  final String name;
  final gl.Program program;
  final WebGLContext _context;

  /// Uniform 位置缓存
  final Map<String, int> _uniformLocations = {};

  /// 属性位置缓存
  final Map<String, int> _attributeLocations = {};

  ShaderProgram({
    required this.name,
    required this.program,
    required WebGLContext context,
  }) : _context = context;

  /// 使用程序
  void use() {
    _context.gl.useProgram(program);
  }

  /// 获取 Uniform 位置
  int getUniformLocation(String name) {
    if (!_uniformLocations.containsKey(name)) {
      final location = _context.gl.getUniformLocation(program, name);
      if (location == null) {
        throw ShaderException('未找到 Uniform: $name');
      }
      _uniformLocations[name] = location;
    }
    return _uniformLocations[name]!;
  }

  /// 获取属性位置
  int getAttributeLocation(String name) {
    if (!_attributeLocations.containsKey(name)) {
      final location = _context.gl.getAttribLocation(program, name);
      if (location < 0) {
        throw ShaderException('未找到属性: $name');
      }
      _attributeLocations[name] = location;
    }
    return _attributeLocations[name]!;
  }

  /// 设置 Uniform 矩阵
  void setUniformMatrix4(String name, Matrix4 matrix) {
    final location = getUniformLocation(name);
    _context.gl.uniformMatrix4fv(location, false, matrix.storage);
  }

  /// 设置 Uniform 向量
  void setUniformVector4(String name, Vector4 vector) {
    final location = getUniformLocation(name);
    _context.gl.uniform4f(location, vector.x, vector.y, vector.z, vector.w);
  }

  /// 设置 Uniform 颜色
  void setUniformColor(String name, Color color) {
    final location = getUniformLocation(name);
    _context.gl.uniform4f(
      location,
      color.red / 255,
      color.green / 255,
      color.blue / 255,
      color.alpha / 255,
    );
  }

  /// 释放资源
  void dispose() {
    _context.gl.deleteProgram(program);
  }
}
```

#### 缓冲区管理器

```dart
/// 缓冲区管理器
class BufferManager {
  final WebGLContext _context;
  final Map<String, gl.Buffer> _buffers = {};

  BufferManager(this._context);

  /// 创建顶点缓冲区
  gl.Buffer createVertexBuffer(String name, List<float> data) {
    final buffer = _context.gl.createBuffer();
    _context.gl.bindBuffer(_context.gl.ARRAY_BUFFER, buffer);
    _context.gl.bufferData(
      _context.gl.ARRAY_BUFFER,
      Float32List.fromList(data),
      _context.gl.STATIC_DRAW,
    );
    _buffers[name] = buffer;
    return buffer;
  }

  /// 创建索引缓冲区
  gl.Buffer createIndexBuffer(String name, List<int> data) {
    final buffer = _context.gl.createBuffer();
    _context.gl.bindBuffer(_context.gl.ELEMENT_ARRAY_BUFFER, buffer);
    _context.gl.bufferData(
      _context.gl.ELEMENT_ARRAY_BUFFER,
      Uint16List.fromList(data),
      _context.gl.STATIC_DRAW,
    );
    _buffers[name] = buffer;
    return buffer;
  }

  /// 更新顶点缓冲区
  void updateVertexBuffer(String name, List<float> data) {
    final buffer = _buffers[name];
    if (buffer == null) {
      throw ArgumentError('缓冲区不存在: $name');
    }

    _context.gl.bindBuffer(_context.gl.ARRAY_BUFFER, buffer);
    _context.gl.bufferSubData(
      _context.gl.ARRAY_BUFFER,
      0,
      Float32List.fromList(data),
    );
  }

  /// 释放缓冲区
  void releaseBuffer(String name) {
    final buffer = _buffers.remove(name);
    if (buffer != null) {
      _context.gl.deleteBuffer(buffer);
    }
  }

  /// 清空所有缓冲区
  void clear() {
    for (final buffer in _buffers.values) {
      _context.gl.deleteBuffer(buffer);
    }
    _buffers.clear();
  }
}
```

## 3. 核心 Shader

### 3.1 节点着色器

```glsl
// 节点顶点着色器
attribute vec2 a_position;
attribute vec2 a_texCoord;
attribute vec4 a_color;

uniform mat4 u_projection;
uniform mat4 u_model;
uniform vec2 u_resolution;

varying vec2 v_texCoord;
varying vec4 v_color;

void main() {
  // 转换位置到裁剪空间
  vec2 position = (u_projection * u_model * vec4(a_position, 0.0, 1.0)).xy;

  // 转换到像素坐标
  vec2 zeroToOne = position / u_resolution;
  vec2 zeroToTwo = zeroToOne * 2.0;
  vec2 clipSpace = zeroToTwo - 1.0;

  gl_Position = vec4(clipSpace * vec2(1, -1), 0, 1);
  gl_Position.w = 1.0;

  v_texCoord = a_texCoord;
  v_color = a_color;
}
```

```glsl
// 节点片段着色器
precision mediump float;

varying vec2 v_texCoord;
varying vec4 v_color;

uniform sampler2D u_texture;
uniform bool u_useTexture;
uniform vec4 u_tintColor;

void main() {
  vec4 color;

  if (u_useTexture) {
    color = texture2D(u_texture, v_texCoord);
  } else {
    color = v_color;
  }

  // 应用着色
  color = color * u_tintColor;

  gl_FragColor = color;
}
```

### 3.2 连接线着色器

```glsl
// 连接线顶点着色器
attribute vec2 a_position;
attribute vec4 a_color;

uniform mat4 u_projection;
uniform mat4 u_model;
uniform float u_lineWidth;

varying vec4 v_color;

void main() {
  vec4 position = u_projection * u_model * vec4(a_position, 0.0, 1.0);

  // 应用线宽
  gl_Position = position;
  gl_Position.w = 1.0;

  v_color = a_color;
}
```

```glsl
// 连接线片段着色器
precision mediump float;

varying vec4 v_color;

uniform vec4 u_color;
uniform float u_opacity;

void main() {
  vec4 color = u_color * v_color;
  color.a *= u_opacity;
  gl_FragColor = color;
}
```

## 4. 批量渲染

### 4.1 批量渲染器

```dart
/// 批量渲染器
class BatchRenderer {
  final WebGLContext _context;
  final ShaderProgram _program;
  final BufferManager _bufferManager;

  /// 批次队列
  final List<Batch> _batches = [];

  /// 当前批次
  Batch? _currentBatch;

  /// 最大批次大小
  final int maxBatchSize = 1000;

  BatchRenderer({
    required WebGLContext context,
    required ShaderProgram program,
    required BufferManager bufferManager,
  })  : _context = context,
        _program = program,
        _bufferManager = bufferManager;

  /// 开始新批次
  void beginBatch() {
    _currentBatch = Batch(
      program: _program,
      maxVertices: maxBatchSize * 4, // 每个四边形 4 个顶点
      maxIndices: maxBatchSize * 6, // 每个四边形 6 个索引
    );
  }

  /// 添加矩形到批次
  void addRect(Rect rect, Color color) {
    if (_currentBatch == null) {
      beginBatch();
    }

    if (_currentBatch!.isFull) {
      flush();
      beginBatch();
    }

    // 添加矩形顶点
    final x1 = rect.left;
    final y1 = rect.top;
    final x2 = rect.right;
    final y2 = rect.bottom;

    // 顶点位置
    final vertices = [
      x1, y1, // 左上
      x2, y1, // 右上
      x2, y2, // 右下
      x1, y2, // 左下
    ];

    // 顶点颜色
    final colors = [
      color.red, color.green, color.blue, color.alpha,
      color.red, color.green, color.blue, color.alpha,
      color.red, color.green, color.blue, color.alpha,
      color.red, color.green, color.blue, color.alpha,
    ];

    // 索引
    final baseVertex = _currentBatch!.vertexCount ~/ 2;
    final indices = [
      baseVertex + 0, baseVertex + 1, baseVertex + 2,
      baseVertex + 0, baseVertex + 2, baseVertex + 3,
    ];

    _currentBatch!.addVertices(vertices, colors, indices);
  }

  /// 刷新批次
  void flush() {
    if (_currentBatch == null || _currentBatch!.isEmpty) {
      return;
    }

    // 使用着色器程序
    _program.use();

    // 绑定顶点缓冲区
    final vertexBuffer = _bufferManager.createVertexBuffer(
      'batch-vertices',
      _currentBatch!.vertices,
    );
    _context.gl.bindBuffer(_context.gl.ARRAY_BUFFER, vertexBuffer);

    // 设置顶点属性
    final positionLocation = _program.getAttributeLocation('a_position');
    _context.gl.enableVertexAttribArray(positionLocation);
    _context.gl.vertexAttribPointer(
      positionLocation,
      2, // x, y
      _context.gl.FLOAT,
      false,
      0,
      0,
    );

    // 绑定颜色缓冲区
    final colorBuffer = _bufferManager.createVertexBuffer(
      'batch-colors',
      _currentBatch!.colors,
    );
    _context.gl.bindBuffer(_context.gl.ARRAY_BUFFER, colorBuffer);

    // 设置颜色属性
    final colorLocation = _program.getAttributeLocation('a_color');
    _context.gl.enableVertexAttribArray(colorLocation);
    _context.gl.vertexAttribPointer(
      colorLocation,
      4, // r, g, b, a
      _context.gl.FLOAT,
      false,
      0,
      0,
    );

    // 绘制
    _context.gl.drawElements(
      _context.gl.TRIANGLES,
      _currentBatch!.indices.length,
      _context.gl.UNSIGNED_SHORT,
      0,
    );

    // 清理
    _bufferManager.releaseBuffer('batch-vertices');
    _bufferManager.releaseBuffer('batch-colors');

    // 清空批次
    _currentBatch = null;
  }
}

/// 批次
class Batch {
  final ShaderProgram program;
  final int maxVertices;
  final int maxIndices;

  final List<float> vertices = [];
  final List<float> colors = [];
  final List<int> indices = [];

  int get vertexCount => vertices.length;
  int get indexCount => indices.length;

  bool get isEmpty => vertices.isEmpty;
  bool get isFull => vertices.length >= maxVertices * 2;

  Batch({
    required this.program,
    required this.maxVertices,
    required this.maxIndices,
  });

  void addVertices(
    List<float> newVertices,
    List<float> newColors,
    List<int> newIndices,
  ) {
    vertices.addAll(newVertices);
    colors.addAll(newColors);
    indices.addAll(newIndices);
  }
}
```

## 5. 性能优化

### 5.1 纹理图集

```dart
/// 纹理图集
class TextureAtlas {
  final WebGLContext _context;
  final Map<String, AtlasRegion> _regions = {};

  late gl.Texture _texture;
  int _width = 2048;
  int _height = 2048;
  int _x = 0;
  int _y = 0;
  int _rowHeight = 0;

  TextureAtlas(this._context) {
    _texture = _createTexture();
  }

  gl.Texture _createTexture() {
    final texture = _context.gl.createTexture();
    _context.gl.bindTexture(_context.gl.TEXTURE_2D, texture);

    // 设置纹理参数
    _context.gl.texParameteri(
      _context.gl.TEXTURE_2D,
      _context.gl.TEXTURE_WRAP_S,
      _context.gl.CLAMP_TO_EDGE,
    );
    _context.gl.texParameteri(
      _context.gl.TEXTURE_2D,
      _context.gl.TEXTURE_WRAP_T,
      _context.gl.CLAMP_TO_EDGE,
    );
    _context.gl.texParameteri(
      _context.gl.TEXTURE_2D,
      _context.gl.TEXTURE_MIN_FILTER,
      _context.gl.LINEAR,
    );
    _context.gl.texParameteri(
      _context.gl.TEXTURE_2D,
      _context.gl.TEXTURE_MAG_FILTER,
      _context.gl.LINEAR,
    );

    // 分配纹理内存
    _context.gl.texImage2D(
      _context.gl.TEXTURE_2D,
      0,
      _context.gl.RGBA,
      _width,
      _height,
      0,
      _context.gl.RGBA,
      _context.gl.UNSIGNED_BYTE,
      null,
    );

    return texture;
  }

  /// 添加纹理到图集
  AtlasRegion addTexture(String name, html.ImageElement image) {
    // 检查是否有足够空间
    if (_x + image.width > _width) {
      _x = 0;
      _y += _rowHeight;
      _rowHeight = 0;
    }

    if (_y + image.height > _height) {
      throw StateError('纹理图集已满');
    }

    // 更新行高
    _rowHeight = max(_rowHeight, image.height);

    // 上传纹理数据
    _context.gl.bindTexture(_context.gl.TEXTURE_2D, _texture);
    _context.gl.texSubImage2D(
      _context.gl.TEXTURE_2D,
      0,
      _x,
      _y,
      image.width,
      image.height,
      _context.gl.RGBA,
      _context.gl.UNSIGNED_BYTE,
      image,
    );

    // 创建区域
    final region = AtlasRegion(
      name: name,
      x: _x,
      y: _y,
      width: image.width,
      height: image.height,
      texture: _texture,
    );

    _regions[name] = region;

    // 更新位置
    _x += image.width;

    return region;
  }

  /// 获取区域
  AtlasRegion? getRegion(String name) {
    return _regions[name];
  }
}

/// 纹理图集区域
class AtlasRegion {
  final String name;
  final int x;
  final int y;
  final int width;
  final int height;
  final gl.Texture texture;

  AtlasRegion({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.texture,
  });

  /// 获取 UV 坐标
  Rect getUVCoords(int atlasWidth, int atlasHeight) {
    return Rect.fromLTWH(
      x / atlasWidth,
      y / atlasHeight,
      width / atlasWidth,
      height / atlasHeight,
    );
  }
}
```

## 6. 关键文件清单

```
lib/flame/rendering/webgl/
├── webgl_renderer.dart             # WebGL 渲染器
├── webgl_context.dart              # WebGL 上下文
├── shader_manager.dart             # 着色器管理器
├── shader_program.dart             # 着色器程序
├── buffer_manager.dart             # 缓冲区管理器
├── batch_renderer.dart             # 批量渲染器
├── texture_manager.dart            # 纹理管理器
├── texture_atlas.dart              # 纹理图集
└── shaders/
    ├── node.vert                   # 节点顶点着色器
    ├── node.frag                   # 节点片段着色器
    ├── connection.vert             # 连接线顶点着色器
    └── connection.frag             # 连接线片段着色器
```

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
