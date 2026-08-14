import 'package:core/cqrs/commands/models/command.dart';
import 'package:core/cqrs/commands/models/command_context.dart';
import 'package:core/cqrs/commands/models/command_handler.dart';
import 'package:core/models/models.dart';

import '../command/converter_commands.dart';
import '../models/models.dart';
import '../service/import_export_service.dart';

/// Handler for previewing import operations.
/// Processes [PreviewImportCommand] and returns a list of nodes without importing them.
class PreviewImportHandler implements CommandHandler<PreviewImportCommand> {
  /// Creates a handler with the provided [ImportExportService].
  PreviewImportHandler(this._service);

  final ImportExportService _service;

  @override
  Future<CommandResult<List<Node>>> execute(
    PreviewImportCommand command,
    CommandContext context,
  ) async {
    try {
      final nodes = await _service.previewImport(
        filePath: command.filePath,
        rule: command.rule,
      );
      return CommandResult.success(nodes);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}

/// Handler for executing import operations.
/// Processes [ExecuteImportCommand] and imports selected nodes into the graph.
class ExecuteImportHandler implements CommandHandler<ExecuteImportCommand> {
  /// Creates a handler with the provided [ImportExportService].
  ExecuteImportHandler(this._service);

  final ImportExportService _service;

  @override
  Future<CommandResult<ConversionResult>> execute(
    ExecuteImportCommand command,
    CommandContext context,
  ) async {
    try {
      final result = await _service.executeImport(
        filePath: command.filePath,
        rule: command.rule,
        selectedIndices: command.selectedIndices,
        addToGraph: command.addToGraph,
      );
      return CommandResult.success(result);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}

/// Handler for previewing export operations.
/// Processes [PreviewExportCommand] and generates markdown preview without saving.
class PreviewExportHandler implements CommandHandler<PreviewExportCommand> {
  /// Creates a handler with the provided [ImportExportService].
  PreviewExportHandler(this._service);

  final ImportExportService _service;

  @override
  Future<CommandResult<String>> execute(
    PreviewExportCommand command,
    CommandContext context,
  ) async {
    try {
      final markdown = await _service.previewExport(
        nodeIds: command.nodeIds,
        rule: command.rule,
      );
      return CommandResult.success(markdown);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}

/// Handler for executing export operations.
/// Processes [ExecuteExportCommand] and exports nodes to a markdown file.
class ExecuteExportHandler implements CommandHandler<ExecuteExportCommand> {
  /// Creates a handler with the provided [ImportExportService].
  ExecuteExportHandler(this._service);

  final ImportExportService _service;

  @override
  Future<CommandResult<void>> execute(
    ExecuteExportCommand command,
    CommandContext context,
  ) async {
    try {
      await _service.executeExport(
        nodeIds: command.nodeIds,
        rule: command.rule,
        outputPath: command.outputPath,
      );
      return CommandResult.success();
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}

/// Handler for batch import operations.
/// Processes [BatchImportCommand] and imports multiple files in a single operation.
class BatchImportHandler implements CommandHandler<BatchImportCommand> {
  /// Creates a handler with the provided [ImportExportService].
  BatchImportHandler(this._service);

  final ImportExportService _service;

  @override
  Future<CommandResult<ConversionResult>> execute(
    BatchImportCommand command,
    CommandContext context,
  ) async {
    try {
      final result = await _service.batchImport(
        filePaths: command.filePaths,
        config: command.config,
      );
      return CommandResult.success(result);
    } catch (e) {
      return CommandResult.failure(e.toString());
    }
  }
}
