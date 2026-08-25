/// 数据恢复命令（M7 data_recovery 插件，纯 DTO + Handler，03 §四）。
library;

import 'package:core/core.dart';

/// 备份命令（sidecar 存储 → data/backups/<时间戳>）。
class BackupCommand extends Command<BackupCommand> {
  /// 备份（无载荷）。
  const BackupCommand();

  @override
  String get name => 'recovery.backup';

  @override
  Map<String, dynamic> get payload => const <String, dynamic>{};
}

/// 备份写结果。
class BackupResult implements WriteResult {
  /// 携带备份路径（affected 为空——备份非节点写）。
  const BackupResult({required this.backupPath});

  /// 备份目录路径。
  final String backupPath;

  @override
  Set<String> get affectedNodeIds => const <String>{};

  @override
  ChangeKind get changeKind => ChangeKind.data;

  @override
  Command? get inverse => null; // M7 显式不可撤销（撤销契约 03 §四）。
}

/// 校验命令（sidecar 可解析 + 引用完整性）。
class VerifyCommand extends Command<VerifyCommand> {
  /// 校验（无载荷）。
  const VerifyCommand();

  @override
  String get name => 'recovery.verify';

  @override
  Map<String, dynamic> get payload => const <String, dynamic>{};
}

/// 校验写结果（携带问题列表）。
class VerifyResult implements WriteResult {
  /// 携带校验问题。
  const VerifyResult({required this.issues});

  /// 校验问题（空 = 健康）。
  final List<String> issues;

  @override
  Set<String> get affectedNodeIds => const <String>{};

  @override
  ChangeKind get changeKind => ChangeKind.data;

  // R3c 不可撤销理由：校验 = 只读检查（无写副作用），以 WriteResult 呈现
  // 仅为统一结果通道——inverse 无意义（docs/review 总览 P0-3 /
  // audit-node_data_recovery #3）。
  @override
  Command? get inverse => null;
}

/// 修复命令（删除损坏 sidecar——恢复为可编辑空节点）。
class RepairCommand extends Command<RepairCommand> {
  /// 修复（无载荷）。
  const RepairCommand();

  @override
  String get name => 'recovery.repair';

  @override
  Map<String, dynamic> get payload => const <String, dynamic>{};
}

/// 修复写结果。
class RepairResult implements WriteResult {
  /// 携带修复的节点（删除的损坏 sidecar id）。
  const RepairResult({required this.repairedNodeIds});

  /// 已修复（删除）的节点 id。
  final Set<String> repairedNodeIds;

  @override
  Set<String> get affectedNodeIds => repairedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  // R3c 不可撤销理由：恢复写——删除损坏 sidecar（+ Graph 索引条目），
  // 不可撤销（docs/review 总览 P0-3 / audit-node_data_recovery #2；
  // 03 §四 明列恢复写豁免——修复即终端动作，无对偶命令）。
  @override
  Command? get inverse => null;
}
