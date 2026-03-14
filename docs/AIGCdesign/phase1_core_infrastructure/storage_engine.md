# 存储引擎设计文档

## 1. 概述

### 1.1 职责
存储引擎是系统的持久化层，负责：
- 节点数据的高效存储和检索
- 写操作优化（LSM Tree 架构）
- 读性能优化（索引和缓存）
- 数据持久化和崩溃恢复
- 并发访问控制

### 1.2 目标
- **写性能**: 单次写入延迟 < 5ms
- **读性能**: 单次查询延迟 < 1ms（内存缓存命中）
- **吞吐量**: > 10,000 writes/s（批量写入）
- **可靠性**: WAL 保证数据不丢失

### 1.3 关键挑战
- **写放大**: LSM Tree 的多级写入
- **空间回收**: 旧版本数据的清理
- **读性能**: 可能查询多个 SSTable
- **崩溃恢复**: WAL 重放和 MemTable 恢复

## 2. 架构设计

### 2.1 组件结构

```
StorageEngine
    │
    ├── LSM Tree
    │   ├── MemTable (内存表)
    │   │   ├── Hash Index (哈希索引)
    │   │   └── Write Buffer (写缓冲)
    │   │
    │   ├── Immutable MemTable (不可变内存表)
    │   │   └── 等待刷新
    │   │
    │   └── SSTables (磁盘表)
    │       ├── Level 0 (新数据)
    │       ├── Level 1 (已合并)
    │       ├── Level 2 (已压缩)
    │       └── ...
    │
    ├── WAL (Write-Ahead Log)
    │   ├── Sequential Write (顺序写)
    │   └── Crash Recovery (崩溃恢复)
    │
    └── Bloom Filters (布隆过滤器)
        └── 加速查找
```

### 2.2 接口定义

#### StorageEngine 接口

```dart
/// 存储引擎接口
abstract class IStorageEngine {
  /// 写入节点
  Future<void> put(Node node);

  /// 批量写入
  Future<void> putBatch(List<Node> nodes);

  /// 读取节点
  Future<Node?> get(String id);

  /// 删除节点
  Future<void> delete(String id);

  /// 批量删除
  Future<void> deleteBatch(List<String> ids);

  /// 范围查询
  Future<List<Node>> scan({
    String? startId,
    String? endId,
    int limit = 100,
  });

  /// 强制刷新 MemTable
  Future<void> flush();

  /// 创建快照
  Future<StorageSnapshot> createSnapshot();

  /// 恢复快照
  Future<void> restoreSnapshot(StorageSnapshot snapshot);

  /// 关闭存储引擎
  Future<void> close();

  /// 获取统计信息
  StorageStats get stats;
}

/// 存储统计信息
class StorageStats {
  final int memTableSize;
  final int walSize;
  final int sstableCount;
  final int totalNodes;
  final int diskUsageBytes;

  StorageStats({
    required this.memTableSize,
    required this.walSize,
    required this.sstableCount,
    required this.totalNodes,
    required this.diskUsageBytes,
  });
}

/// 存储快照
class StorageSnapshot {
  final Map<String, Node> nodes;
  final DateTime createdAt;

  StorageSnapshot({
    required this.nodes,
    required this.createdAt,
  });
}
```

## 3. 核心组件

### 3.1 WAL (Write-Ahead Log)

#### 职责
- 顺序记录所有写操作
- 崩溃恢复时重放
- 保证数据持久性

#### 数据结构

