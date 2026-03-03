import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../converter/converter_service_impl.dart';
import '../../core/models/models.dart';
import '../../core/repositories/repositories.dart';
import '../../ui/models/models.dart';
import '../../converter/models/models.dart';

/// 转换配置页面
class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  _ConverterPageState();

  late final ConverterServiceImpl _converterService;
  ConversionRule _rule = const ConversionRule(
    splitStrategy: SplitStrategy.heading,
    headingRule: HeadingSplitRule(level: 2),
  );

  String? _selectedPath;
  bool _isDirectory = false; // false = MD → Nodes, true = Nodes → MD
  List<Node> _previewNodes = [];
  String _previewMarkdown = '';
  bool _isConverting = false;
  bool _isPreviewing = false;

  // 合并规则（用于 Nodes → MD）
  MergeRule _mergeRule = const MergeRule(
    strategy: MergeStrategy.hierarchy,
    hierarchyRule: HierarchyMergeRule(),
  );

  @override
  void initState() {
    super.initState();
    // 初始化转换服务，延迟到 build 后获取 Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final repository = context.read<NodeRepository>();
        setState(() {
          _converterService = ConverterServiceImpl(repository);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Markdown Converter'),
      ),
      body: Row(
        children: [
          // 配置面板
          SizedBox(
            width: 400,
            child: _buildConfigPanel(),
          ),

          // 预览面板
          Expanded(
            child: _buildPreviewPanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigPanel() {
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
                  // 清除之前的预览
                  _previewNodes = [];
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
                    onPressed: _previewNodes.isEmpty || _isConverting
                        ? null
                        : _previewConversion,
                    icon: const Icon(Icons.preview),
                    label: const Text('Preview'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _selectedPath == null || _isConverting
                        ? null
                        : _startConversion,
                    icon: _isConverting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_isConverting ? 'Converting...' : 'Convert'),
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

  Widget _buildPreviewPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isDirectory) ...[
            // MD → Nodes 模式
            if (_previewNodes.isEmpty && !_isPreviewing)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.preview,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Preview will appear here',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select a source and click "Preview" to see the conversion results',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              )
            else if (_isPreviewing)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _previewNodes.length,
                  itemBuilder: (ctx, i) {
                    final node = _previewNodes[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          node.isConcept ? Icons.category : Icons.note,
                          color: node.isConcept ? Colors.orange : null,
                        ),
                        title: Text(node.title),
                        subtitle: Text(
                          '${node.content?.length ?? 0} characters, ${node.references.length} references',
                        ),
                        trailing: Chip(
                          label: Text(node.type.name),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ] else ...[
            // Nodes → MD 模式
            if (_previewMarkdown.isEmpty && !_isPreviewing)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Markdown preview will appear here',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  ],
                ),
              )
            else if (_isPreviewing)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(_previewMarkdown),
                ),
              ),
          ],
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
            _previewNodes.clear();
          });
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
            _previewNodes.clear();
          });
        }
      }
    } else {
      // Nodes → MD 模式：选择节点
      final nodeModel = context.read<NodeModel>();
      final nodes = nodeModel.nodes;

      if (nodes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No nodes available to convert')),
          );
        }
        return;
      }

      setState(() {
        _previewNodes = nodes;
        _selectedPath = 'nodes';
      });
    }
  }

  Future<void> _previewConversion() async {
    if (_selectedPath == null) return;

    setState(() {
      _isPreviewing = true;
    });

    try {
      if (!_isDirectory) {
        // MD → Nodes 模式
        List<Node> nodes;

        if (_selectedPath == 'nodes') {
          // 使用现有节点
          nodes = _previewNodes;
        } else {
          final isDir = FileSystemEntity.isDirectorySync(_selectedPath!);
          if (isDir) {
            // 批量预览 - 只处理前几个文件
            final dir = Directory(_selectedPath!);
            final files = await dir.list().where((f) => f.path.endsWith('.md')).take(5).toList();

            nodes = <Node>[];
            for (final file in files) {
              final fileNodes = await _converterService.fileToNodes(
                filePath: file.path,
                rule: _rule,
              );
              nodes.addAll(fileNodes);
            }
          } else {
            nodes = await _converterService.fileToNodes(
              filePath: _selectedPath!,
              rule: _rule,
            );
          }
        }

        setState(() {
          _previewNodes = nodes.take(50).toList();
        });
      } else {
        // Nodes → MD 模式
        final markdown = await _converterService.nodesToMarkdown(
          nodes: _previewNodes,
          rule: _mergeRule,
        );

        setState(() {
          _previewMarkdown = markdown;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preview failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPreviewing = false;
        });
      }
    }
  }

  Future<void> _startConversion() async {
    if (_selectedPath == null) return;

    setState(() {
      _isConverting = true;
    });

    try {
      if (_isDirectory) {
        // 批量转换
        final result = await _converterService.convertDirectory(
          inputPath: _selectedPath!,
          outputPath: 'data/nodes',
          config: ConversionConfig(rule: _rule),
          onProgress: (current, total) {
            // 可以显示进度
            debugPrint('Progress: $current/$total');
          },
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Conversion complete!\n'
                'Success: ${result.successCount}\n'
                'Failed: ${result.failureCount}',
              ),
            ),
          );

          // 刷新节点列表
          context.read<NodeModel>().loadNodes();
        }
      } else {
        // 单文件转换
        final nodes = await _converterService.fileToNodes(
          filePath: _selectedPath!,
          rule: _rule,
        );

        final nodeModel = context.read<NodeModel>();
        for (final node in nodes) {
          await nodeModel.createNode(
            type: node.type,
            title: node.title,
            content: node.content,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Created ${nodes.length} nodes')),
          );

          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conversion failed: $e')),
        );
      }
    } finally {
      setState(() {
        _isConverting = false;
      });
    }
  }
}
