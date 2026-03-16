import 'package:flutter_bloc/flutter_bloc.dart';

import '../models/models.dart';
import '../service/import_export_service.dart';
import 'converter_event.dart';
import 'converter_state.dart';

/// 转换器 BLoC，处理转换相关的状态管理
class ConverterBloc extends Bloc<ConverterEvent, ConverterState> {
  /// 创建转换器 BLoC
  /// 
  /// [importExportService] - 导入导出服务，用于执行导入导出操作
  ConverterBloc({required ImportExportService importExportService})
    : _importExportService = importExportService,
      super(ConverterState.initial()) {
    on<ImportPreviewEvent>(_onImportPreview);
    on<ImportExecuteEvent>(_onImportExecute);
    on<ExportPreviewEvent>(_onExportPreview);
    on<ExportExecuteEvent>(_onExportExecute);
    on<BatchImportEvent>(_onBatchImport);
    on<ClearPreviewEvent>(_onClearPreview);
  }

  final ImportExportService _importExportService;

  /// 导入预览
  Future<void> _onImportPreview(
    ImportPreviewEvent event,
    Emitter<ConverterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final nodes = await _importExportService.previewImport(
        filePath: event.filePath,
        rule: event.rule,
      );

      emit(
        state.copyWith(
          importPreviewNodes: nodes,
          isLoading: false,
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 导入执行
  Future<void> _onImportExecute(
    ImportExecuteEvent event,
    Emitter<ConverterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final result = await _importExportService.executeImport(
        filePath: event.filePath,
        rule: event.rule,
        selectedIndices: event.selectedIndices,
        addToGraph: event.addToGraph,
      );

      emit(
        state.copyWith(isLoading: false, conversionResult: result, error: null),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 导出预览
  Future<void> _onExportPreview(
    ExportPreviewEvent event,
    Emitter<ConverterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final markdown = await _importExportService.previewExport(
        nodeIds: event.nodeIds,
        rule: event.rule,
      );

      emit(
        state.copyWith(
          exportPreviewMarkdown: markdown,
          isLoading: false,
          error: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 导出执行
  Future<void> _onExportExecute(
    ExportExecuteEvent event,
    Emitter<ConverterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      await _importExportService.executeExport(
        nodeIds: event.nodeIds,
        rule: event.rule,
        outputPath: event.outputPath,
      );

      final result = ConversionResult(
        successCount: event.nodeIds.length,
        failureCount: 0,
        errors: const [],
        duration: Duration.zero,
        createdNodeIds: event.nodeIds,
      );

      emit(
        state.copyWith(isLoading: false, conversionResult: result, error: null),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  /// 批量导入
  Future<void> _onBatchImport(
    BatchImportEvent event,
    Emitter<ConverterState> emit,
  ) async {
    emit(
      state.copyWith(
        isLoading: true,
        currentProgress: 0,
        totalProgress: event.filePaths.length,
        error: null,
      ),
    );

    try {
      final result = await _importExportService.batchImport(
        filePaths: event.filePaths,
        config: event.config,
        onProgress: (current, total) {
          emit(state.copyWith(currentProgress: current, totalProgress: total));
        },
      );

      emit(
        state.copyWith(
          isLoading: false,
          conversionResult: result,
          currentProgress: null,
          totalProgress: null,
          error: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          currentProgress: null,
          totalProgress: null,
          error: e.toString(),
        ),
      );
    }
  }

  /// 清除预览
  void _onClearPreview(ClearPreviewEvent event, Emitter<ConverterState> emit) {
    emit(ConverterState.initial());
  }
}
