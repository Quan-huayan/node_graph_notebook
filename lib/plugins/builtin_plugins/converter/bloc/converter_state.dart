import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/models.dart';
import '../models/models.dart';

/// 转换器状态基类
@immutable
class ConverterState extends Equatable {
  /// 创建转换器状态
  /// 
  /// [isLoading] - 是否正在加载
  /// [importPreviewNodes] - 导入预览节点列表
  /// [exportPreviewMarkdown] - 导出预览 Markdown 内容
  /// [currentProgress] - 当前进度
  /// [totalProgress] - 总进度
  /// [conversionResult] - 转换结果
  /// [error] - 错误信息
  const ConverterState({
    required this.isLoading,
    required this.importPreviewNodes,
    required this.exportPreviewMarkdown,
    this.currentProgress,
    this.totalProgress,
    this.conversionResult,
    this.error,
  });

  /// 创建初始状态
  factory ConverterState.initial() => const ConverterState(
      isLoading: false,
      importPreviewNodes: [],
      exportPreviewMarkdown: '',
      currentProgress: null,
      totalProgress: null,
      conversionResult: null,
      error: null,
    );

  /// 是否正在加载
  final bool isLoading;
  /// 导入预览节点列表
  final List<Node> importPreviewNodes;
  /// 导出预览 Markdown 内容
  final String exportPreviewMarkdown;
  /// 当前进度
  final int? currentProgress;
  /// 总进度
  final int? totalProgress;
  /// 转换结果
  final ConversionResult? conversionResult;
  /// 错误信息
  final String? error;

  /// 便捷方法
  /// 是否有错误
  bool get hasError => error != null;
  /// 是否有导入预览
  bool get hasImportPreview => importPreviewNodes.isNotEmpty;
  /// 是否有导出预览
  bool get hasExportPreview => exportPreviewMarkdown.isNotEmpty;
  /// 是否正在处理
  bool get isProcessing => currentProgress != null && totalProgress != null;
  /// 是否有转换结果
  bool get hasResult => conversionResult != null;
  /// 转换是否成功
  bool get wasSuccessful => conversionResult?.failureCount == 0;

  /// 创建修改后的状态
  /// 
  /// 返回一个新的 ConverterState 实例，包含指定的修改
  ConverterState copyWith({
    bool? isLoading,
    List<Node>? importPreviewNodes,
    String? exportPreviewMarkdown,
    int? currentProgress,
    int? totalProgress,
    ConversionResult? conversionResult,
    String? error,
  }) => ConverterState(
      isLoading: isLoading ?? this.isLoading,
      importPreviewNodes: importPreviewNodes ?? this.importPreviewNodes,
      exportPreviewMarkdown:
          exportPreviewMarkdown ?? this.exportPreviewMarkdown,
      currentProgress: currentProgress,
      totalProgress: totalProgress,
      conversionResult: conversionResult ?? this.conversionResult,
      error: error,
    );

  @override
  /// 状态的属性列表，用于Equatable比较
  List<Object?> get props => [
    isLoading,
    importPreviewNodes,
    exportPreviewMarkdown,
    currentProgress,
    totalProgress,
    conversionResult,
    error,
  ];
}
