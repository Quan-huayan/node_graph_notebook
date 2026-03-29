import '../utils/logger.dart';

const _log = AppLogger('RenderingFeatureFlags');

/// UI布局系统功能标志
///
/// **用途：**
/// - 控制新的UILayoutService系统的启用/禁用
/// - 支持渐进式迁移和A/B测试
/// - 提供降级机制以确保稳定性
///
/// **使用场景：**
/// 1. 在开发环境启用新系统
/// 2. 在生产环境逐步推出
/// 3. 遇到问题时快速禁用新系统
class LayoutFeatureFlags {
  /// 是否启用新的UI布局系统（总开关）
  ///
  /// 设为 false 可完全禁用新系统，回退到旧的HookRegistry实现
  /// 设为 true 则使用新的UILayoutService系统
  ///
  /// **重要：** 默认为 false，确保系统稳定性
  /// 在完成所有组件的测试和验证之前，请保持为 false
  static const bool useNewLayoutSystem = false;

  /// 是否为Sidebar启用新系统
  ///
  /// 支持组件级别的渐进式迁移
  static const bool useNewLayoutSystemForSidebar = false;

  /// 是否为Toolbar启用新系统
  ///
  /// 支持组件级别的渐进式迁移
  static const bool useNewLayoutSystemForToolbar = false;

  /// 是否为Graph启用新系统
  ///
  /// 支持组件级别的渐进式迁移
  static const bool useNewLayoutSystemForGraph = false;
}

/// 渲染优化功能标志
///
/// **用途：**
/// - 控制渲染优化功能的启用/禁用
/// - 支持渐进式推出和 A/B 测试
/// - 提供降级机制以确保稳定性
///
/// **使用场景：**
/// 1. 在开发环境启用所有优化
/// 2. 在生产环境逐步推出
/// 3. 遇到问题时快速禁用特定优化
/// 4. 基于节点数量动态启用优化
class RenderingFeatureFlags {
  // === 主开关 ===

  /// 是否启用渲染优化（总开关）
  ///
  /// 设为 false 可完全禁用所有优化，回退到原始实现
  static const bool enableOptimizedRendering = true;

  /// 是否启用视口剔除
  ///
  /// 视口剔除可以减少 50-90% 的渲染工作量
  /// 推荐始终启用（除非发现 bug）
  static const bool enableViewportCulling = true;

  /// 是否启用纹理缓存
  ///
  /// 纹理缓存可减少 60% 的节点渲染时间
  /// 推荐始终启用（除非内存不足）
  static const bool enableTextureCaching = true;

  /// 是否启用多线程计算
  ///
  /// Isolate 线程池用于文本布局、节点尺寸等计算
  /// 推荐在大型图表（200+ 节点）时启用
  static const bool enableMultiThreading = true;

  /// 是否启用性能监控
  ///
  /// 性能监控会收集 FPS、缓存命中率等指标
  /// 推荐在开发环境启用，生产环境可选择性启用
  static const bool enablePerformanceMonitoring = true;

  // === 阈值配置 ===

  /// 启用优化的最小节点数
  ///
  /// 小于此数量时使用原始实现，避免优化开销
  static const int optimizationThreshold = 100;

  /// 启用多线程的最小节点数
  ///
  /// 多线程有固定开销，小规模计算时反而更慢
  static const int multiThreadingThreshold = 200;

  /// 启用纹理缓存的最小节点数
  ///
  /// 纹理缓存占用内存，小规模时缓存命中率低
  static const int textureCacheThreshold = 50;

  // === 缓存配置 ===

  /// 纹理缓存最大大小（字节）
  ///
  /// 默认 100MB，可根据设备内存调整
  static const int maxTextureCacheSize = 100 * 1024 * 1024;

  /// Isolate 线程池大小
  ///
  /// 默认：处理器核心数 - 1，可手动指定
  static const int? isolatePoolSize = null; // null = 自动计算

  // === 调试选项 ===

