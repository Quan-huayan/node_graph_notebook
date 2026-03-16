import 'package:equatable/equatable.dart';
import '../models/models.dart';

/// 转换器事件基类
abstract class ConverterEvent extends Equatable {
  /// 创建转换器事件
  const ConverterEvent();

  @override
  /// 事件的属性列表，用于Equatable比较
  List<Object?> get props => [];
}

/// 导入预览事件，用于预览文件导入结果
class ImportPreviewEvent extends ConverterEvent {
  /// 创建导入预览事件
  /// 
  /// [filePath] - 要导入的文件路径
  /// [rule] - 转换规则
  const ImportPreviewEvent(this.filePath, this.rule);

  /// 要导入的文件路径
  final String filePath;
  /// 转换规则
  final ConversionRule rule;

  @override
  /// 事件的属性列表，用于Equatable比较
  List<Object?> get props => [filePath, rule];
}

/// 导入执行事件，用于执行文件导入操作
class ImportExecuteEvent extends ConverterEvent {
  /// 创建导入执行事件
  /// 
  /// [filePath] - 要导入的文件路径
  /// [rule] - 转换规则
  /// [selectedIndices] - 要导入的节点索引列表
  /// [addToGraph] - 是否将创建的节点添加到当前图，默认为 true
  const ImportExecuteEvent(
    this.filePath,
    this.rule,
    this.selectedIndices, {
    this.addToGraph = true,
  });

  /// 要导入的文件路径
  final String filePath;
  /// 转换规则
  final ConversionRule rule;
  /// 要导入的节点索引列表
  final List<int> selectedIndices;
  /// 是否将创建的节点添加到当前图
  final bool addToGraph;

  @override
  /// 事件的属性列表，用于Equatable比较
  List<Object?> get props => [filePath, rule, selectedIndices, addToGraph];
}

/// 导出预览事件，用于预览导出结果
class ExportPreviewEvent extends ConverterEvent {
  /// 创建导出预览事件
  /// 
  /// [nodeIds] - 要导出的节点 ID 列表
  /// [rule] - 合并规则
  const ExportPreviewEvent(this.nodeIds, this.rule);

  /// 要导出的节点 ID 列表
  final List<String> nodeIds;
  /// 合并规则
  final MergeRule rule;

  @override
  /// 事件的属性列表，用于Equatable比较
  List<Object?> get props => [nodeIds, rule];
}

/// 导出执行事件，用于执行导出操作
class ExportExecuteEvent extends ConverterEvent {
  /// 创建导出执行事件
  /// 
  /// [nodeIds] - 要导出的节点 ID 列表
  /// [rule] - 合并规则
  /// [outputPath] - 输出文件路径
  const ExportExecuteEvent(this.nodeIds, this.rule, this.outputPath);

  /// 要导出的节点 ID 列表
  final List<String> nodeIds;
  /// 合并规则
  final MergeRule rule;
  /// 输出文件路径
  final String outputPath;

  @override
  /// 事件的属性列表，用于Equatable比较
  List<Object?> get props => [nodeIds, rule, outputPath];
}

/// 批量导入事件，用于批量导入多个文件
class BatchImportEvent extends ConverterEvent {
  /// 创建批量导入事件
  /// 
  /// [filePaths] - 要导入的文件路径列表
  /// [config] - 转换配置
  const BatchImportEvent(this.filePaths, this.config);

  /// 要导入的文件路径列表
  final List<String> filePaths;
  /// 转换配置
  final ConversionConfig config;

  @override
  /// 事件的属性列表，用于Equatable比较
  List<Object?> get props => [filePaths, config];
}

/// 清除预览事件，用于清除预览结果
class ClearPreviewEvent extends ConverterEvent {
  /// 创建清除预览事件
  const ClearPreviewEvent();
}
