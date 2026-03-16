import 'package:flutter/material.dart';

import '../../../core/models/node.dart';
import '../../../core/plugin/plugin.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/ui_hook.dart';
import '../../../core/repositories/node_repository.dart';
import 'command/ai_commands.dart';
import 'handler/analyze_node_handler.dart';
import 'service/ai_service.dart';
import 'service/ai_service_bindings.dart';

/// AI 集成插件
///
/// 提供 AI 功能：节点分析、连接建议、图摘要等
class AIIntegrationPlugin extends MainToolbarHook {
  PluginState _state = PluginState.loaded;

  @override
  PluginState get state => _state;

  @override
  set state(PluginState newState) {
    _state = newState;
  }

  @override
  int get priority => 40;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'ai_integration',
    name: 'AI Integration',
    version: '1.0.0',
    description: 'AI-powered node analysis and connection suggestions',
    author: 'Node Graph Notebook',
  );

  @override
  List<ServiceBinding> registerServices() => [AIServiceBinding()];

  @override
  Widget renderToolbar(MainToolbarHookContext context) => IconButton(
      icon: const Icon(Icons.psychology, color: Colors.purple),
      tooltip: 'AI Tools',
      onPressed: () => _showAIMenu(context),
    );

  /// 显示 AI 菜单
  void _showAIMenu(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;

    if (buildContext == null) {
      debugPrint('AIIntegrationPlugin: BuildContext not found');
      return;
    }

    showModalBottomSheet(
      context: buildContext,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('分析选中节点'),
              subtitle: const Text('使用 AI 分析节点内容'),
              onTap: () {
                Navigator.pop(ctx);
                _analyzeSelectedNodes(context, buildContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.hub),
              title: const Text('推荐连接'),
              subtitle: const Text('AI 分析并推荐节点连接'),
              onTap: () {
                Navigator.pop(ctx);
                _suggestConnections(context, buildContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize),
              title: const Text('生成图摘要'),
              subtitle: const Text('AI 生成整张图的摘要'),
              onTap: () {
                Navigator.pop(ctx);
                _generateGraphSummary(context, buildContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('生成节点'),
              subtitle: const Text('使用 AI 生成新节点内容'),
              onTap: () {
                Navigator.pop(ctx);
                _showGenerateNodeDialog(context, buildContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 分析选中的节点
  Future<void> _analyzeSelectedNodes(
    MainToolbarHookContext context,
    BuildContext buildContext,
  ) async {
    if (context.pluginContext == null) {
      debugPrint('AIIntegrationPlugin: PluginContext not available');
      _showError(buildContext, 'Plugin system not available');
      return;
    }

    // TODO: 获取选中的节点列表
    // 当前简化版本：提示用户输入节点 ID
    final nodeId = await _promptForNodeId(buildContext);
    if (nodeId == null) return;

    try {
      // 显示加载指示器
      _showLoading(buildContext, '正在分析节点...');

      // 读取节点
      final nodeRepository = context.pluginContext!.read<NodeRepository>();
      final node = await nodeRepository.load(nodeId);

      if (node == null) {
        Navigator.pop(buildContext);
        _showError(buildContext, '节点不存在: $nodeId');
        return;
      }

      // 执行分析命令
      final result = await context.pluginContext!.commandBus.dispatch(
        AnalyzeNodeCommand(node: node),
      );

      // 关闭加载指示器
      if (buildContext.mounted) {
        Navigator.pop(buildContext);
      }

      if (!result.isSuccess) {
        _showError(buildContext, '分析失败: ${result.error}');
        return;
      }

      final analysisResult = result.data as NodeAnalysis;
      _showAnalysisResult(buildContext, analysisResult);
    } catch (e) {
      if (buildContext.mounted) {
        Navigator.pop(buildContext);
      }
      _showError(buildContext, '分析出错: $e');
    }
  }

  /// 推荐连接
  Future<void> _suggestConnections(
    MainToolbarHookContext context,
    BuildContext buildContext,
  ) async {
    if (context.pluginContext == null) {
      _showError(buildContext, 'Plugin system not available');
      return;
    }

    try {
      // 显示加载指示器
      _showLoading(buildContext, '正在分析节点关系...');

      // 读取所有节点
      final nodeRepository = context.pluginContext!.read<NodeRepository>();
      final nodes = await nodeRepository.queryAll();

      if (nodes.isEmpty) {
        Navigator.pop(buildContext);
        _showError(buildContext, '没有节点可用于分析');
        return;
      }

      // 执行推荐命令
      final result = await context.pluginContext!.commandBus.dispatch(
        SuggestConnectionsCommand(
          nodes: nodes,
          maxSuggestions: 10,
          minConfidence: 0.7,
        ),
      );

      // 关闭加载指示器
      if (buildContext.mounted) {
        Navigator.pop(buildContext);
      }

      if (!result.isSuccess) {
        _showError(buildContext, '推荐失败: ${result.error}');
        return;
      }

      final suggestions = result.data as List<ConnectionSuggestion>;
      _showConnectionSuggestions(buildContext, suggestions);
    } catch (e) {
      if (buildContext.mounted) {
        Navigator.pop(buildContext);
      }
      _showError(buildContext, '推荐出错: $e');
    }
  }

  /// 生成图摘要
  Future<void> _generateGraphSummary(
    MainToolbarHookContext context,
    BuildContext buildContext,
  ) async {
    if (context.pluginContext == null) {
      _showError(buildContext, 'Plugin system not available');
      return;
    }

    try {
      // 显示加载指示器
      _showLoading(buildContext, '正在生成图摘要...');

      // 执行摘要命令
      final result = await context.pluginContext!.commandBus.dispatch(
        GenerateGraphSummaryCommand(),
      );

      // 关闭加载指示器
      if (buildContext.mounted) {
        Navigator.pop(buildContext);
      }

      if (!result.isSuccess) {
        _showError(buildContext, '生成失败: ${result.error}');
        return;
      }

      final summary = result.data as GraphSummary;
      _showGraphSummary(buildContext, summary);
    } catch (e) {
      if (buildContext.mounted) {
        Navigator.pop(buildContext);
      }
      _showError(buildContext, '生成出错: $e');
    }
  }

  /// 显示生成节点对话框
  void _showGenerateNodeDialog(
    MainToolbarHookContext context,
    BuildContext buildContext,
  ) {
    final promptController = TextEditingController();

    showDialog(
      context: buildContext,
      builder: (ctx) => AlertDialog(
        title: const Text('AI 生成节点'),
        content: TextField(
          controller: promptController,
          decoration: const InputDecoration(
            labelText: '提示词',
            hintText: '例如：创建一个关于机器学习的概念节点',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final prompt = promptController.text.trim();
              if (prompt.isEmpty) return;

              Navigator.pop(ctx);

              await _generateNode(context, buildContext, prompt);
            },
            child: const Text('生成'),
          ),
        ],
      ),
    );
  }

  /// 生成节点
  Future<void> _generateNode(
    MainToolbarHookContext context,
    BuildContext buildContext,
    String prompt,
  ) async {
    if (context.pluginContext == null) {
      _showError(buildContext, 'Plugin system not available');
      return;
    }

    try {
      // 显示加载指示器
      _showLoading(buildContext, '正在生成节点...');

      // 执行生成命令
      final result = await context.pluginContext!.commandBus.dispatch(
        GenerateNodeCommand(prompt: prompt),
      );

      // 关闭加载指示器
      if (buildContext.mounted) {
        Navigator.pop(buildContext);
      }

      if (!result.isSuccess) {
        _showError(buildContext, '生成失败: ${result.error}');
        return;
      }

      final node = result.data as Node;
      ScaffoldMessenger.of(buildContext).showSnackBar(
        SnackBar(
          content: Text('已生成节点: ${node.title}'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (buildContext.mounted) {
        Navigator.pop(buildContext);
      }
      _showError(buildContext, '生成出错: $e');
    }
  }

  /// 显示分析结果
  void _showAnalysisResult(BuildContext context, NodeAnalysis result) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('节点分析结果'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('摘要:', style: Theme.of(ctx).textTheme.titleSmall),
              Text(result.summary),
              const SizedBox(height: 16),
              Text('关键词:', style: Theme.of(ctx).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.keywords
                    .map((k) => Chip(label: Text(k)))
                    .toList(),
              ),
              const SizedBox(height: 16),
              Text('主题:', style: Theme.of(ctx).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: result.topics
                    .map((t) => Chip(label: Text(t)))
                    .toList(),
              ),
              if (result.sentiment != null) ...[
                const SizedBox(height: 16),
                Text('情感倾向: ${result.sentiment}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示连接建议
  void _showConnectionSuggestions(
    BuildContext context,
    List<ConnectionSuggestion> suggestions,
  ) {
    if (suggestions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('没有找到高置信度的连接建议')));
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('连接建议 (${suggestions.length})'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return ListTile(
                title: Text(
                  '${suggestion.fromNodeId} → ${suggestion.toNodeId}',
                ),
                subtitle: Text(suggestion.reason),
                trailing: Text(
                  '${(suggestion.confidence * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    color: suggestion.confidence > 0.8
                        ? Colors.green
                        : suggestion.confidence > 0.6
                        ? Colors.orange
                        : Colors.red,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 显示图摘要
  void _showGraphSummary(BuildContext context, GraphSummary summary) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(summary.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(summary.description),
              const SizedBox(height: 16),
              Text('节点数: ${summary.nodeCount}'),
              Text('连接数: ${summary.connectionCount}'),
              const SizedBox(height: 16),
              Text('关键主题:', style: Theme.of(ctx).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: summary.keyTopics
                    .map((t) => Chip(label: Text(t)))
                    .toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  /// 提示用户输入节点 ID
  Future<String?> _promptForNodeId(BuildContext context) async {
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入节点 ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '节点 ID',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示加载指示器
  void _showLoading(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(message),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示错误消息
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Future<void> onInit() async {}

  @override
  Future<void> onDispose() async {}

  @override
  Future<void> onEnable() async {}

  @override
  Future<void> onDisable() async {}

  @override
  Future<void> onLoad(PluginContext context) async {
    // 注册命令处理器
    _registerCommandHandlers(context);
  }

  @override
  Future<void> onUnload() async {
    // 卸载时的逻辑
  }

  /// 注册命令处理器
  void _registerCommandHandlers(PluginContext context) {
    final commandBus = context.commandBus;
    final aiService = context.read<AIService>();

    // 注册 AI 命令处理器
    commandBus.registerHandler<AnalyzeNodeCommand>(
      AnalyzeNodeHandler(aiService),
      AnalyzeNodeCommand,
    );
  }
}
