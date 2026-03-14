# 版本控制设计文档

## 1. 概述

### 1.1 职责
版本控制是系统数据历史管理的核心组件，负责：
- 记录所有数据变更的历史
- 支持数据的时间旅行查询
- 提供版本回滚功能
- 管理历史数据的生命周期
- 支持分支和合并（可选）

### 1.2 目标
- **写入性能**: 版本记录延迟 < 2ms
- **查询性能**: 历史版本查询延迟 < 5ms
- **空间效率**: 版本存储开销 < 50%
- **可靠性**: 版本数据不丢失

### 1.3 关键挑战
- **存储空间**: 历史版本的累积
- **查询效率**: 跨版本的查询优化
- **清理策略**: 旧版本的安全删除
- **一致性**: 版本链的完整性

## 2. 架构设计

### 2.1 组件结构

```
VersionControl
    │
    ├── Version Store (版本存储)
    │   ├── Append-Only Log (追加日志)
    │   └── Version Index (版本索引)
    │
    ├── Version Chain (版本链)
    │   ├── Head (最新版本)
    │   ├── Previous (前一版本)
    │   └── Versions (所有版本)
    │
    ├── Snapshot Manager (快照管理)
    │   ├── Snapshots (快照列表)
    │   └── Retention Policy (保留策略)
    │
    └── Garbage Collector (垃圾回收)
        ├── expired Versions (过期版本)
        └── orphaned Data (孤立数据)
```

### 2.2 接口定义

#### VersionInfo 定义

```dart
/// 版本信息
class VersionInfo {
  /// 版本号
  final int version;

  /// 父版本号
  final int parentVersion;

  /// 创建时间
  final DateTime createdAt;

  /// 创建者
  final String? author;

  /// 变更摘要
  final String? summary;

  /// 变更类型
  final VersionChangeType changeType;

  VersionInfo({
    required this.version,
    required this.parentVersion,
    required this.createdAt,
    this.author,
    this.summary,
    required this.changeType,
  });

  /// 序列化
  Map<String, dynamic> toJson() => {
        'version': version,
        'parentVersion': parentVersion,
        'createdAt': createdAt.toIso8601String(),
        'author': author,
        'summary': summary,
        'changeType': changeType.index,
      };

  /// 反序列化
  static VersionInfo fromJson(Map<String, dynamic> json) => VersionInfo(
        version: json['version'] as int,
        parentVersion: json['parentVersion'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        author: json['author'] as String?,
        summary: json['summary'] as String?,
        changeType: VersionChangeType.values[json['changeType'] as int],
      );
}

/// 版本变更类型
enum VersionChangeType {
  /// 创建
  create,

  /// 更新
  update,

  /// 删除
  delete,

  /// 恢复
  restore,
}
```

#### VersionedNode 定义

```dart
/// 带版本信息的节点
class VersionedNode {
  /// 节点 ID
  final String id;

  /// 当前版本
  final Node currentNode;

  /// 版本历史
  final List<VersionInfo> versions;

  VersionedNode({
    required this.id,
    required this.currentNode,
    required this.versions,
  });

  /// 获取特定版本的节点
  Node? getVersion(int version) {
    // TODO: 从版本存储中加载
    return null;
  }

  /// 获取所有版本
  List<int> get versionNumbers =>
      versions.map((v) => v.version).toList();
}
```

#### IVersionControl 接口