```dart
/// WAL 条目
class WalEntry {
  final WalEntryType type;
  final String key;
  final List<int> value; // 序列化的 Node
  final DateTime timestamp;

  WalEntry({
    required this.type,
    required this.key,
    required this.value,
    required this.timestamp,
  });

  /// 序列化为字节
  List<int> serialize() {
    // 格式: [type(1)][keyLength(4)][key][valueLength(4)][value][timestamp(8)]
    final buffer = BytesBuilder();
    buffer.addByte(type.index);
    final keyBytes = utf8.encode(key);
    buffer.add(_intToBytes(keyBytes.length));
    buffer.add(keyBytes);
    buffer.add(_intToBytes(value.length));
    buffer.add(value);
    buffer.add(_intToBytes(timestamp.millisecondsSinceEpoch));
    return buffer.toBytes();
  }

  /// 从字节反序列化
  static WalEntry deserialize(List<int> bytes) {
    // ... 反序列化逻辑
  }
}

enum WalEntryType {
  put,
  delete,
}

/// WAL 文件
class WalFile {
  final File file;
  final RandomAccessFile raf;
  bool isOpen = false;

  WalFile(this.file) : raf = file.openSync(mode: FileMode.append) {
    isOpen = true;
  }

  /// 追加条目
  Future<void> append(WalEntry entry) async {
    if (!isOpen) throw StateError('WAL 已关闭');

    final bytes = entry.serialize();
    await raf.writeFrom(bytes);
    await raf.flush();
  }

  /// 读取所有条目
  Future<List<WalEntry>> readAll() async {
    await raf.setPosition(0);
    final entries = <WalEntry>[];

    while (true) {
      final position = raf.position();
      if (position >= await raf.length()) break;

      // 读取条目长度
      final lengthBytes = await raf.read(4);
      if (lengthBytes.length < 4) break;

      final length = _bytesToInt(lengthBytes);
      final data = await raf.read(length);
      entries.add(WalEntry.deserialize(data));
    }

    return entries;
  }

  /// 截断 WAL（清空）
  Future<void> truncate() async {
    await raf.close();
    await file.writeAsBytes([]);
    raf = file.openSync(mode: FileMode.append);
    isOpen = true;
  }

  Future<void> close() async {
    isOpen = false;
    await raf.close();
  }

  static List<int> _intToBytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  static int _bytesToInt(List<int> bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }
}
```

#### 崩溃恢复算法

**问题描述**:
系统崩溃后，如何从 WAL 恢复 MemTable 状态。

**算法描述**:
1. 读取 WAL 文件
2. 按顺序重放所有条目
3. 重建 MemTable
4. 删除已恢复的 WAL

**伪代码**:
```
function recoverFromWAL(walFile, memTable):
    entries = walFile.readAll()

    for entry in entries:
        if entry.type == PUT:
            memTable.put(entry.key, entry.value)
        else if entry.type == DELETE:
            memTable.delete(entry.key)

    // WAL 重放完成，截断 WAL
    walFile.truncate()

    return memTable
```

**复杂度分析**:
- 时间复杂度: O(n)，n 为 WAL 条目数
- 空间复杂度: O(m)，m 为 MemTable 大小

### 3.2 MemTable (内存表)

#### 职责
- 缓冲写入操作
- 提供快速读取
- 触发刷新到磁盘

#### 数据结构

```dart
/// MemTable - 基于 Hash Map 的内存表
class MemTable {
  final Map<String, _MemEntry> _table = {};
  final int _maxSizeBytes;
  int _currentSizeBytes = 0;

  MemTable({required int maxSizeBytes})
      : _maxSizeBytes = maxSizeBytes;

  /// 写入键值对
  void put(String key, Node value) {
    final serialized = jsonEncode(value.toJson());
    final size = serialized.length;

    // 检查是否需要刷新
    if (_currentSizeBytes + size > _maxSizeBytes) {
      throw MemTableFullException();
    }

    _table[key] = _MemEntry(
      key: key,
      value: value,
      size: size,
      timestamp: DateTime.now(),
    );

    _currentSizeBytes += size;
  }

  /// 读取键值
  Node? get(String key) {
    final entry = _table[key];
    return entry?.value;
  }

  /// 删除键值
  void delete(String key) {
    final entry = _table[key];
    if (entry != null) {
      _currentSizeBytes -= entry.size;
      _table.remove(key);
    }
  }

  /// 检查是否已满
  bool get isFull => _currentSizeBytes >= _maxSizeBytes;

  /// 获取所有条目
  List<_MemEntry> getAll() => _table.values.toList();

  /// 清空表
  void clear() {
    _table.clear();
    _currentSizeBytes = 0;
  }

  /// 获取大小
  int get sizeBytes => _currentSizeBytes;
}

/// MemTable 条目
class _MemEntry {
  final String key;
  final Node value;
  final int size;
  final DateTime timestamp;

  _MemEntry({
    required this.key,
    required this.value,
    required this.size,
    required this.timestamp,
  });
}
```