  /// 是否启用调试日志
  ///
  /// 输出详细的优化日志到控制台
  static const bool enableDebugLogging = false;

  /// 是否显示性能覆盖层
  ///
  /// 在屏幕上显示实时性能指标
  static const bool showPerformanceOverlay = false;

  // === 环境检测 ===

  /// 当前是否在调试模式
  static bool get isDebugMode {
    var debugMode = false;
    assert(debugMode = true);
    return debugMode;
  }

  /// 是否应该启用优化（基于节点数量）
  static bool shouldEnableOptimization(int nodeCount) {
    if (!enableOptimizedRendering) return false;
    return nodeCount >= optimizationThreshold;
  }

  /// 是否应该启用多线程（基于节点数量）
  static bool shouldEnableMultiThreading(int nodeCount) {
    if (!enableMultiThreading) return false;
    return nodeCount >= multiThreadingThreshold;
  }

  /// 是否应该启用纹理缓存（基于节点数量）
  static bool shouldEnableTextureCache(int nodeCount) {
    if (!enableTextureCaching) return false;
    return nodeCount >= textureCacheThreshold;
  }

  // === 配置验证 ===

  /// 验证配置的有效性
  static bool validateConfig() {
    // 检查阈值合理性
    if (optimizationThreshold < 0) {
      _log.info('WARNING: optimizationThreshold < 0');
      return false;
    }

    if (multiThreadingThreshold < optimizationThreshold) {
      _log.info('WARNING: multiThreadingThreshold < optimizationThreshold');
    }

    if (textureCacheThreshold > optimizationThreshold) {
      _log.info('WARNING: textureCacheThreshold > optimizationThreshold');
    }

    // 检查缓存大小
    if (maxTextureCacheSize < 10 * 1024 * 1024) {
      _log.info('WARNING: maxTextureCacheSize < 10MB');
    }

    return true;
  }

  // === 运行时配置 ===

  /// 允许运行时修改的配置
  static RuntimeConfig runtimeConfig = RuntimeConfig();

  /// 重置为默认配置
  static void resetToDefaults() {
    runtimeConfig = RuntimeConfig();
  }
}

/// 运行时可修改的配置
///
/// **注意：** 这些配置可以在应用运行时动态修改
/// 但修改后需要重新加载组件才能生效
class RuntimeConfig {
  /// 是否强制启用优化（忽略节点数量阈值）
  bool forceEnableOptimization = false;

  /// 是否强制禁用优化（用于紧急降级）
  bool forceDisableOptimization = false;

  /// 自定义优化阈值（null = 使用默认值）
  int? customOptimizationThreshold;

  /// 自定义缓存大小（null = 使用默认值）
  int? customMaxCacheSize;

  /// 是否启用性能覆盖层
  bool showPerformanceOverlay = false;

  /// 复制配置
  RuntimeConfig copyWith({
    bool? forceEnableOptimization,
    bool? forceDisableOptimization,
    int? customOptimizationThreshold,
    int? customMaxCacheSize,
    bool? showPerformanceOverlay,
  }) => RuntimeConfig()
      ..forceEnableOptimization = forceEnableOptimization ?? this.forceEnableOptimization
      ..forceDisableOptimization = forceDisableOptimization ?? this.forceDisableOptimization
      ..customOptimizationThreshold = customOptimizationThreshold ?? this.customOptimizationThreshold
      ..customMaxCacheSize = customMaxCacheSize ?? this.customMaxCacheSize
      ..showPerformanceOverlay = showPerformanceOverlay ?? this.showPerformanceOverlay;

  /// 获取实际使用的优化阈值
  int get effectiveOptimizationThreshold => customOptimizationThreshold ?? RenderingFeatureFlags.optimizationThreshold;

  /// 获取实际使用的缓存大小
  int get effectiveMaxCacheSize => customMaxCacheSize ?? RenderingFeatureFlags.maxTextureCacheSize;
}
