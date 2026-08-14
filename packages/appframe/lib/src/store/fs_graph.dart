/// FSTGraph —— Graph 接口的文件系统实现（architecture.md §6）。
///
/// 组合：SidecarStore（结构权威）+ FileLayer（内容镜像）。
/// 10⁶ 路径：懒加载（窗口读走 getMany）+ 内存二级索引（冷启动构建、
/// 变更增量更新）+ 原子写（tmp + rename）。
///
/// 逻辑层不感知文件（00 §3.4）：FSTGraph 只是 Graph 的一种实现，
/// InMemoryGraph 行为一致（契约测试基准）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:core_data/core_data.dart';

import 'file_layer.dart';
import 'sidecar_store.dart';

/// Graph 的文件系统实现。
class FSTGraph implements Graph {
  /// 以数据根目录初始化（sidecar + 内容文件 + 二级索引）。
  FSTGraph({required Directory dataRoot})
    : _dataRoot = dataRoot,
      sidecar = SidecarStore(dataRoot: dataRoot),
      files = FileLayer(dataRoot: dataRoot),
      _metadataIndex = <String, Map<String, Set<String>>>{};

  /// 数据根目录（M7：data_recovery 备份/校验访问 sidecar 存储）。
  Directory get dataRoot => _dataRoot;

  final Directory _dataRoot;

  /// 结构存储（sidecar）。
  final SidecarStore sidecar;

  /// 内容文件层（镜像）。
  final FileLayer files;

  /// 二级索引：metadata key → jsonEncode(value) → nodeIds
  /// （10⁶ × 平均 100B 可承受，架构 §6.3）。
  final Map<String, Map<String, Set<String>>> _metadataIndex;

  /// 冷启动索引是否已构建（首次 getByMetadata/getAll 时构建）。
  bool _indexBuilt = false;

  /// 冷启动：目录枚举构建 nodeId → 分区路径索引（不读文件内容）。
  ///
  /// 10⁶ 背书：文件系统目录 = 索引；节点结构（含 title）懒加载
  /// （架构 §6.3，02 §2.4）。
  Map<String, SidecarMeta> scanIndex() => sidecar.scan();

  void _ensureIndex() {
    if (_indexBuilt) {
      return;
    }
    sidecar.scan().keys.forEach(_indexNode);
    _indexBuilt = true;
  }

  void _indexNode(String nodeId) {
    final node = sidecar.read(nodeId);
    if (node == null) {
      return;
    }
    node.metadata.forEach((key, value) {
      final valueKey = jsonEncode(value);
      _metadataIndex
          .putIfAbsent(key, () => <String, Set<String>>{})
          .putIfAbsent(valueKey, () => <String>{})
          .add(nodeId);
    });
  }

  void _unindexNode(String nodeId) {
    for (final byValue in _metadataIndex.values) {
      for (final ids in byValue.values) {
        ids.remove(nodeId);
      }
    }
  }

  @override
  Node? get(String id) => sidecar.read(id);

  @override
  List<Node> getMany(List<String> ids) =>
      ids.map(sidecar.read).whereType<Node>().toList();

  @override
  void save(Node node) {
    sidecar.write(node);
    files.writeContent(node);
    _unindexNode(node.id);
    _indexNode(node.id);
  }

  @override
  void delete(String id) {
    final node = sidecar.read(id);
    if (node == null) {
      return;
    }
    sidecar.delete(id);
    files.deleteContent(node);
    _unindexNode(id);
  }

  @override
  List<Node> getAll() {
    _ensureIndex();
    final ids = sidecar.scan().keys.toList();
    return getMany(ids);
  }

  @override
  List<Node> getByMetadata(String key, dynamic value) {
    _ensureIndex();
    final ids = _metadataIndex[key]?[jsonEncode(value)];
    if (ids == null || ids.isEmpty) {
      return <Node>[];
    }
    return getMany(ids.toList());
  }
}