#### 刷新算法

**问题描述**:
MemTable 满时，如何高效刷新到磁盘。

**算法描述**:
1. 创建 Immutable MemTable
2. 新建空的 MemTable 接收写入
3. 异步将 Immutable MemTable 写入 SSTable
4. 写入完成后删除 Immutable MemTable

**伪代码**:
```
function flushMemTable(memTable):
    // 1. 切换 MemTable
    immutableMemTable = memTable
    memTable = new MemTable()

    // 2. 异步写入磁盘
    async {
        sstable = writeToSSTable(immutableMemTable)
        addSSTable(sstable, level=0)
        delete immutableMemTable
    }
```

**复杂度分析**:
- 时间复杂度: O(n log n)，n 为 MemTable 条目数（排序）
- 空间复杂度: O(n)，临时 SSTable 文件

### 3.3 SSTable (Sorted String Table)

#### 职责
- 不可变的磁盘存储
- 有序存储键值对
- 支持范围查询

#### 数据结构

```dart
/// SSTable - 不可变的磁盘表
class SSTable {
  final File file;
  final int level;
  final int startKey;
  final int endKey;
  final int numEntries;
  final BloomFilter bloomFilter;
  final IndexBlock indexBlock;

  SSTable({
    required this.file,
    required this.level,
    required this.startKey,
    required this.endKey,
    required this.numEntries,
    required this.bloomFilter,
    required this.indexBlock,
  });

  /// 查找键
  Future<Node?> get(String key) async {
    // 1. 布隆过滤器快速判断
    if (!bloomFilter.mightContain(key)) {
      return null;
    }

    // 2. 查找索引块
    final blockOffset = indexBlock.findBlock(key);

    // 3. 读取数据块
    final block = await _readBlock(blockOffset);

    // 4. 在块中查找
    return block.find(key);
  }

  /// 范围查询
  Future<List<Node>> scan({
    String? startKey,
    String? endKey,
    int limit = 100,
  }) async {
    final results = <Node>[];

    // 使用索引块定位起始位置
    var blockOffset = indexBlock.findBlock(startKey ?? this.startKey);

    while (results.length < limit) {
      final block = await _readBlock(blockOffset);
      final entries = block.scan(startKey, endKey, limit - results.length);
      results.addAll(entries);

      if (entries.isEmpty || block.isLast) break;

      blockOffset = block.nextBlockOffset;
    }

    return results;
  }

  Future<DataBlock> _readBlock(int offset) async {
    final raf = await file.open();
    await raf.setPosition(offset);
    final sizeBytes = await raf.read(4);
    final size = _bytesToInt(sizeBytes);
    final data = await raf.read(size);
    await raf.close();
    return DataBlock.fromBytes(data);
  }

  static int _bytesToInt(List<int> bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }
}

/// 数据块
class DataBlock {
  final List<_SSTableEntry> entries;
  final int nextBlockOffset;
  final bool isLast;

  DataBlock({
    required this.entries,
    required this.nextBlockOffset,
    required this.isLast,
  });

  Node? find(String key) {
    // 二分查找
    int left = 0;
    int right = entries.length - 1;

    while (left <= right) {
      final mid = (left + right) ~/ 2;
      final cmp = entries[mid].key.compareTo(key);

      if (cmp == 0) {
        return entries[mid].value;
      } else if (cmp < 0) {
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return null;
  }

  List<Node> scan(String? startKey, String? endKey, int limit) {
    final results = <Node>[];

    for (final entry in entries) {
      if (startKey != null && entry.key.compareTo(startKey) < 0) continue;
      if (endKey != null && entry.key.compareTo(endKey) > 0) continue;
      results.add(entry.value);
      if (results.length >= limit) break;
    }

    return results;
  }

  static DataBlock fromBytes(List<int> bytes) {
    // ... 反序列化逻辑
  }
}

/// 索引块
class IndexBlock {
  final List<_IndexEntry> entries;

  IndexBlock(this.entries);

  int findBlock(String key) {
    // 找到包含 key 的块
    for (final entry in entries) {
      if (key.compareTo(entry.startKey) >= 0 &&
          key.compareTo(entry.endKey) <= 0) {
        return entry.offset;
      }
    }
    return entries.first.offset;
  }
}

class _IndexEntry {
  final String startKey;
  final String endKey;
  final int offset;
}

class _SSTableEntry {
  final String key;
  final Node value;
}
```