```dart
/// 版本控制接口
abstract class IVersionControl {
  /// 创建新版本
  Future<VersionInfo> createVersion(
    String nodeId,
    Node node, {
    String? author,
    String? summary,
    VersionChangeType changeType = VersionChangeType.update,
  });

  /// 获取节点的当前版本
  Future<Node?> getCurrentVersion(String nodeId);

  /// 获取节点的特定版本
  Future<Node?> getVersion(String nodeId, int version);

  /// 获取节点的版本历史
  Future<List<VersionInfo>> getVersionHistory(String nodeId);

  /// 获取节点的所有版本号
  Future<List<int>> getVersionNumbers(String nodeId);

  /// 回滚到特定版本
  Future<Node> rollbackToVersion(
    String nodeId,
    int version, {
    String? author,
    String? summary,
  });

  /// 比较两个版本
  Future<VersionDiff> compareVersions(
    String nodeId,
    int version1,
    int version2,
  );

  /// 创建快照
  Future<String> createSnapshot({
    String? name,
    String? description,
  });

  /// 恢复快照
  Future<void> restoreSnapshot(String snapshotId);

  /// 删除快照
  Future<void> deleteSnapshot(String snapshotId);

  /// 获取所有快照
  Future<List<SnapshotInfo>> getSnapshots();

  /// 清理过期版本
  Future<void> cleanupExpiredVersions({
    int? keepVersions,
    Duration? maxAge,
  });

  /// 获取统计信息
  VersionStats get stats;
}

/// 版本差异
class VersionDiff {
  final int version1;
  final int version2;
  final List<FieldDiff> fieldDiffs;

  VersionDiff({
    required this.version1,
    required this.version2,
    required this.fieldDiffs,
  });
}

/// 字段差异
class FieldDiff {
  final String field;
  final DiffType type;
  final dynamic oldValue;
  final dynamic newValue;

  FieldDiff({
    required this.field,
    required this.type,
    this.oldValue,
    this.newValue,
  });
}

enum DiffType {
  added,
  removed,
  modified,
  unchanged,
}

/// 快照信息
class SnapshotInfo {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final int nodeCount;

  SnapshotInfo({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.nodeCount,
  });
}

/// 版本统计信息
class VersionStats {
  final int totalVersions;
  final int totalSnapshots;
  final int averageVersionsPerNode;
  final int storageUsageBytes;

  VersionStats({
    required this.totalVersions,
    required this.totalSnapshots,
    required this.averageVersionsPerNode,
    required this.storageUsageBytes,
  });
}
```

## 3. 核心数据结构

### 3.1 Append-Only Log（追加日志）

**描述**:
所有版本数据以追加方式写入日志文件，保证数据不可变。

**数据结构**:

```dart
/// 版本日志条目
class VersionLogEntry {
  final String nodeId;
  final int version;
  final Node data;
  final VersionInfo info;

  VersionLogEntry({
    required this.nodeId,
    required this.version,
    required this.data,
    required this.info,
  });

  /// 序列化
  List<int> serialize() {
    // 格式: [length(4)][nodeId][version(4)][data][info]
    final buffer = BytesBuilder();

    // 节点 ID
    final nodeIdBytes = utf8.encode(nodeId);
    buffer.add(_intToBytes(nodeIdBytes.length));
    buffer.add(nodeIdBytes);

    // 版本号
    buffer.add(_intToBytes(version));

    // 数据
    final dataBytes = utf8.encode(jsonEncode(data.toJson()));
    buffer.add(_intToBytes(dataBytes.length));
    buffer.add(dataBytes);

    // 版本信息
    final infoBytes = utf8.encode(jsonEncode(info.toJson()));
    buffer.add(_intToBytes(infoBytes.length));
    buffer.add(infoBytes);

    return buffer.toBytes();
  }

  /// 反序列化
  static VersionLogEntry deserialize(List<int> bytes) {
    int offset = 0;

    // 节点 ID
    final nodeIdLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;
    final nodeId = utf8.decode(bytes.sublist(offset, offset + nodeIdLength));
    offset += nodeIdLength;

    // 版本号
    final version = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;

    // 数据
    final dataLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;
    final dataBytes = bytes.sublist(offset, offset + dataLength);
    offset += dataLength;
    final data = Node.fromJson(jsonDecode(utf8.decode(dataBytes)));

    // 版本信息
    final infoLength = _bytesToInt(bytes.sublist(offset, offset + 4));
    offset += 4;
    final infoBytes = bytes.sublist(offset, offset + infoLength);
    final info = VersionInfo.fromJson(jsonDecode(utf8.decode(infoBytes)));

    return VersionLogEntry(
      nodeId: nodeId,
      version: version,
      data: data,
      info: info,
    );
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

/// 版本日志文件
class VersionLogFile {
  final File file;
  RandomAccessFile? _raf;

  VersionLogFile(this.file);

  /// 追加条目
  Future<void> append(VersionLogEntry entry) async {
    _raf ??= await file.open(mode: FileMode.append);

    final bytes = entry.serialize();
    await _raf!.writeFrom(bytes);
    await _raf!.flush();
  }

  /// 读取所有条目
  Future<List<VersionLogEntry>> readAll() async {
    await _close();

    final bytes = await file.readAsBytes();
    final entries = <VersionLogEntry>[];

    int offset = 0;
    while (offset < bytes.length) {
      // 读取条目长度
      if (offset + 4 > bytes.length) break;

      final length = _bytesToInt(bytes.sublist(offset, offset + 4));
      offset += 4;

      if (offset + length > bytes.length) break;

      final entryBytes = bytes.sublist(offset, offset + length);
      entries.add(VersionLogEntry.deserialize(entryBytes));
      offset += length;
    }

    return entries;
  }

  /// 关闭文件
  Future<void> _close() async {
    await _raf?.close();
    _raf = null;
  }

  static int _bytesToInt(List<int> bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }
}
```

