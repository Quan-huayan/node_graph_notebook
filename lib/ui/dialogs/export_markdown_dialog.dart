import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../bloc/blocs.dart';
import '../widgets/node_selector_widget.dart';
import '../widgets/markdown_preview_widget.dart';
import '../../converter/models/models.dart';

// 暂时弃用。

/// 导出 Markdown 对话框
class ExportMarkdownDialog extends StatefulWidget {
  const ExportMarkdownDialog({super.key});

  @override
  State<ExportMarkdownDialog> createState() => _ExportMarkdownDialogState();
}

class _ExportMarkdownDialogState extends State<ExportMarkdownDialog> {
  MergeRule? _selectedRule;
  Set<String> _selectedNodeIds = {};
  final bool _isRenderMode = false;

  // 内置规则
  final List<MergeRule> _rules = [
    const MergeRule(
      strategy: MergeStrategy.hierarchy,
      hierarchyRule: HierarchyMergeRule(),
    ),
    const MergeRule(
      strategy: MergeStrategy.sequence,
      sequenceRule: SequenceMergeRule(
        separator: '\n\n---\n\n',
      ),
    ),
    const MergeRule(
      strategy: MergeStrategy.custom,
      customRule: CustomMergeRule(
        template: '# {{title}}\n\n{{content}}\n\n',
      ),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedRule = _rules.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Export Markdown'),
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
                    flex: 2,
                    child: _buildNodeSelector(),
                  ),

                  const VerticalDivider(width: 1),

                  // 右列：Markdown 预览
                  Expanded(
                    flex: 1,
                    child: _buildMarkdownPreview(),
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
          onPressed: _canExport()
              ? () => _exportSelected(context)
              : null,
          child: Text('Export Selected (${_selectedNodeIds.length})'),
        ),
      ],
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
            switch (rule.strategy) {
              case MergeStrategy.hierarchy:
                label = 'Merge Hier';
                icon = Icons.account_tree;
                break;
              case MergeStrategy.sequence:
                label = 'Merge Seq';
                icon = Icons.format_list_numbered;
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
                  _loadPreview();
                });
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildNodeSelector() {
    return BlocBuilder<NodeBloc, NodeState>(
      builder: (context, state) {
        if (state.nodes.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('No nodes available'),
              ],
            ),
          );
        }

        return NodeSelectorWidget(
          nodes: state.nodes,
          selectedIndices: _selectedNodeIds
              .map((id) => state.nodes.indexWhere((n) => n.id == id))
              .where((i) => i >= 0)
              .toSet(),
          onSelectionChanged: (indices) {
            setState(() {
              _selectedNodeIds = indices
                  .map((i) => state.nodes[i].id)
                  .toSet();
              _loadPreview();
            });
          },
        );
      },
    );
  }

  Widget _buildMarkdownPreview() {
    return BlocBuilder<ConverterBloc, ConverterState>(
      builder: (context, state) {
        // 关键修复：所有分支都返回相同的基础结构（包含 Expanded）
        // 避免在 Expanded 内部动态切换不同类型的 widget

        if (state.isLoading) {
          return const Column(
            children: [
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          );
        }

        if (state.error != null) {
          return Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Error: ${state.error}'),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        // 正常状态也使用 Column + Expanded 包裹，保持结构一致
        return Column(
          children: [
            Expanded(
              child: MarkdownPreviewWidget(
                markdown: state.exportPreviewMarkdown,
                isRenderMode: _isRenderMode,
              ),
            ),
          ],
        );
      },
    );
  }

  void _loadPreview() {
    if (_selectedNodeIds.isEmpty || _selectedRule == null) return;

    context.read<ConverterBloc>().add(
          ExportPreviewEvent(
            _selectedNodeIds.toList(),
            _selectedRule!,
          ),
        );
  }

  bool _canExport() {
    return _selectedNodeIds.isNotEmpty;
  }

  Future<void> _exportSelected(BuildContext context) async {
    if (_selectedRule == null) return;

    // 选择输出路径
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save exported markdown',
      fileName: 'exported_notes.md',
      type: FileType.custom,
      allowedExtensions: ['md', 'markdown'],
    );

    if (outputPath == null) return;

    context.read<ConverterBloc>().add(
          ExportExecuteEvent(
            _selectedNodeIds.toList(),
            _selectedRule!,
            outputPath,
          ),
        );

    // 显示完成提示
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${_selectedNodeIds.length} nodes to $outputPath'),
          duration: const Duration(seconds: 3),
        ),
      );
      Navigator.pop(context);
    }
  }
}