### 3.4 Bloom Filter (布隆过滤器)

#### 职责
- 快速判断键是否可能存在
- 减少 SSTable 的磁盘读取

#### 数据结构

```dart
/// 布隆过滤器
class BloomFilter {
  final List<bool> _bits;
  final int _hashFunctions;

  BloomFilter({
    required int size,
    required int hashFunctions,
  })  : _bits = List.filled(size, false),
        _hashFunctions = hashFunctions;

  /// 添加元素
  void add(String key) {
    final hashes = _hashes(key);
    for (final hash in hashes) {
      _bits[hash % _bits.length] = true;
    }
  }

  /// 检查元素是否可能存在
  bool mightContain(String key) {
    final hashes = _hashes(key);
    for (final hash in hashes) {
      if (!_bits[hash % _bits.length]) {
        return false;
      }
    }
    return true;
  }

  /// 计算多个哈希值
  List<int> _hashes(String key) {
    final bytes = utf8.encode(key);
    final hash1 = _jenkinsHash(bytes);
    final hash2 = _murmurHash(bytes);

    final hashes = <int>[];
    for (int i = 0; i < _hashFunctions; i++) {
      hashes.add(hash1 + i * hash2);
    }
    return hashes;
  }

  /// Jenkins Hash
  int _jenkinsHash(List<int> key) {
    var hash = 0;
    for (final byte in key) {
      hash += byte;
      hash += (hash << 10);
      hash ^= (hash >> 6);
    }
    hash += (hash << 3);
    hash ^= (hash >> 11);
    hash += (hash << 15);
    return hash;
  }

  /// MurmurHash3 (简化版)
  int _murmurHash(List<int> key) {
    const uint32Max = 0xFFFFFFFF;
    var h = 0x12345678;
    final length = key.length;

    for (var i = 0; i < length; i++) {
      var k = key[i] & 0xFF;
      k = (k * 0xCC9E2D51) & uint32Max;
      k = ((k << 15) | (k >> 17)) & uint32Max;
      k = (k * 0x1B873593) & uint32Max;

      h ^= k;
      h = ((h << 13) | (h >> 19)) & uint32Max;
      h = (h * 5 + 0xE6546B64) & uint32Max;
    }

    h ^= length;
    h ^= (h >> 16);
    h = (h * 0x85EBCA6B) & uint32Max;
    h ^= (h >> 13);
    h = (h * 0xC2B2AE35) & uint32Max;
    h ^= (h >> 16);

    return h;
  }

  /// 序列化
  List<int> toBytes() {
    final bytes = <int>[];
    for (final bit in _bits) {
      bytes.add(bit ? 1 : 0);
    }
    return bytes;
  }

  /// 反序列化
  static BloomFilter fromBytes(List<int> bytes, int hashFunctions) {
    final bits = bytes.map((b) => b == 1).toList();
    return BloomFilter(
      size: bits.length,
      hashFunctions: hashFunctions,
    ).._bits.clear().._bits.addAll(bits);
  }
}
```

## 4. 核心算法

### 4.1 写入流程

**问题描述**:
如何高效写入数据并保证持久性。

