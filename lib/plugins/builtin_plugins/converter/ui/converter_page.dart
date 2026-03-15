import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/graph_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/graph_event.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/node_bloc.dart';
import 'package:node_graph_notebook/plugins/builtin_plugins/graph/bloc/node_event.dart';
import '../service/converter_service_impl.dart';
import '../../../../core/models/models.dart';
import '../../../../core/repositories/repositories.dart';
import '../models/models.dart';
import 'convert_config_panel.dart';
import 'convert_preview_panel.dart';

/// 转换配置页面
class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  _ConverterPageState();

  late final ConverterServiceImpl _converterService;
  final _rule = const ConversionRule(
    splitStrategy: SplitStrategy.heading,
    headingRule: HeadingSplitRule(level: 2),
  );

  String? _selectedPath;
  final bool _isDirectory = false; // false = MD → Nodes, true = Nodes → MD
  List<Node> _previewNodes = [];
  String _previewMarkdown = '';
  bool _isConverting = false;
  bool _isPreviewing = false;

  // 合并规则（用于 Nodes → MD）
  final _mergeRule = const MergeRule(
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
            child: ConvertConfigPanel(
              onPathSelected: (path) {
                setState(() {
                  _selectedPath = path;
                  _previewNodes.clear();
                });
              },
              onNodesSelected: (nodes) {
                setState(() {
                  _previewNodes = nodes;
                });
              },
              onPreviewRequested: _previewConversion,
              onConvertRequested: _startConversion,
              isConverting: _isConverting,
              isPreviewing: _isPreviewing,
              previewNodes: _previewNodes,
            ),
          ),

          // 预览面板
          Expanded(
            child: ConvertPreviewPanel(
              isDirectory: _isDirectory,
              previewNodes: _previewNodes,
              previewMarkdown: _previewMarkdown,
              isPreviewing: _isPreviewing,
            ),
          ),
        ],
      ),
    );
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
          context.read<NodeBloc>().add(const NodeLoadEvent());
        }
      } else {
        // 单文件转换
        final nodes = await _converterService.fileToNodes(
          filePath: _selectedPath!,
          rule: _rule,
        );

        final nodeBloc = context.read<NodeBloc>();
        final graphBloc = context.read<GraphBloc>();
        final nodeRepository = context.read<NodeRepository>();

        // 批量保存所有节点到文件
        await nodeRepository.saveAll(nodes);

        // 刷新节点列表
        nodeBloc.add(const NodeLoadEvent());

        // 等待节点列表更新完成
        await Future.delayed(const Duration(milliseconds: 500));

        // 将所有节点添加到图中（批量操作）
        final events = nodes.map((node) => NodeAddEvent(node.id)).toList();
        graphBloc.add(BatchEvent(events));

        // 等待 GraphBloc 处理完成
        await Future.delayed(const Duration(milliseconds: 1000));

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
