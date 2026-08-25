/// SidecarStore —— 节点结构存储（architecture.md §6）。
///
/// 每 Node 一个 sidecar 结构文件，nodeId 哈希分区
/// （`data/.node/ab/3f/<id>.node.json`，前两位 → 256 分区，
/// 10⁶ 时单分区 ~3900 文件）。原子写：tmp + rename。
library;

import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

import 'stored_node.dart';

/// sidecar 解析失败（architecture.md §8）：
/// 触发"节点数据损坏，已恢复为可编辑状态"（兜底加载）。
class CorruptNodeError implements Exception {
  /// 携带损坏节点与原因。
  const CorruptNodeError(this.nodeId, this.reason);

  /// 损坏的节点 id。
  final String nodeId;

  /// 解析失败原因。
  final String reason;

  @override
  String toString() => 'CorruptNodeError: 节点 $nodeId 数据损坏（$reason）';
}

/// sidecar 分区元数据（冷启动索引的最小载荷）。
class SidecarMeta {
  /// 最小元数据（nodeId + 分区路径，10⁶ 索引构建的最小载荷）。
  const SidecarMeta({required this.id, required this.partition});

  /// 节点 id。
  final String id;

  /// 分区目录名（id 前两位；结构懒加载的寻址依据）。
  final String partition;
}

/// 节点结构存储：sidecar 文件读写 + 分区 + 原子写。
class SidecarStore {
  /// 以数据根目录初始化（`data/.node/` 分区目录）。
  SidecarStore({required Directory dataRoot})
    : _sidecarDir = Directory('${dataRoot.path}${Platform.pathSeparator}.node');

  /// sidecar 根目录（`data/.node/`）。
  Directory get storeDir => _sidecarDir;

  final Directory _sidecarDir;

  /// 节点 id → 分区目录（id 前两位，256 分区）。
  String partitionPath(String nodeId) =>
      nodeId.length >= 2 ? nodeId.substring(0, 2) : nodeId;

  File _fileFor(String nodeId) => File(
    '${_sidecarDir.path}${Platform.pathSeparator}'
    '${partitionPath(nodeId)}${Platform.pathSeparator}$nodeId.node.json',
  );

  /// 已确认存在的目录缓存（避免每次 save 重复 createSync(recursive)）。
  final Set<String> _dirsCreated = <String>{};

  void _ensureDir(String path) {
    if (_dirsCreated.add(path)) {
      Directory(path).createSync(recursive: true);
    }
  }

  /// 读取节点；不存在返回 null；解析失败 → 兜底加载（可编辑状态）。
  Node? read(String nodeId) {
    final file = _fileFor(nodeId);
    if (!file.existsSync()) {
      return null;
    }
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return StoredNode.fromJson(json);
    } on FormatException {
      // 解析损坏的已知形态（R9 类型化——仅 JSON 语法错误触发兜底，架构 §8）。
      return FallbackNode(id: nodeId, title: '[损坏节点] $nodeId');
    } on TypeError {
      // 解析损坏的已知形态（类型不符：非 Map/字段类型错，R9 类型化）。
      return FallbackNode(id: nodeId, title: '[损坏节点] $nodeId');
    }
  }

  /// 原子写：tmp + rename（10⁶ 读写路径，架构 §6.3）。
  void write(Node node) {
    _ensureDir(_fileFor(node.id).parent.path);
    final json = (node is StoredNode)
        ? node.toJson()
        : StoredNode(
            id: node.id,
            title: node.title,
            content: node.content,
            references: node.references,
            metadata: node.metadata,
            createdAt: node.createdAt,
            updatedAt: node.updatedAt,
          ).toJson();
    final target = _fileFor(node.id);
    final tmp = File('${target.path}.tmp');
    // flush: false —— 数据进 OS 页缓存后 rename；原子语义（旧或新）不变，
    // 崩溃窗口内的数据由数据恢复插件兜底（架构 §8 恢复路径）。
    tmp.writeAsStringSync(jsonEncode(json), flush: false);
    tmp.renameSync(target.path);
  }

  /// 删除 sidecar；不存在为静默 no-op。
  void delete(String nodeId) {
    final file = _fileFor(nodeId);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }

  /// 冷启动索引：**目录枚举**（只列文件名，不读文件内容）。
  ///
  /// 10⁶ 背书：文件系统目录本身就是 nodeId → 分区路径的索引
  /// （架构 §6.3"冷启动读索引"）；节点结构（含 title）懒加载，
  /// 首次 getByMetadata/getAll 时逐节点读入（02 §2.4）。
  Map<String, SidecarMeta> scan() {
    final result = <String, SidecarMeta>{};
    if (!_sidecarDir.existsSync()) {
      return result;
    }
    for (final dir in _sidecarDir.listSync().whereType<Directory>()) {
      final partition = dir.uri.pathSegments.last;
      for (final file in dir.listSync().whereType<File>()) {
        if (!file.path.endsWith('.node.json')) {
          continue;
        }
        final id = file.uri.pathSegments.last.replaceFirst('.node.json', '');
        result[id] = SidecarMeta(id: id, partition: partition);
      }
    }
    return result;
  }
}
