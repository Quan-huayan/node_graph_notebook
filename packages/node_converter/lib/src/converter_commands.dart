/// 导入导出命令（M7 converter 插件，纯 DTO + Handler，03 §四）。
library;

import 'package:core/core.dart';

/// 导出命令（节点集 → JSON 文件）。
class ExportCommand extends Command<ExportCommand> {
  /// 携带目标路径与导出的节点（null = 全部）。
  const ExportCommand({required this.path, this.nodeIds});

  /// 目标文件路径。
  final String path;

  /// 导出的节点 id 集合（null = 全部）。
  final Set<String>? nodeIds;

  @override
  String get name => 'converter.export';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'path': path,
    'nodeIds': nodeIds,
  };
}

/// 导出写结果。
class ExportResult implements WriteResult {
  /// 携带导出节点数。
  const ExportResult({required this.exportedCount});

  /// 导出节点数。
  final int exportedCount;

  @override
  Set<String> get affectedNodeIds => const <String>{};

  @override
  ChangeKind get changeKind => ChangeKind.data;

  @override
  Command? get inverse => null; // M7 显式不可撤销（撤销契约 03 §四）。
}

/// 导入命令（JSON 文件 → 节点）。
class ImportCommand extends Command<ImportCommand> {
  /// 携带源文件路径。
  const ImportCommand({required this.path});

  /// 源文件路径。
  final String path;

  @override
  String get name => 'converter.import';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{'path': path};
}

/// 导入写结果（structure：新节点 → 树重挂）。
class ImportResult implements WriteResult {
  /// 携带导入节点 id。
  const ImportResult({required this.importedNodeIds});

  /// 导入节点 id。
  final Set<String> importedNodeIds;

  @override
  Set<String> get affectedNodeIds => importedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  @override
  Command? get inverse => null;
}