### 3.2 Version Index（版本索引）

**描述**:
快速定位特定版本的节点数据。

**数据结构**:

```dart
/// 版本索引
class VersionIndex {
  /// nodeId -> 版本号 -> 文件偏移
  final Map<String, Map<int, int>> _index = {};

  /// 添加索引
  void add(String nodeId, int version, int offset) {
    _index
        .putIfAbsent(nodeId, () => {})
        [version] = offset;
  }

  /// 查找偏移
  int? find(String nodeId, int version) {
    return _index[nodeId]?[version];
  }

  /// 获取所有版本
  List<int>? getVersions(String nodeId) {
    return _index[nodeId]?.keys.toList();
  }

  /// 删除节点索引
  void remove(String nodeId) {
    _index.remove(nodeId);
  }

  /// 清空索引
  void clear() {
    _index.clear();
  }
}
```

### 3.3 Version Chain（版本链）

**描述**:
维护节点的版本链结构。

**数据结构**:

```dart
/// 版本链
class VersionChain {
  final String nodeId;
  final List<VersionInfo> versions;

  VersionChain({
    required this.nodeId,
    required this.versions,
  });

  /// 添加版本
  void add(VersionInfo info) {
    versions.add(info);
  }

  /// 获取最新版本
  VersionInfo? get latest => versions.isNotEmpty ? versions.last : null;

  /// 获取版本号
  int get currentVersion => latest?.version ?? 0;

  /// 查找版本
  VersionInfo? find(int version) {
    for (final info in versions) {
      if (info.version == version) {
        return info;
      }
    }
    return null;
  }

  /// 获取版本范围
  List<VersionInfo> getRange(int start, int end) {
    return versions.skip(start).take(end - start).toList();
  }
}
```

## 4. 核心算法

### 4.1 创建版本

**问题描述**:
如何高效创建新版本并维护版本链。

**算法描述**:
1. 生成新版本号（当前版本 + 1）
2. 序列化节点数据
3. 追加到版本日志
4. 更新版本索引
5. 更新版本链

**伪代码**:
```
function createVersion(nodeId, node, author, summary, changeType):
    // 1. 获取版本链
    chain = getVersionChain(nodeId)
    currentVersion = chain.currentVersion
    newVersion = currentVersion + 1

    // 2. 创建版本信息
    info = VersionInfo(
        version: newVersion,
        parentVersion: currentVersion,
        createdAt: now(),
        author: author,
        summary: summary,
        changeType: changeType,
    )

    // 3. 写入日志
    entry = VersionLogEntry(
        nodeId: nodeId,
        version: newVersion,
        data: node,
        info: info,
    )
    offset = logFile.append(entry)

    // 4. 更新索引
    index.add(nodeId, newVersion, offset)

    // 5. 更新版本链
    chain.add(info)

    return info
```

