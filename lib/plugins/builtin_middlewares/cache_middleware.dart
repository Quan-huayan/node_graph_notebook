import '../../core/commands/models/command.dart';
import '../../core/commands/models/command_context.dart';
import '../../core/plugin/middleware/middleware_plugin.dart';
import '../../core/plugin/plugin_context.dart';
import '../../core/plugin/plugin_metadata.dart';

/// 缓存中间件
class CacheMiddleware extends CommandMiddlewarePlugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'cache_middleware',
    name: 'Cache Middleware',
    version: '1.0.0',
    description: 'Caches command results for better performance',
  );

  @override
  int get priority => 50;

  final Map<String, CommandResult> _cache = {};
  final Map<String, Duration> _cacheTtl = {};
  final Duration _defaultTtl = const Duration(minutes: 5);

  @override
  Future<void> onInit(MiddlewarePluginContext context) async {
    // 初始化缓存
  }

  @override
  Future<void> onDispose() async {
    // 清理缓存
    _cache.clear();
    _cacheTtl.clear();
  }

  @override
  Future<void> onLoad(PluginContext context) async {
    // 加载时的逻辑
  }

  @override
  Future<void> onEnable() async {
    // 启用时的逻辑
  }

  @override
  Future<void> onDisable() async {
    // 禁用时的逻辑
  }

  @override
  Future<void> onUnload() async {
    // 卸载时的逻辑
  }

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  /// 插件状态
  PluginState _state = PluginState.unloaded;

  @override
  bool canHandle(Command command) 
    // 只处理标记为可缓存的命令
    => command is CacheableCommand;

  @override
  Future<CommandResult?> handle(
    Command command,
    CommandContext context,
    NextMiddleware next,
  ) async {
    final cacheKey = _generateCacheKey(command);

    // 检查缓存
    if (_isValidCache(cacheKey)) {
      return _cache[cacheKey];
    }

    // 执行命令
    final result = await next(command, context);

    // 缓存结果
    if (result != null && command is CacheableCommand) {
      _cache[cacheKey] = result;
      _cacheTtl[cacheKey] = command.cacheTtl ?? _defaultTtl;
    }

    return result;
  }

  String _generateCacheKey(Command command) => '${command.runtimeType.toString()}:${command.hashCode}';

  bool _isValidCache(String key) {
    if (!_cache.containsKey(key) || !_cacheTtl.containsKey(key)) {
      return false;
    }

    final ttl = _cacheTtl[key]!;
    final timestamp = _getCacheTimestamp(key);
    return DateTime.now().difference(timestamp) < ttl;
  }

  DateTime _getCacheTimestamp(String key) => DateTime.now(); // 这里简化处理，实际应该存储时间戳

  /// 清除所有缓存
  ///
  /// 移除所有命令的缓存结果
  void clearCache() {
    _cache.clear();
    _cacheTtl.clear();
  }

  /// 清除指定命令的缓存
  ///
  /// [command] 要清除缓存的命令
  void clearCacheForCommand(Command command) {
    final key = _generateCacheKey(command);
    _cache.remove(key);
    _cacheTtl.remove(key);
  }
}

/// 可缓存的命令接口
///
/// 标记命令可以被缓存中间件缓存
abstract class CacheableCommand extends Command {
  /// 缓存有效期
  ///
  /// 如果为 null，则使用中间件的默认缓存时间
  Duration? get cacheTtl;
}
