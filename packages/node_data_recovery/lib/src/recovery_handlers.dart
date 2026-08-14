/// 数据恢复 Handler（M7 data_recovery 插件，写操作唯一执行者，01-D）：
///
/// - Backup：复制 sidecar 存储（data/.node + ui-state.json）→
///   data/backups/<时间戳>/（可被 git/用户管理，00 §3.2 文件树主张）
/// - Verify：sidecar JSON 可解析性 + 引用完整性（引用目标存在）
/// - Repair：删除损坏 sidecar（架构 §8 CorruptNodeError 恢复路径——
///   损坏节点恢复为可编辑空节点）
library;

import 'dart:convert';
import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

import 'recovery_commands.dart';

/// 备份 Handler。
class BackupHandler extends CommandHandler<BackupCommand, BackupResult> {
  /// [graphProvider] 延迟解析结构存储（FSTGraph 提供数据根）。
  BackupHandler({required Graph Function() graphProvider})
    : _graphProvider = graphProvider;

  final Graph Function() _graphProvider;

  @override
  Type get commandType => BackupCommand;

  @override
  Future<BackupResult> handle(BackupCommand command) async {
    final graph = _graphProvider() as FSTGraph;
    final dataRoot = graph.dataRoot;
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupDir = Directory(
      '${dataRoot.path}${Platform.pathSeparator}backups'
      '${Platform.pathSeparator}$stamp',
    )..createSync(recursive: true);
    _copyDirectory(graph.sidecar.storeDir, backupDir);
    // ui-state.json（外观存储——备份完整快照）。
    final uiState = File(
      '${dataRoot.path}${Platform.pathSeparator}ui-state.json',
    );
    if (uiState.existsSync()) {
      uiState.copySync(
        '${backupDir.path}${Platform.pathSeparator}ui-state.json',
      );
    }
    return BackupResult(backupPath: backupDir.path);
  }

  void _copyDirectory(Directory from, Directory to) {
    if (!from.existsSync()) {
      return;
    }
    for (final entity in from.listSync(recursive: true)) {
      if (entity is File) {
        final relative = entity.path.substring(from.path.length + 1);
        final target = File('${to.path}${Platform.pathSeparator}$relative');
        target.parent.createSync(recursive: true);
        entity.copySync(target.path);
      }
    }
  }
}

/// 校验 Handler。
class VerifyHandler extends CommandHandler<VerifyCommand, VerifyResult> {
  /// [graphProvider] 延迟解析结构存储。
  VerifyHandler({required Graph Function() graphProvider})
    : _graphProvider = graphProvider;

  final Graph Function() _graphProvider;

  @override
  Type get commandType => VerifyCommand;

  @override
  Future<VerifyResult> handle(VerifyCommand command) async {
    final graph = _graphProvider() as FSTGraph;
    final issues = <String>[];
    final parsedIds = <String>{};
    final storeDir = graph.sidecar.storeDir;
    if (!storeDir.existsSync()) {
      return const VerifyResult(issues: <String>['sidecar 存储不存在']);
    }
    // 1. 可解析性。
    for (final file
        in storeDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.node.json'))) {
      try {
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final id = data['id'];
        if (id is! String || id.isEmpty) {
          issues.add('${file.path}: 缺少 id');
          continue;
        }
        parsedIds.add(id);
      } on FormatException {
        issues.add('${file.path}: JSON 损坏');
      } on TypeError {
        issues.add('${file.path}: 结构异常');
      }
    }
    // 2. 引用完整性（引用目标存在）。
    for (final file
        in storeDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.node.json'))) {
      try {
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final references = data['references'];
        if (references is Map<String, dynamic>) {
          for (final entry in references.entries) {
            final target = entry.value;
            if (target is String && !parsedIds.contains(target)) {
              issues.add('${file.path}: 引用 ${entry.key} → $target 不存在');
            }
          }
        }
      } on FormatException {
        // 已在可解析性阶段记录。
      }
    }
    return VerifyResult(issues: issues);
  }
}

/// 修复 Handler（删除损坏 sidecar）。
class RepairHandler extends CommandHandler<RepairCommand, RepairResult> {
  /// [graphProvider] 延迟解析结构存储。
  RepairHandler({required Graph Function() graphProvider})
    : _graphProvider = graphProvider;

  final Graph Function() _graphProvider;

  @override
  Type get commandType => RepairCommand;

  @override
  Future<RepairResult> handle(RepairCommand command) async {
    final graph = _graphProvider() as FSTGraph;
    final repaired = <String>{};
    final storeDir = graph.sidecar.storeDir;
    if (!storeDir.existsSync()) {
      return RepairResult(repairedNodeIds: repaired);
    }
    for (final file
        in storeDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.node.json'))) {
      var corrupt = false;
      try {
        final data =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        if (data['id'] is! String) {
          corrupt = true;
        }
      } on FormatException {
        corrupt = true;
      }
      if (corrupt) {
        // 从文件名提取 id（<id>.node.json）——sidecar 命名约定。
        final id = file.uri.pathSegments.last.replaceAll('.node.json', '');
        file.deleteSync();
        // 从 Graph 索引移除（侧边栏/画布不再显示损坏节点）。
        graph.delete(id);
        repaired.add(id);
      }
    }
    return RepairResult(repairedNodeIds: repaired);
  }
}