**复杂度分析**:
- 时间复杂度: O(1) 追加写入
- 空间复杂度: O(1) 每次操作

**实现**:

```dart
@override
Future<VersionInfo> createVersion(
  String nodeId,
  Node node, {
  String? author,
  String? summary,
  VersionChangeType changeType = VersionChangeType.update,
}) async {
  // 1. 获取版本链
  final chain = await _getVersionChain(nodeId);
  final currentVersion = chain.currentVersion;
  final newVersion = currentVersion + 1;

  // 2. 创建版本信息
  final info = VersionInfo(
    version: newVersion,
    parentVersion: currentVersion,
    createdAt: DateTime.now(),
    author: author,
    summary: summary,
    changeType: changeType,
  );

  // 3. 写入日志
  final entry = VersionLogEntry(
    nodeId: nodeId,
    version: newVersion,
    data: node,
    info: info,
  );

  final offset = await _logFile.append(entry);

  // 4. 更新索引
  _index.add(nodeId, newVersion, offset);

  // 5. 更新版本链
  chain.add(info);
  _chains[nodeId] = chain;

  return info;
}
```

### 4.2 获取版本

**问题描述**:
如何快速加载特定版本的节点数据。

**算法描述**:
1. 查询版本索引获取偏移
2. 从日志文件读取数据
3. 反序列化返回

**伪代码**:
```
function getVersion(nodeId, version):
    // 1. 查找索引
    offset = index.find(nodeId, version)
    if offset == null:
        return null

    // 2. 读取日志
    entry = logFile.readAt(offset)

    return entry.data
```

**复杂度分析**:
- 时间复杂度: O(1) 索引查找 + O(n) 文件读取（n 为数据大小）
- 空间复杂度: O(n) 数据大小

**实现**:

```dart
@override
Future<Node?> getVersion(String nodeId, int version) async {
  // 1. 查找索引
  final offset = _index.find(nodeId, version);
  if (offset == null) {
    return null;
  }

  // 2. 读取日志
  final entry = await _logFile.readAt(offset);

  return entry.data;
}
```

### 4.3 回滚版本

**问题描述**:
如何将节点回滚到历史版本。

**算法描述**:
1. 加载目标版本数据
2. 创建新版本（复制目标版本）
3. 标记为恢复操作

**伪代码**:
```
function rollbackToVersion(nodeId, targetVersion, author, summary):
    // 1. 加载目标版本
    targetNode = getVersion(nodeId, targetVersion)
    if targetNode == null:
        throw VersionNotFoundException()

    // 2. 创建新版本（复制目标版本）
    newInfo = createVersion(
        nodeId,
        targetNode,
        author: author,
        summary: summary,
        changeType: RESTORE,
    )

    // 3. 返回新版本
    return getCurrentVersion(nodeId)
```

**复杂度分析**:
- 时间复杂度: O(n) 读取目标版本 + O(1) 写入新版本
- 空间复杂度: O(n) 新版本数据

**实现**:

```dart
@override
Future<Node> rollbackToVersion(
  String nodeId,
  int version, {
  String? author,
  String? summary,
}) async {
  // 1. 加载目标版本
  final targetNode = await getVersion(nodeId, version);
  if (targetNode == null) {
    throw VersionNotFoundException('版本不存在: $version');
  }

  // 2. 创建新版本
  final defaultSummary = summary ?? '回滚到版本 $version';
  await createVersion(
    nodeId,
    targetNode,
    author: author,
    summary: defaultSummary,
    changeType: VersionChangeType.restore,
  );

  // 3. 返回当前版本
  final current = await getCurrentVersion(nodeId);
  return current!;
}
```

### 4.4 版本比较

**问题描述**:
如何比较两个版本的差异。

**算法描述**:
1. 加载两个版本
2. 递归比较字段
3. 生成差异报告

