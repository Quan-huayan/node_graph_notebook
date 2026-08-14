import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/models/models.dart';

import '../models/models.dart';

/// Command to preview nodes that will be imported from a file.
class PreviewImportCommand extends Command<List<Node>> {
  /// Creates a command to preview import with the specified [filePath] and [rule].
  PreviewImportCommand({
    required this.filePath,
    required this.rule,
  });

  /// The path to the file to import.
  final String filePath;
  /// The conversion rule to apply during import.
  final ConversionRule rule;

  @override
  String get name => 'PreviewImport';

  @override
  String get description => '预览导入: $filePath';

  @override
  bool get isUndoable => false;

  @override
  Future<CommandResult<List<Node>>> execute(CommandContext context) {
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {}
}

/// Command to execute the import of nodes from a file.
class ExecuteImportCommand extends Command<ConversionResult> {
  /// Creates a command to execute import with the specified parameters.
  ExecuteImportCommand({
    required this.filePath,
    required this.rule,
    required this.selectedIndices,
    this.addToGraph = true,
  });

  /// The path to the file to import.
  final String filePath;
  /// The conversion rule to apply during import.
  final ConversionRule rule;
  /// The indices of nodes to import from the preview.
  final List<int> selectedIndices;
  /// Whether to add the imported nodes to the current graph.
  final bool addToGraph;

  @override
  String get name => 'ExecuteImport';

  @override
  String get description => '执行导入: $filePath';

  @override
  Future<CommandResult<ConversionResult>> execute(CommandContext context) {
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {}
}

/// Command to preview the markdown export of selected nodes.
class PreviewExportCommand extends Command<String> {
  /// Creates a command to preview export with the specified [nodeIds] and [rule].
  PreviewExportCommand({
    required this.nodeIds,
    required this.rule,
  });

  /// The IDs of nodes to export.
  final List<String> nodeIds;
  /// The merge rule to apply during export.
  final MergeRule rule;

  @override
  String get name => 'PreviewExport';

  @override
  String get description => '预览导出 (${nodeIds.length} 个节点)';

  @override
  bool get isUndoable => false;

  @override
  Future<CommandResult<String>> execute(CommandContext context) {
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {}
}

/// Command to execute the export of nodes to a markdown file.
class ExecuteExportCommand extends Command<void> {
  /// Creates a command to execute export with the specified parameters.
  ExecuteExportCommand({
    required this.nodeIds,
    required this.rule,
    required this.outputPath,
  });

  /// The IDs of nodes to export.
  final List<String> nodeIds;
  /// The merge rule to apply during export.
  final MergeRule rule;
  /// The output path for the exported markdown file.
  final String outputPath;

  @override
  String get name => 'ExecuteExport';

  @override
  String get description => '执行导出: $outputPath';

  @override
  bool get isUndoable => false;

  @override
  Future<CommandResult<void>> execute(CommandContext context) {
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {}
}

/// Command to batch import multiple files at once.
class BatchImportCommand extends Command<ConversionResult> {
  /// Creates a command to batch import with the specified [filePaths] and [config].
  BatchImportCommand({
    required this.filePaths,
    required this.config,
  });

  /// The paths to the files to import.
  final List<String> filePaths;
  /// The conversion configuration to apply to all files.
  final ConversionConfig config;

  @override
  String get name => 'BatchImport';

  @override
  String get description => '批量导入 (${filePaths.length} 个文件)';

  @override
  Future<CommandResult<ConversionResult>> execute(CommandContext context) {
    throw UnimplementedError('命令执行由处理器处理');
  }

  @override
  Future<void> undo(CommandContext context) async {}
}
