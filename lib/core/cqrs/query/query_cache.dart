import 'dart:collection';
import 'query.dart';

/// LRU (Least Recently Used) 缓存实现
///
/// 设计说明：
/// QueryCache 使用 LRU 策略管理缓存条目：
/// 1. 当缓存满时，驱逐最近最少使用的条目
/// 2. 使用 LinkedHashMap 保证插入顺序和快速访问
/// 3. 支持按 TTL (Time To Live) 自动过期
/// 4. 线程安全（Dart 单线程模型下无需额外锁）
///
/// 性能特性：
/// - get 操作: O(1)
/// - put 操作: O(1) (驱逐时 O(n) 但只在缓存满时触发)
/// - 内存占用: 可控，通过 maxSize 限制
///
/// 使用场景：
/// - 频繁查询的节点数据
/// - 搜索结果缓存
/// - 图邻居查询结果
class QueryCache {
  /// 构造函数
  QueryCache({
    required this.maxSize,
    required this.defaultTtl,
  }) : assert(maxSize > 0, 'maxSize must be greater than 0');

  /// 最大缓存条目数
  final int maxSize;

  /// 默认缓存有效期
  final Duration defaultTtl;

  /// 缓存存储 (使用 LinkedHashMap 保持访问顺序)
  final LinkedHashMap<String, _CacheEntry> _storage = LinkedHashMap();

  /// 当前缓存大小
  int get size => _storage.length;

  /// 缓存是否已满
  bool get isFull => _storage.length >= maxSize;

  /// 获取缓存值
  ///
  /// [query] 查询对象
  /// 返回缓存的结果，如果不存在或已过期则返回 null
  ///
  /// 副作用：每次成功获取会更新访问时间，影响 LRU 驱逐顺序
  QueryResult? get(Query query) {
    if (query is! CacheableQuery) {
      return null;
    }

    final key = _generateKey(query);
    final entry = _storage[key];

    if (entry == null) {
      return null;
    }

    // 检查是否过期
    if (_isExpired(entry)) {
      _storage.remove(key);
      return null;
    }

    // 更新访问时间（LRU 策略）
    entry.lastAccessedAt = DateTime.now();

    // 重新插入以更新顺序（LinkedHashMap 特性）
    _storage.remove(key);
    _storage[key] = entry;

    return entry.result;
  }

  /// 存储缓存值
  ///
  /// [query] 查询对象
  /// [result] 查询结果
  ///
  /// 副作用：如果缓存已满，会驱逐最近最少使用的条目
  void put(Query query, QueryResult result) {
    if (query is! CacheableQuery || !result.isSuccess) {
      // 只缓存成功的可缓存查询
      return;
    }

    final key = _generateKey(query);
    final ttl = query.cacheTtl ?? defaultTtl;

    // 如果已存在，先移除（稍后重新插入到末尾）
    _storage.remove(key);

    // 检查是否需要驱逐
    if (isFull) {
      _evictLRU();
    }

    // 添加新条目
    final now = DateTime.now();
    _storage[key] = _CacheEntry(
      result: result,
      createdAt: now,
      lastAccessedAt: now,
      expiresAt: now.add(ttl),
    );
  }

  /// 使指定键的缓存失效
  ///
  /// [query] 查询对象
  void invalidate(Query query) {
    if (query is! CacheableQuery) {
      return;
    }
    _storage.remove(_generateKey(query));
  }

  /// 使指定类型的所有缓存失效
  ///
  /// [queryType] Query 的运行时类型
  void invalidateByType(Type queryType) {
    final keysToRemove = _storage.keys
        .where((key) => key.startsWith('${queryType}_'))
        .toList();

    keysToRemove.forEach(_storage.remove);
  }

  /// 清除所有缓存
  void clear() {
    _storage.clear();
  }

  /// 清理过期的缓存条目
  ///
  /// 返回清理的条目数
  int cleanup() {
    final now = DateTime.now();
    final expiredKeys = _storage.entries
        .where((entry) => entry.value.expiresAt.isBefore(now))
        .map((entry) => entry.key)
        .toList();

    expiredKeys.forEach(_storage.remove);

    return expiredKeys.length;
  }

  /// 获取缓存统计信息
  QueryCacheStats get stats {
    final now = DateTime.now();
    final entries = _storage.values.toList();

    // 计算命中率（需要额外计数器，这里简化为返回当前状态）
    return QueryCacheStats(
      size: size,
      maxSize: maxSize,
      expiredCount: entries.where((e) => e.expiresAt.isBefore(now)).length,
    );
  }

  /// 生成缓存键
  String _generateKey(CacheableQuery query) => query.cacheKey;

  /// 检查缓存条目是否过期
  bool _isExpired(_CacheEntry entry) => DateTime.now().isAfter(entry.expiresAt);

  /// 驱逐最近最少使用的条目
  ///
  /// 实现说明：
  /// LinkedHashMap 保持插入顺序，第一个元素是最久未使用的
  void _evictLRU() {
    if (_storage.isEmpty) {
      return;
    }

    // 获取第一个键（最久未使用）
    final lruKey = _storage.keys.first;
    _storage.remove(lruKey);
  }
}

/// 缓存条目
class _CacheEntry {
  /// 构造函数
  _CacheEntry({
    required this.result,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.expiresAt,
  });

  /// 缓存结果
  final QueryResult result;

  /// 创建时间
  final DateTime createdAt;

  /// 最后访问时间
  DateTime lastAccessedAt;

  /// 过期时间
  final DateTime expiresAt;
}

/// 缓存统计信息
class QueryCacheStats {
  /// 构造函数
  const QueryCacheStats({
    required this.size,
    required this.maxSize,
    required this.expiredCount,
  });

  /// 当前缓存大小
  final int size;

  /// 最大缓存大小
  final int maxSize;

  /// 已过期但未清理的条目数
  final int expiredCount;

  /// 缓存使用率 (0.0 - 1.0)
  double get usageRate => maxSize > 0 ? size / maxSize : 0.0;

  @override
  String toString() =>
      'QueryCacheStats(size: $size/$maxSize, '
      'usage: ${(usageRate * 100).toStringAsFixed(1)}%, '
      'expired: $expiredCount)';
}