**伪代码**:
```
function compareVersions(nodeId, version1, version2):
    // 1. 加载版本
    node1 = getVersion(nodeId, version1)
    node2 = getVersion(nodeId, version2)

    // 2. 比较字段
    diffs = []
    for field in allFields:
        value1 = node1[field]
        value2 = node2[field]

        if value1 == value2:
            diffs.add(FieldDiff(field, UNCHANGED, value1, value2))
        elif value1 == null:
            diffs.add(FieldDiff(field, ADDED, null, value2))
        elif value2 == null:
            diffs.add(FieldDiff(field, REMOVED, value1, null))
        else:
            diffs.add(FieldDiff(field, MODIFIED, value1, value2))

    return VersionDiff(version1, version2, diffs)
```

**复杂度分析**:
- 时间复杂度: O(n) n 为字段数量
- 空间复杂度: O(n)

**实现**:

```dart
@override
Future<VersionDiff> compareVersions(
  String nodeId,
  int version1,
  int version2,
) async {
  // 1. 加载版本
  final node1 = await getVersion(nodeId, version1);
  final node2 = await getVersion(nodeId, version2);

  if (node1 == null || node2 == null) {
    throw VersionNotFoundException('版本不存在');
  }

  // 2. 比较字段
  final diffs = <FieldDiff>[];

  final json1 = node1.toJson();
  final json2 = node2.toJson();

  final allKeys = {...json1.keys, ...json2.keys};

  for (final field in allKeys) {
    final value1 = json1[field];
    final value2 = json2[field];

    if (value1 == value2) {
      diffs.add(FieldDiff(
        field: field,
        type: DiffType.unchanged,
        oldValue: value1,
        newValue: value2,
      ));
    } else if (value1 == null) {
      diffs.add(FieldDiff(
        field: field,
        type: DiffType.added,
        newValue: value2,
      ));
    } else if (value2 == null) {
      diffs.add(FieldDiff(
        field: field,
        type: DiffType.removed,
        oldValue: value1,
      ));
    } else {
      diffs.add(FieldDiff(
        field: field,
        type: DiffType.modified,
        oldValue: value1,
        newValue: value2,
      ));
    }
  }

  return VersionDiff(
    version1: version1,
    version2: version2,
    fieldDiffs: diffs,
  );
}
```

## 5. 快照管理

### 5.1 创建快照

**描述**:
保存整个系统的当前状态。

**实现**:

```dart
@override
Future<String> createSnapshot({
  String? name,
  String? description,
}) async {
  final snapshotId = _generateSnapshotId();

  // 1. 获取所有节点的当前版本
  final nodes = await _getAllCurrentNodes();

  // 2. 创建快照元数据
  final snapshot = SnapshotInfo(
    id: snapshotId,
    name: name ?? 'Snapshot ${DateTime.now()}',
    description: description,
    createdAt: DateTime.now(),
    nodeCount: nodes.length,
  );

  // 3. 保存快照
  await _saveSnapshot(snapshot, nodes);

  // 4. 更新索引
  _snapshots[snapshotId] = snapshot;

  return snapshotId;
}
```

### 5.2 恢复快照

**描述**:
从快照恢复系统状态。

**实现**:

```dart
@override
Future<void> restoreSnapshot(String snapshotId) async {
  // 1. 加载快照
  final snapshot = _snapshots[snapshotId];
  if (snapshot == null) {
    throw SnapshotNotFoundException('快照不存在: $snapshotId');
  }

  // 2. 加载快照数据
  final nodes = await _loadSnapshot(snapshotId);

  // 3. 恢复节点
  for (final node in nodes) {
    await createVersion(
      node.id,
      node,
      author: 'system',
      summary: '从快照恢复',
      changeType: VersionChangeType.restore,
    );
  }
}
```

## 6. 垃圾回收

### 6.1 清理过期版本

**描述**:
删除超过保留期限或数量的旧版本。

**策略**:
- 保留最近 N 个版本
- 或保留最近 N 天的版本
- 保留快照引用的版本

