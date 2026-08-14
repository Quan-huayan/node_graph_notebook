import 'package:core/cqrs/commands/command_bus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../command/converter_commands.dart';
import '../models/models.dart';
import 'converter_event.dart';
import 'converter_state.dart';

/// Bloc that manages the state and logic for data conversion operations.
/// Handles import, export, and batch processing events.
class ConverterBloc extends Bloc<ConverterEvent, ConverterState> {
  /// Creates a [ConverterBloc] with the required [CommandBus] for dispatching commands.
  ConverterBloc({required CommandBus commandBus})
    : _commandBus = commandBus,
      super(ConverterState.initial()) {
    on<ImportPreviewEvent>(_onImportPreview);
    on<ImportExecuteEvent>(_onImportExecute);
    on<ExportPreviewEvent>(_onExportPreview);
    on<ExportExecuteEvent>(_onExportExecute);
    on<BatchImportEvent>(_onBatchImport);
    on<ClearPreviewEvent>(_onClearPreview);
  }

  final CommandBus _commandBus;

  Future<void> _onImportPreview(
    ImportPreviewEvent event,
    Emitter<ConverterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final command = PreviewImportCommand(
        filePath: event.filePath,
        rule: event.rule,
      );
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        emit(
          state.copyWith(
            importPreviewNodes: result.data,
            isLoading: false,
            error: null,
          ),
        );
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onImportExecute(
    ImportExecuteEvent event,
    Emitter<ConverterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final command = ExecuteImportCommand(
        filePath: event.filePath,
        rule: event.rule,
        selectedIndices: event.selectedIndices,
        addToGraph: event.addToGraph,
      );
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        emit(
          state.copyWith(
            isLoading: false,
            conversionResult: result.data,
            error: null,
          ),
        );
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onExportPreview(
    ExportPreviewEvent event,
    Emitter<ConverterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final command = PreviewExportCommand(
        nodeIds: event.nodeIds,
        rule: event.rule,
      );
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        emit(
          state.copyWith(
            exportPreviewMarkdown: result.data,
            isLoading: false,
            error: null,
          ),
        );
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onExportExecute(
    ExportExecuteEvent event,
    Emitter<ConverterState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));

    try {
      final command = ExecuteExportCommand(
        nodeIds: event.nodeIds,
        rule: event.rule,
        outputPath: event.outputPath,
      );
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        final conversionResult = ConversionResult(
          successCount: event.nodeIds.length,
          failureCount: 0,
          errors: const [],
          duration: Duration.zero,
          createdNodeIds: event.nodeIds,
        );

        emit(
          state.copyWith(
            isLoading: false,
            conversionResult: conversionResult,
            error: null,
          ),
        );
      } else {
        emit(state.copyWith(isLoading: false, error: result.error));
      }
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

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
      final command = BatchImportCommand(
        filePaths: event.filePaths,
        config: event.config,
      );
      final result = await _commandBus.dispatch(command);

      if (result.isSuccess) {
        emit(
          state.copyWith(
            isLoading: false,
            conversionResult: result.data,
            currentProgress: null,
            totalProgress: null,
            error: null,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            currentProgress: null,
            totalProgress: null,
            error: result.error,
          ),
        );
      }
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

  void _onClearPreview(ClearPreviewEvent event, Emitter<ConverterState> emit) {
    emit(ConverterState.initial());
  }
}