**算法描述**:
1. 写入 WAL
2. 写入 MemTable
3. 检查是否需要刷新
4. 如果需要，触发异步刷新

**伪代码**:
```
function put(key, value):
    // 1. 写入 WAL
    wal.append(WalEntry(PUT, key, value))

    // 2. 写入 MemTable
    memTable.put(key, value)

    // 3. 检查是否需要刷新
    if memTable.isFull():
        flushMemTable(memTable)
```

**复杂度分析**:
- 时间复杂度: O(1) 平均情况
- 空间复杂度: O(1)

### 4.2 读取流程

**问题描述**:
如何快速读取数据。

**算法描述**:
1. 查询 MemTable
2. 查询 Immutable MemTable
3. 查询 SSTable（从 Level 0 到最高级）
4. 返回最新版本

**伪代码**:
```
function get(key):
    // 1. 查询 MemTable
    value = memTable.get(key)
    if value != null:
        return value

    // 2. 查询 Immutable MemTable
    value = immutableMemTable.get(key)
    if value != null:
        return value

    // 3. 查询 SSTables
    for level in [0, 1, 2, ...]:
        for sstable in sstables[level]:
            value = sstable.get(key)
            if value != null:
                return value

    return null
```

**复杂度分析**:
- 时间复杂度: O(L * S)，L 为层数，S 为每层 SSTable 数量
- 空间复杂度: O(1)

### 4.3 压缩算法

**问题描述**:
如何合并多层 SSTable 以减少空间和查询时间。

**算法描述**:
1. 选择要压缩的 SSTable
2. 合并排序所有条目
3. 删除旧版本
4. 写入新的 SSTable

**伪代码**:
```
function compact(level):
    // 1. 选择 SSTable
    sstables = selectSSTablesForCompaction(level)

    // 2. 合并条目
    entries = []
    for sstable in sstables:
        entries.addAll(sstable.getAll())

    // 3. 排序并去重（保留最新版本）
    entries.sort(by key)
    entries = deduplicate(entries)

    // 4. 写入新 SSTable
    newSSTable = writeSSTable(entries, level + 1)

    // 5. 删除旧 SSTable
    for sstable in sstables:
        delete sstable

    addSSTable(newSSTable, level + 1)
```

**复杂度分析**:
- 时间复杂度: O(n log n)，n 为总条目数
- 空间复杂度: O(n)，临时存储

## 5. 并发模型

### 5.1 写操作串行化

**策略**:
- 使用 WriteQueue 串行化所有写操作
- 读操作无锁（Atomic 变量）

**实现**:

```dart
class WriteQueue {
  final Queue<Future<void> Function()> _queue = Queue();
  bool _isProcessing = false;

  Future<T> enqueue<T>(Future<T> Function() operation) async {
    final completer = Completer<T>();

    _queue.add(() async {
      final result = await operation();
      completer.complete(result);
    });

    _processQueue();
    return completer.future;
  }

  void _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;

    while (_queue.isNotEmpty) {
      final operation = _queue.removeFirst();
      await operation();
    }

    _isProcessing = false;
  }
}
```

### 5.2 读操作无锁

**策略**:
- 使用不可变数据结构
- Atomic 指针切换
- Copy-on-Write

**实现**:

```dart
class LSMTreeStorage {
  final WriteQueue _writeQueue = WriteQueue();
  MemTable _memTable = MemTable();
  ImmutableMemTable? _immutableMemTable;

  Future<void> put(String key, Node value) async {
    await _writeQueue.enqueue(() async {
      // 写操作串行化
      _memTable.put(key, value);
      if (_memTable.isFull) {
        _flushMemTable();
      }
    });
  }

  Future<Node?> get(String key) async {
    // 读操作无锁
    // 1. 查询 MemTable
    final value = _memTable.get(key);
    if (value != null) return value;

    // 2. 查询 Immutable MemTable
    final immutable = _immutableMemTable;
    if (immutable != null) {
      final value = immutable.get(key);
      if (value != null) return value;
    }

    // 3. 查询 SSTables
    return await _searchSSTables(key);
  }

  void _flushMemTable() {
    // 切换 MemTable（原子操作）
    final oldMemTable = _memTable;
    _memTable = MemTable();

    // 创建 Immutable MemTable
    _immutableMemTable = ImmutableMemTable.from(oldMemTable);

    // 异步写入磁盘
    _flushToDisk(_immutableMemTable!);
  }
}
```

