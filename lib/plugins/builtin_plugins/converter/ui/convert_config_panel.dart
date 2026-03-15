import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/node_bloc.dart';
import '../../../../core/models/models.dart';
import '../models/models.dart';

/// 转换配置面板
class ConvertConfigPanel extends StatefulWidget {
  const ConvertConfigPanel({
    super.key,
    required this.onPathSelected,
    required this.onNodesSelected,
    required this.onPreviewRequested,
    required this.onConvertRequested,
    required this.isConverting,
    required this.isPreviewing,
    required this.previewNodes,
  });

  final Function(String?) onPathSelected;
  final Function(List<Node>) onNodesSelected;
  final Function() onPreviewRequested;
  final Function() onConvertRequested;
  final bool isConverting;
  final bool isPreviewing;
  final List<Node> previewNodes;

  @override
  State<ConvertConfigPanel> createState() => _ConvertConfigPanelState();
}

class _ConvertConfigPanelState extends State<ConvertConfigPanel> {
  String? _selectedPath;
  bool _isDirectory = false; // false = MD → Nodes, true = Nodes → MD
  ConversionRule _rule = const ConversionRule(
    splitStrategy: SplitStrategy.heading,
    headingRule: HeadingSplitRule(level: 2),
  );

  // 合并规则（用于 Nodes → MD）
  MergeRule _mergeRule = const MergeRule(
    strategy: MergeStrategy.hierarchy,
    hierarchyRule: HierarchyMergeRule(),
  );

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 文件选择
            Text(
              'Source',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(_selectedPath ?? 'Select file or directory'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _selectSource,
            ),
            const SizedBox(height: 24),

            // 转换方向
            Text(
              'Direction',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('MD → Nodes'),
                  icon: Icon(Icons.arrow_forward),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Nodes → MD'),
                  icon: Icon(Icons.arrow_back),
                ),
              ],
              selected: {_isDirectory},
              onSelectionChanged: (Set<bool> selection) {
                setState(() {
                  _isDirectory = selection.first;
                  _selectedPath = null;
                });
              },
            ),
            const SizedBox(height: 24),

            // 根据转换模式显示不同的选项
            if (!_isDirectory) ...[
              // MD → Nodes 模式：显示拆分规则
              Text(
                'Split Rule',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildSplitRuleSelector(),
              const SizedBox(height: 24),
            ] else ...[
              // Nodes → MD 模式：显示合并规则
              Text(
                'Merge Rule',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildMergeRuleSelector(),
              const SizedBox(height: 24),
            ],

            // 高级选项（仅 MD → Nodes 模式）
            if (!_isDirectory) ...[
              Text(
                'Options',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Extract connections'),
                subtitle: const Text('Auto-detect [[wiki_links]]'),
                value: _rule.extractConnections,
                onChanged: (value) {
                  setState(() {
                    _rule = _rule.copyWith(extractConnections: value);
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Extract tags'),
                subtitle: const Text('Auto-detect #tags'),
                value: _rule.extractTags,
                onChanged: (value) {
                  setState(() {
                    _rule = _rule.copyWith(extractTags: value);
                  });
                },
              ),
              SwitchListTile(
                title: const Text('Parse frontmatter'),
                value: _rule.parseFrontmatter,
                onChanged: (value) {
                  setState(() {
                    _rule = _rule.copyWith(parseFrontmatter: value);
                  });
                },
              ),
              const SizedBox(height: 24),
            ],

            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.previewNodes.isEmpty || widget.isConverting
                        ? null
                        : widget.onPreviewRequested,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedPath == null || widget.isConverting
                        ? null
                        : widget.onConvertRequested,
                    icon: widget.isConverting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(widget.isConverting ? 'Converting...' : 'Convert'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitRuleSelector() {
    return RadioGroup<SplitStrategy>(
      groupValue: _rule.splitStrategy,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            switch (value) {
              case SplitStrategy.heading:
                _rule = _rule.copyWith(
                  splitStrategy: value,
                  headingRule: const HeadingSplitRule(level: 2),
                );
                break;
              case SplitStrategy.separator:
                _rule = _rule.copyWith(
                  splitStrategy: value,
                  separatorRule: const SeparatorSplitRule(pattern: r'^---+$'),
                );
                break;
              case SplitStrategy.aiSmart:
                _rule = _rule.copyWith(
                  splitStrategy: value,
                  aiRule: const AISmartSplitRule(),
                );
                break;
              case SplitStrategy.customRegex:
                // 不处理
                break;
            }
          });
        }
      },
      child: const Column(
        children: [
          RadioListTile<SplitStrategy>(
            title: Text('By Heading'),
            subtitle: Text('Split by # headings'),
            value: SplitStrategy.heading,
          ),
          RadioListTile<SplitStrategy>(
            title: Text('By Separator'),
            subtitle: Text('Split by --- or ___'),
            value: SplitStrategy.separator,
          ),
          RadioListTile<SplitStrategy>(
            title: Text('AI Smart Split'),
            subtitle: Text('AI-powered semantic splitting'),
            value: SplitStrategy.aiSmart,
          ),
        ],
      ),
    );
  }

  Widget _buildMergeRuleSelector() {
    return RadioGroup<MergeStrategy>(
      groupValue: _mergeRule.strategy,
      onChanged: (value) {
        if (value != null) {
          setState(() {
            switch (value) {
              case MergeStrategy.hierarchy:
                _mergeRule = MergeRule(
                  strategy: value,
                  hierarchyRule: const HierarchyMergeRule(),
                );
                break;
              case MergeStrategy.sequence:
                _mergeRule = MergeRule(
                  strategy: value,
                  sequenceRule: const SequenceMergeRule(),
                );
                break;
              case MergeStrategy.custom:
                // 不处理
                break;
            }
          });
        }
      },
      child: const Column(
        children: [
          RadioListTile<MergeStrategy>(
            title: Text('Hierarchy'),
            subtitle: Text('Merge with hierarchical structure'),
            value: MergeStrategy.hierarchy,
          ),
          RadioListTile<MergeStrategy>(
            title: Text('Sequence'),
            subtitle: Text('Merge in sequential order'),
            value: MergeStrategy.sequence,
          ),
        ],
      ),
    );
  }

  Future<void> _selectSource() async {
    if (!_isDirectory) {
      // MD → Nodes 模式：选择 Markdown 文件
      final result = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Select Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('Single File'),
                onTap: () => Navigator.pop(ctx, false),
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Directory'),
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      );

      if (result == null) return;

      if (result) {
        // 选择目录
        final directoryPath = await FilePicker.platform.getDirectoryPath();
        if (directoryPath != null) {
          setState(() {
            _selectedPath = directoryPath;
          });
          widget.onPathSelected(directoryPath);
        }
      } else {
        // 选择文件
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['md', 'markdown'],
        );

        if (result != null &&
            result.files.isNotEmpty &&
            result.files.single.path != null) {
          setState(() {
            _selectedPath = result.files.single.path;
          });
          widget.onPathSelected(result.files.single.path);
        }
      }
    } else {
      // Nodes → MD 模式：选择节点（过滤掉 AI 节点和文件夹）
      final nodeBloc = context.read<NodeBloc>();
      final nodes = nodeBloc.state.nodes.where((n) {
        // 排除文件夹
        if (n.isFolder) return false;

        // 检查是否是 AI 节点
        final isAI = n.metadata['isAI'];
        if (isAI == true) return false;
        if (isAI == 'true') return false;

        return true;
      }).toList();

      if (nodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No nodes available to convert')),
          );
        }
        return;
      }

      setState(() {
        _selectedPath = 'nodes';
      });
      widget.onPathSelected('nodes');
      widget.onNodesSelected(nodes);
    }
  }
}
