import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../converter/models/models.dart';
import '../../core/models/models.dart';

/// 转换器状态基类
@immutable
class ConverterState extends Equatable {
  const ConverterState({
    required this.isLoading,
    required this.importPreviewNodes,
    required this.exportPreviewMarkdown,
    this.currentProgress,
    this.totalProgress,
    this.conversionResult,
    this.error,
  });

  /// 初始状态
  factory ConverterState.initial() {
    return const ConverterState(
      isLoading: false,
      importPreviewNodes: [],
      exportPreviewMarkdown: '',
      currentProgress: null,
      totalProgress: null,
      conversionResult: null,
      error: null,
    );
  }

  final bool isLoading;
  final List<Node> importPreviewNodes;
  final String exportPreviewMarkdown;
  final int? currentProgress;
  final int? totalProgress;
  final ConversionResult? conversionResult;
  final String? error;

  /// 便捷方法
  bool get hasError => error != null;
  bool get hasImportPreview => importPreviewNodes.isNotEmpty;
  bool get hasExportPreview => exportPreviewMarkdown.isNotEmpty;
  bool get isProcessing => currentProgress != null && totalProgress != null;
  bool get hasResult => conversionResult != null;
  bool get wasSuccessful => conversionResult?.failureCount == 0;

  ConverterState copyWith({
    bool? isLoading,
    List<Node>? importPreviewNodes,
    String? exportPreviewMarkdown,
    int? currentProgress,
    int? totalProgress,
    ConversionResult? conversionResult,
    String? error,
  }) {
    return ConverterState(
      isLoading: isLoading ?? this.isLoading,
      importPreviewNodes: importPreviewNodes ?? this.importPreviewNodes,
      exportPreviewMarkdown: exportPreviewMarkdown ?? this.exportPreviewMarkdown,
      currentProgress: currentProgress,
      totalProgress: totalProgress,
      conversionResult: conversionResult ?? this.conversionResult,
      error: error,
    );
  }

  @override
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