## 6. 错误处理

### 6.1 写入失败处理

**策略**:
1. WAL 写入失败 → 拒绝操作
2. MemTable 写入失败 → 触发刷新
3. SSTable 写入失败 → 重试

**实现**:

```dart
Future<void> put(String key, Node value) async {
  try {
    // 1. 写入 WAL
    await _wal.append(WalEntry.put(key, value));
  } catch (e) {
    throw StorageException('WAL 写入失败', e);
  }

  try {
    // 2. 写入 MemTable
    _memTable.put(key, value);
  } on MemTableFullException {
    // 3. MemTable 满了，刷新
    await _flushMemTable();
    _memTable.put(key, value);
  }
}
```

### 6.2 崩溃恢复

**策略**:
1. 启动时检查 WAL
2. 如果 WAL 存在，重放
3. 重放完成后删除 WAL

**实现**:

```dart
Future<void> recover() async {
  final walExists = await _wal.file.exists();

  if (walExists) {
    // 重放 WAL
    final entries = await _wal.readAll();
    for (final entry in entries) {
      if (entry.type == WalEntryType.put) {
        final node = Node.fromJson(jsonDecode(entry.value));
        _memTable.put(entry.key, node);
      } else if (entry.type == WalEntryType.delete) {
        _memTable.delete(entry.key);
      }
    }

    // 删除 WAL
    await _wal.truncate();
  }
}
```

## 7. 性能考虑

### 7.1 概念性性能指标

| 操作 | 目标延迟 | 说明 |
|------|----------|------|
| 写入 | < 5ms | 包含 WAL 和 MemTable |
| 读取（内存命中） | < 1ms | MemTable 命中 |
| 读取（磁盘） | < 10ms | SSTable 查询 |
| 刷新 | < 100ms | MemTable → SSTable |
| 压缩 | < 1s | 小型压缩 |

### 7.2 优化方向

1. **批量写入**:
   - 批量写入 WAL
   - 减少磁盘同步次数

2. **缓存优化**:
   - Block Cache
   - Index Cache
   - Bloom Filter

3. **压缩策略**:
   - 分层压缩
   - 增量压缩
   - 后台压缩

### 7.3 瓶颈分析

**潜在瓶颈**:
- WAL 顺序写入
- MemTable 排序
- SSTable 合并

**解决方案**:
- WAL 批量写入
- MemTable 跳表
- 并行压缩

## 8. 关键文件清单

```
lib/core/storage/
├── storage_engine.dart         # IStorageEngine 接口
├── lsm_tree/
│   ├── lsm_tree.dart          # LSMTree 主类
│   ├── mem_table.dart         # MemTable 实现
│   ├── immutable_mem_table.dart # ImmutableMemTable 实现
│   ├── sstable/
│   │   ├── sstable.dart       # SSTable 实现
│   │   ├── data_block.dart    # 数据块
│   │   └── index_block.dart   # 索引块
│   ├── wal/
│   │   ├── wal.dart           # WAL 文件
│   │   └── wal_entry.dart     # WAL 条目
│   ├── bloom_filter.dart      # 布隆过滤器
│   ├── compaction.dart        # 压缩算法
│   └── write_queue.dart       # 写队列
└── exceptions.dart            # 存储异常定义
```

## 9. 参考资料

### LSM Tree 论文
- "The Log-Structured Merge-Tree (LSM-Tree)" - O'Neil et al., 1996

### 实现参考
- LevelDB Architecture
- RocksDB Documentation
- Apache HBase

### 相关技术
- Bloom Filters - Burton H. Bloom, 1970
- Skip Lists - William Pugh, 1990

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
