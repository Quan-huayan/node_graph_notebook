import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/models/node.dart';
import '../../bloc/blocs.dart';
import '../widgets/node_selector_widget.dart';
import '../widgets/graph_preview_widget.dart';
import '../../converter/models/models.dart';

/// 导入 Markdown 对话框
class ImportMarkdownDialog extends StatefulWidget {
  const ImportMarkdownDialog({super.key});

  @override
  State<ImportMarkdownDialog> createState() => _ImportMarkdownDialogState();
}

class _ImportMarkdownDialogState extends State<ImportMarkdownDialog> {
  String? _filePath;
  ConversionRule? _selectedRule;
  Set<int> _selectedIndices = {};

  // 内置规则
  final List<ConversionRule> _rules = const [
    ConversionRule(
      splitStrategy: SplitStrategy.heading,
      headingRule: HeadingSplitRule(level: 2),
      extractConnections: true,
      extractTags: true,
    ),
    ConversionRule(
      splitStrategy: SplitStrategy.separator,
      separatorRule: SeparatorSplitRule(pattern: r'^---$'),
      extractConnections: true,
      extractTags: true,
    ),
    ConversionRule(
      splitStrategy: SplitStrategy.aiSmart,
      aiRule: AISmartSplitRule(
        minSectionLength: 500,
        semanticSimilarityThreshold: 0.7,
      ),
      extractConnections: true,
      extractTags: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocListener<ConverterBloc, ConverterState>(
      listener: (context, state) {
        // 监听导入完成
        if (state.conversionResult != null) {
          final result = state.conversionResult!;
          final graphBloc = context.read<GraphBloc>();

          if (result.errors.isEmpty) {
            // 导入成功：刷新图显示
            graphBloc.add(const GraphInitializeEvent());

            // 显示成功消息
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Successfully imported ${result.successCount} nodes'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );

            // 关闭对话框
            Navigator.pop(context);
          } else {
            // 导入部分成功或失败：显示错误
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Imported ${result.successCount} nodes with ${result.errors.length} errors',
                ),
                backgroundColor: Colors.orange,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Details',
                  textColor: Colors.white,
                  onPressed: () {
                    // 显示详细错误
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Import Errors'),
                        content: SizedBox(
                          width: 500,
                          height: 300,
                          child: ListView.builder(
                            itemCount: result.errors.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('• ${result.errors[index]}'),
                              );
                            },
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );

            // 如果有成功导入的节点，仍然刷新图并关闭对话框
            if (result.successCount > 0) {
              graphBloc.add(const GraphInitializeEvent());
              Navigator.pop(context);
            }
          }
        }
      },
      child: AlertDialog(
        title: const Text('Import Markdown'),
        content: SizedBox(
          width: 800,
          height: 500,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    // 左列：模式选择
                    SizedBox(
                      width: 150,
                      child: _buildModeSelector(theme),
                    ),

                    const VerticalDivider(width: 1),

                    // 中列：节点选择
                    Expanded(
                      child: _buildNodeSelector(),
                    ),

                    const VerticalDivider(width: 1),

                    // 右列：图形预览
                    SizedBox(
                      width: 200,
                      child: _buildGraphPreview(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _canImport()
                ? () => _importSelected(context)
                : null,
            child: Text('Import Selected (${_selectedIndices.length})'),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Mode',
            style: theme.textTheme.titleSmall,
          ),
        ),
        const Divider(height: 1),
        ListView.builder(
          shrinkWrap: true,
          itemCount: _rules.length,
          itemBuilder: (context, index) {
            final rule = _rules[index];
            final isSelected = _selectedRule == rule;

            String label;
            IconData icon;
            switch (rule.splitStrategy) {
              case SplitStrategy.heading:
                label = 'Split by H2';
                icon = Icons.title;
                break;
              case SplitStrategy.separator:
                label = 'Split by Sep';
                icon = Icons.more_vert;
                break;
              case SplitStrategy.aiSmart:
                label = 'AI Smart';
                icon = Icons.psychology;
                break;
              default:
                label = 'Custom';
                icon = Icons.settings;
            }

            return ListTile(
              leading: Icon(icon, size: 16),
              title: Text(
                label,
                style: theme.textTheme.bodySmall,
              ),
              selected: isSelected,
              onTap: () {
                setState(() {
                  _selectedRule = rule;
                  if (_filePath != null) {
                    _loadPreview();
                  }
                });
              },
            );
          },
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: ElevatedButton.icon(
            onPressed: _selectFile,
            icon: const Icon(Icons.folder_open, size: 16),
            label: const Text('Select File'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNodeSelector() {
    return BlocBuilder<ConverterBloc, ConverterState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text('Error: ${state.error}'),
              ],
            ),
          );
        }

        if (!state.hasImportPreview) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.upload_file, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('Select a file to preview'),
              ],
            ),
          );
        }

        return NodeSelectorWidget(
          nodes: state.importPreviewNodes,
          selectedIndices: _selectedIndices,
          onSelectionChanged: (indices) {
            setState(() {
              _selectedIndices = indices;
            });
          },
        );
      },
    );
  }

  Widget _buildGraphPreview() {
    return BlocBuilder<ConverterBloc, ConverterState>(
      builder: (context, state) {
        final selectedNodes = <Node>[];
        for (final index in _selectedIndices) {
          if (index >= 0 && index < state.importPreviewNodes.length) {
            selectedNodes.add(state.importPreviewNodes[index]);
          }
        }

        return GraphPreviewWidget(nodes: selectedNodes);
      },
    );
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _filePath = result.files.single.path;
        _selectedIndices = {};
        _selectedRule ??= _rules.first;
      });
      _loadPreview();
    }
  }

  void _loadPreview() {
    if (_filePath == null || _selectedRule == null) return;

    context.read<ConverterBloc>().add(
          ImportPreviewEvent(_filePath!, _selectedRule!),
        );
  }

  bool _canImport() {
    return _filePath != null && _selectedIndices.isNotEmpty;
  }

  void _importSelected(BuildContext context) {
    if (_filePath == null || _selectedRule == null) return;

    final sortedIndices = _selectedIndices.toList()..sort();
    context.read<ConverterBloc>().add(
          ImportExecuteEvent(
            _filePath!,
            _selectedRule!,
            sortedIndices,
            addToGraph: true, // 命名参数
          ),
        );
  }
}
