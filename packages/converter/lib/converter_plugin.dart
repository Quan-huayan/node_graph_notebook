import 'package:core/core.dart' hide Plugin, PluginManager, PluginContext, PluginMetadata;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:plugin/plugin.dart';

import 'bloc/converter_bloc.dart';
import 'command/converter_commands.dart';
import 'converter_toolbar_hook.dart';
import 'handler/converter_handlers.dart';
import 'service/import_export_service.dart';

/// A plugin that enables data import and export between Node Graph Notebook
/// and external formats such as Markdown and JSON.
class ConverterPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'converter',
    name: 'Converter',
    version: '1.0.0',
    description: 'Data import/export functionality',
    author: 'Node Graph Notebook',
  );

  @override
  List<ServiceRegistration> registerServices() => [];

  @override
  List<BlocProvider> registerBlocs() => [
    BlocProvider<ConverterBloc>(
      create: (ctx) => ConverterBloc(commandBus: ctx.read<CommandBus>()),
    ),
  ];

  @override
  List<HookFactory> registerHooks() => [
    ConverterToolbarHook.new,
  ];

  @override
  Future<void> onLoad(PluginContext context) async {
    _registerCommandHandlers(context);
    debugPrint('[ConverterPlugin] Converter plugin loaded');
  }

  void _registerCommandHandlers(PluginContext context) {
    final commandBus = context.get<CommandBus>();
    final importExportService = context.get<ImportExportService>();

    commandBus.registerHandlers({
      PreviewImportCommand: PreviewImportHandler(importExportService),
      ExecuteImportCommand: ExecuteImportHandler(importExportService),
      PreviewExportCommand: PreviewExportHandler(importExportService),
      ExecuteExportCommand: ExecuteExportHandler(importExportService),
      BatchImportCommand: BatchImportHandler(importExportService),
    });
  }
}
