/// FileLayer —— 内容文件层（00 §3.2：内容 = 文件树，任意类型）。
///
/// 数据目录是文件树，可直接被编辑器、git、脚本管理——产品数据
/// 不锁死在私有格式里。主内容文件是 Node.content 的用户可编辑镜像：
/// 逻辑权威在 sidecar（SidecarStore），此处保证内容可外部访问。
///
/// 路径确定性（物理布局永不上浮为逻辑结构，00 §3.4）：
/// `files/<type>/<h2>/<id8>_<slug>.<ext>`——文件路径只是别名。
library;

import 'dart:io';

import 'package:core_data/core_data.dart';

/// 内容文件层：主内容镜像的确定性路径计算与读写。
class FileLayer {
  /// 以数据根目录初始化（`files/` 下按类型分区）。
  FileLayer({required Directory dataRoot})
    : _filesRoot = Directory('${dataRoot.path}${Platform.pathSeparator}files');

  final Directory _filesRoot;

  /// 内容类型目录：metadata['type']（如 'code'），缺省 'note'。
  /// 类型是数据，不是机制（02 §1.2：自定义 metadata key）。
  String _typeOf(Node node) => node.metadata['type'] as String? ?? 'note';

  /// slug：title 清洗为安全文件名；空 title 回退 id。
  String _slugOf(Node node) {
    final cleaned = node.title
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    return cleaned.isEmpty ? node.id : cleaned;
  }

  /// 内容文件扩展名（M2：markdown 主内容；资产类型扩展名后续接入）。
  String _extOf(Node node) {
    final type = _typeOf(node);
    return switch (type) {
      'code' => '.txt',
      _ => '.md',
    };
  }

  /// 内容文件路径（确定性：由 id 分区 + title slug 计算）。
  File contentFileFor(Node node) {
    final h2 = node.id.length >= 2 ? node.id.substring(0, 2) : node.id;
    final id8 = node.id.length >= 8 ? node.id.substring(0, 8) : node.id;
    return File(
      '${_filesRoot.path}${Platform.pathSeparator}'
      '${_typeOf(node)}${Platform.pathSeparator}'
      '$h2${Platform.pathSeparator}'
      '${id8}_${_slugOf(node)}${_extOf(node)}',
    );
  }

  /// 已确认存在的目录缓存（避免每次 save 重复 createSync(recursive)）。
  final Set<String> _dirsCreated = <String>{};

  /// 镜像写：Node.content 落盘（与 sidecar 双写）。
  void writeContent(Node node) {
    final file = contentFileFor(node);
    if (_dirsCreated.add(file.parent.path)) {
      file.parent.createSync(recursive: true);
    }
    // flush: false —— 同 SidecarStore：原子语义 + 恢复流程兜底。
    file.writeAsStringSync(node.content ?? '', flush: false);
  }

  /// 删除内容镜像（Node 删除时同步清理）。
  void deleteContent(Node node) {
    final file = contentFileFor(node);
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}
