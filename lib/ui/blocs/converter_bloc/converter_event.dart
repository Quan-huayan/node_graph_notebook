import 'package:equatable/equatable.dart';
import '../../../converter/models/models.dart';

/// 转换器事件基类
abstract class ConverterEvent extends Equatable {
  const ConverterEvent();

  @override
  List<Object?> get props => [];
}

/// 导入预览事件
class ImportPreviewEvent extends ConverterEvent {
  const ImportPreviewEvent(this.filePath, this.rule);

  final String filePath;
  final ConversionRule rule;

  @override
  List<Object?> get props => [filePath, rule];
}

/// 导入执行事件
class ImportExecuteEvent extends ConverterEvent {
  const ImportExecuteEvent(
    this.filePath,
    this.rule,
    this.selectedIndices, {
    this.addToGraph = true,
  });

  final String filePath;
  final ConversionRule rule;
  final List<int> selectedIndices;
  final bool addToGraph;

  @override
  List<Object?> get props => [filePath, rule, selectedIndices, addToGraph];
}

/// 导出预览事件
class ExportPreviewEvent extends ConverterEvent {
  const ExportPreviewEvent(this.nodeIds, this.rule);

  final List<String> nodeIds;
  final MergeRule rule;

  @override
  List<Object?> get props => [nodeIds, rule];
}

/// 导出执行事件
class ExportExecuteEvent extends ConverterEvent {
  const ExportExecuteEvent(
    this.nodeIds,
    this.rule,
    this.outputPath,
  );

  final List<String> nodeIds;
  final MergeRule rule;
  final String outputPath;

  @override
  List<Object?> get props => [nodeIds, rule, outputPath];
}

/// 批量导入事件
class BatchImportEvent extends ConverterEvent {
  const BatchImportEvent(
    this.filePaths,
    this.config,
  );

  final List<String> filePaths;
  final ConversionConfig config;

  @override
  List<Object?> get props => [filePaths, config];
}

/// 清除预览事件
class ClearPreviewEvent extends ConverterEvent {
  const ClearPreviewEvent();
}