**实现**:

```dart
@override
Future<void> cleanupExpiredVersions({
  int? keepVersions,
  Duration? maxAge,
}) async {
  final now = DateTime.now();

  for (final entry in _chains.entries) {
    final nodeId = entry.key;
    final chain = entry.value;

    final versionsToKeep = <VersionInfo>[];

    for (final info in chain.versions) {
      bool shouldKeep = false;

      // 检查版本号范围
      if (keepVersions != null) {
        final versionsFromEnd = chain.currentVersion - info.version + 1;
        if (versionsFromEnd <= keepVersions) {
          shouldKeep = true;
        }
      }

      // 检查时间范围
      if (maxAge != null) {
        final age = now.difference(info.createdAt);
        if (age <= maxAge) {
          shouldKeep = true;
        }
      }

      // 检查快照引用
      if (_isReferencedBySnapshot(nodeId, info.version)) {
        shouldKeep = true;
      }

      if (shouldKeep) {
        versionsToKeep.add(info);
      }
    }

    // 更新版本链
    _chains[nodeId] = VersionChain(
      nodeId: nodeId,
      versions: versionsToKeep,
    );

    // TODO: 清理日志文件中的孤立数据
  }
}

bool _isReferencedBySnapshot(String nodeId, int version) {
  // 检查是否有快照引用此版本
  return false; // TODO: 实现
}
```

## 7. 并发模型

### 7.1 写操作串行化

**策略**:
- 版本创建进入队列
- 按顺序执行
- 保证版本号连续性

**实现**:

```dart
class VersionControl implements IVersionControl {
  final WriteQueue _writeQueue = WriteQueue();

  @override
  Future<VersionInfo> createVersion(...) async {
    return await _writeQueue.enqueue(() async {
      // ... 创建版本逻辑
    });
  }
}
```

### 7.2 读操作无锁

**策略**:
- 读取不可变数据
- 无需加锁
- 最终一致性

## 8. 错误处理

### 8.1 版本冲突

**策略**:
- 检测版本号冲突
- 自动重试
- 或抛出异常

### 8.2 损坏恢复

**策略**:
- 日志文件校验和
- 索引重建
- 从快照恢复

## 9. 性能考虑

### 9.1 概念性性能指标

| 操作 | 目标延迟 | 说明 |
|------|----------|------|
| 创建版本 | < 2ms | 追加写入 |
| 读取版本 | < 5ms | 索引 + 文件读取 |
| 版本比较 | < 10ms | 内存比较 |
| 创建快照 | < 1s | 取决于节点数 |

### 9.2 优化方向

1. **增量存储**:
   - 只存储变更的字段
   - 压缩算法
   - 去重

2. **索引优化**:
   - 分片索引
   - 缓存热数据
   - 异步更新

3. **并发优化**:
   - 批量操作
   - 并行写入
   - 读写分离

## 10. 关键文件清单

```
lib/core/storage/
└── version/
    ├── version_control.dart       # IVersionControl 接口
    ├── version_info.dart          # VersionInfo 数据类
    ├── versioned_node.dart        # VersionedNode 数据类
    ├── log/
    │   ├── version_log.dart       # 版本日志
    │   └── version_log_entry.dart # 日志条目
    ├── index/
    │   └── version_index.dart     # 版本索引
    ├── chain/
    │   └── version_chain.dart     # 版本链
    ├── snapshot/
    │   ├── snapshot_manager.dart  # 快照管理器
    │   └── snapshot_info.dart     # 快照信息
    ├── diff/
    │   └── version_diff.dart      # 版本差异
    └── gc/
        └── garbage_collector.dart # 垃圾回收
```

## 11. 参考资料

### 版本控制系统
- Git Architecture
- Mercurial Design
- Version Control Systems

### 数据结构
- Append-Only Logs
- Immutable Data Structures
- Persistent Data Structures

---

**文档所有者**: Node Graph Notebook 架构组
**最后更新**: 2025-01-14
