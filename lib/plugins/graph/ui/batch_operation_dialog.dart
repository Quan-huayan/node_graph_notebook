import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../converter/bloc/converter_bloc.dart';
import '../../converter/bloc/converter_event.dart';
import '../../converter/bloc/converter_state.dart';
import '../../converter/models/models.dart';

/// 批量操作预设
class BatchPreset {
  /// 创建批量操作预设
  const BatchPreset({
    required this.name,
    required this.description,
    required this.rule,
  });

  /// 预设名称
  final String name;
  /// 预设描述
  final String description;
  /// 转换规则
  final ConversionRule rule;
}

/// 批量操作对话框
class BatchOperationDialog extends StatefulWidget {
  /// 创建批量操作对话框
  const BatchOperationDialog({super.key});

  @override
  State<BatchOperationDialog> createState() => _BatchOperationDialogState();
}

class _BatchOperationDialogState extends State<BatchOperationDialog> {
  List<String> _selectedFiles = [];
  BatchPreset? _selectedPreset;
  bool _isProcessing = false;

  // 内置预设
  final List<BatchPreset> _presets = const [
    BatchPreset(
      name: 'Standard Import',
      description: 'Split by H2, preserve structure',
      rule: ConversionRule(
        splitStrategy: SplitStrategy.heading,
        headingRule: HeadingSplitRule(level: 2),
      ),
    ),
    BatchPreset(
      name: 'Obsidian Notes',
      description: 'Split by --- separator',
      rule: ConversionRule(
        splitStrategy: SplitStrategy.separator,
        separatorRule: SeparatorSplitRule(pattern: r'^---$'),
      ),
    ),
    BatchPreset(
      name: 'Research Papers',
      description: 'AI smart split for academic content',
      rule: ConversionRule(
        splitStrategy: SplitStrategy.aiSmart,
        aiRule: AISmartSplitRule(
          minSectionLength: 500,
          semanticSimilarityThreshold: 0.7,
        ),
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedPreset = _presets.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Batch Import'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: BlocListener<ConverterBloc, ConverterState>(
          listener: (context, state) {
            if (state.isProcessing) {
              setState(() {
                _isProcessing = true;
              });
            } else if (state.hasResult) {
              setState(() {
                _isProcessing = false;
              });

              // 显示结果
              if (context.mounted) {
                final result = state.conversionResult;
                final message = result != null
                    ? 'Imported ${result.successCount} nodes, ${result.failureCount} failed in ${result.duration.inSeconds}s'
                    : 'Batch import completed';

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    duration: const Duration(seconds: 3),
                  ),
                );

                if (result != null && result.failureCount == 0) {
                  Navigator.pop(context);
                }
              }
            } else if (state.hasError) {
              setState(() {
                _isProcessing = false;
              });
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 预设选择
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Import Preset', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<BatchPreset>(
                        initialValue: _selectedPreset,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: _presets.map((preset) => DropdownMenuItem(
                            value: preset,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(preset.name),
                                Text(
                                  preset.description,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          )).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPreset = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 文件选择
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Files', style: theme.textTheme.titleSmall),
                          ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _selectFiles,
                            icon: const Icon(Icons.folder_open, size: 16),
                            label: const Text('Add Files'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(32),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_selectedFiles.length} files selected',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      // 文件列表
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 150),
                        child: _selectedFiles.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('No files selected'),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: _selectedFiles.length,
                                itemBuilder: (context, index) {
                                  final file = _selectedFiles[index];
                                  final fileName = file
                                      .split('\\')
                                      .last
                                      .split('/')
                                      .last;
                                  return ListTile(
                                    dense: true,
                                    leading: const Icon(
                                      Icons.description,
                                      size: 16,
                                    ),
                                    title: Text(
                                      fileName,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    trailing: IconButton(
                                      icon: const Icon(Icons.close, size: 16),
                                      onPressed: _isProcessing
                                          ? null
                                          : () {
                                              setState(() {
                                                _selectedFiles.removeAt(index);
                                              });
                                            },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 进度显示
              BlocBuilder<ConverterBloc, ConverterState>(
                builder: (context, state) {
                  if (!_isProcessing) {
                    return const SizedBox.shrink();
                  }

                  final current = state.currentProgress ?? 0;
                  final total = state.totalProgress ?? 1;

                  return DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          LinearProgressIndicator(
                            value: total > 0 ? current / total : 0,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Processing: $current / $total',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _canStart() && !_isProcessing
              ? () => _startBatchImport(context)
              : null,
          child: _isProcessing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('Start Import (${_selectedFiles.length})'),
        ),
      ],
    );
  }

  Future<void> _selectFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
      allowMultiple: true,
    );

    if (result != null) {
      final paths = result.files
          .map((f) => f.path)
          .whereType<String>()
          .toList();

      setState(() {
        _selectedFiles = {..._selectedFiles, ...paths}.toList();
      });
    }
  }

  bool _canStart() => _selectedFiles.isNotEmpty && _selectedPreset != null;

  void _startBatchImport(BuildContext context) {
    if (_selectedPreset == null) return;

    final config = ConversionConfig(
      rule: _selectedPreset!.rule,
      preserveOriginalFiles: true,
    );

    context.read<ConverterBloc>().add(BatchImportEvent(_selectedFiles, config));
  }
}
