import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/cqrs/query/query_bus.dart';
import '../../../../core/models/models.dart';
import '../../../../core/plugin/plugin_context.dart';
import '../../../../core/repositories/graph_repository.dart';
import '../../../../core/repositories/node_repository.dart';
import '../../../../core/services/services.dart';
import '../../../core/cqrs/commands/command_bus.dart';
import '../../graph/bloc/node_bloc.dart';
import '../../graph/bloc/node_event.dart';
import '../function_calling/service/ai_function_calling_service.dart';
import '../function_calling/tool/ai_tool.dart';
import '../service/ai_service.dart';

/// AI 聊天对话框
///
/// 功能：
/// - 与 AI 节点进行对话交互
/// - AI 能理解连接的节点内容
/// - 支持创建新节点
/// - 支持 function calling
class AIChatDialog extends StatefulWidget {
  /// 创建 AI 聊天对话框
  ///
  /// [aiNode] AI 节点实例
  /// [connectedNodes] 与 AI 节点连接的节点列表
  /// [enableFunctionCalling] - 是否启用 function calling，默认为 true
  const AIChatDialog({
    super.key,
    required this.aiNode,
    this.connectedNodes = const [],
    this.enableFunctionCalling = true,
  });

  /// AI 节点
  final Node aiNode;

  /// 连接的节点（AI 可以理解这些节点的内容）
  final List<Node> connectedNodes;

  /// 是否启用 function calling
  final bool enableFunctionCalling;

  @override
  State<AIChatDialog> createState() => _AIChatDialogState();
}

class _AIChatDialogState extends State<AIChatDialog> {
  late TextEditingController _messageController;
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  // Function Calling 服务
  AIFunctionCallingService? _functionCallingService;
  StreamSubscription<ToolCallEvent>? _toolCallSubscription;

  // === 扩展点：自定义功能处理器 ===
  /// 功能命令处理器映射
  /// 格式: {命令前缀: 处理函数}
  final Map<String, Future<String> Function(String, _ChatMessageBuilder)>
  _commandHandlers = {};

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();

    // 初始化 function calling 服务
    if (widget.enableFunctionCalling) {
      _functionCallingService = AIFunctionCallingService();

      // 订阅工具调用事件
      _toolCallSubscription =
          _functionCallingService!.toolCallStream.listen(_handleToolCallEvent);
    }

    _addSystemMessage(
      '🤖 AI Assistant: ${widget.aiNode.title}\n'
      'I can help you create and understand nodes. '
      'Connected to ${widget.connectedNodes.length} node(s).\n'
      '\nCommands:\n'
      '/create <title> - Create a new node\n'
      '/summarize - Summarize connected nodes\n'
      '/help - Show all commands'
      '${widget.enableFunctionCalling ? '\n\n✨ Function Calling enabled' : ''}',
    );

    // 注册默认命令处理器
    _registerDefaultCommands();
  }

  @override
  void dispose() {
    _toolCallSubscription?.cancel();
    _functionCallingService?.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// 处理工具调用事件
  ///
  /// 在 UI 中显示工具调用过程
  void _handleToolCallEvent(ToolCallEvent event) {
    if (event is ToolCallStarted) {
      _addSystemMessage(
        '🔧 Calling tool: ${event.toolId}\n'
        'Arguments: ${event.arguments}',
      );
    } else if (event is ToolCallSucceeded) {
      _addSystemMessage(
        '✅ Tool succeeded: ${event.toolId}\n'
        'Summary: ${event.result.summary ?? "OK"}',
      );
    } else if (event is ToolCallFailed) {
      _addSystemMessage(
        '❌ Tool failed: ${event.toolId}\n'
        'Error: ${event.error}',
      );
    }
  }

  /// === 架构说明：命令系统 ===
  /// 设计意图：提供可扩展的命令系统，方便后续添加新功能
  /// 实现方式：通过命令前缀路由到不同的处理器
  void _registerDefaultCommands() {
    // 创建节点命令
    _commandHandlers['/create'] = _handleCreateCommand;

    // 总结命令
    _commandHandlers['/summarize'] = _handleSummarizeCommand;

    // 帮助命令
    _commandHandlers['/help'] = _handleHelpCommand;

    // 预留扩展点：可以在此添加更多命令处理器
    // 例如：
    // _commandHandlers['/analyze'] = _handleAnalyzeCommand;
    // _commandHandlers['/connect'] = _handleConnectCommand;
  }

  /// 处理创建节点命令
  ///
  /// 格式: /create <节点标题>
  Future<String> _handleCreateCommand(
    String command,
    _ChatMessageBuilder messageBuilder,
  ) async {
    final parts = command.split(' ');
    if (parts.length < 2) {
      return '❌ Usage: /create <node title>';
    }

    final title = parts.sublist(1).join(' ');
    final nodeBloc = context.read<NodeBloc>();

    try {
      // 创建新节点
      nodeBloc.add(
        NodeCreateEvent(
          title: title,
          content: 'Created with assistance from ${widget.aiNode.title}',
        ),
      );

      return '✓ Created node: "$title". You can manually connect it to AI if needed.';
    } catch (e) {
      return '❌ Failed to create node: ${e.toString()}';
    }
  }

  /// 处理总结命令
  ///
  /// 用途：让 AI 总结所有连接的节点内容
  Future<String> _handleSummarizeCommand(
    String command,
    _ChatMessageBuilder messageBuilder,
  ) async {
    if (widget.connectedNodes.isEmpty) {
      return 'ℹ️ No connected nodes to summarize.';
    }

    try {
      final settingsService = context.read<SettingsService>();
      if (!settingsService.isAIConfigured) {
        return '❌ AI not configured. Please configure AI settings first.';
      }

      // 构建上下文（重命名变量以避免与 BuildContext 冲突）
      final nodesContext = widget.connectedNodes
          .map((n) => '# ${n.title}\n${n.content ?? ""}')
          .join('\n\n');

      // 调用 AI 总结
      final response = await _callAI('Summarize these nodes:\n\n$nodesContext');

      return response;
    } catch (e) {
      return '❌ Failed to summarize: ${e.toString()}';
    }
  }

  /// 处理帮助命令
  Future<String> _handleHelpCommand(
    String command,
    _ChatMessageBuilder messageBuilder,
  ) async => '''
Available Commands:

/create <title> - Create a new node
  Example: /create My New Idea

/summarize - Summarize all connected nodes
  AI will analyze and summarize connected nodes

/help - Show this help message

Extension Commands:
  (Add custom commands by extending _commandHandlers)
''';

  /// === 核心功能：发送消息 ===
  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _isLoading) return;

    // 检查是否是命令
    if (text.startsWith('/')) {
      await _handleCommand(text);
      return;
    }

    // 常规聊天消息
    _addMessage(text, true);
    _messageController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      String response;

      // 优先使用 function calling
      if (widget.enableFunctionCalling && _functionCallingService != null) {
        final provider = _getAIProvider();
        final toolContext = AIToolContext(
          commandBus: context.read<CommandBus>(),
          pluginContext: context.read<PluginContext>(),
          queryBus: context.read<QueryBus?>(),
          nodeRepository: context.read<NodeRepository?>(),
          graphRepository: context.read<GraphRepository?>(),
        );

        response = await _functionCallingService!.chatWithFunctionCalling(
          userMessage: text,
          provider: provider,
          context: toolContext,
        );
      } else {
        // 回退到传统方式
        response = await _callAIWithContext(text);
      }

      _addMessage(response, false);
    } catch (e) {
      _addSystemMessage('❌ Error: ${e.toString()}');
      debugPrint('AI Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 处理命令消息
  Future<void> _handleCommand(String command) async {
    _addMessage(command, true);
    _messageController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      // 查找命令处理器
      final commandPart = command.split(' ')[0];
      final handler = _commandHandlers[commandPart];

      if (handler == null) {
        _addSystemMessage(
          '❓ Unknown command: $commandPart. Type /help for available commands.',
        );
        return;
      }

      // 创建消息构建器（用于在命令处理器中添加消息）
      final messageBuilder = _ChatMessageBuilder(
        addMessage: _addMessage,
        addSystemMessage: _addSystemMessage,
      );

      // 执行命令
      final response = await handler(command, messageBuilder);
      _addSystemMessage(response);
    } catch (e) {
      _addSystemMessage('❌ Command error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// === 架构说明：AI 调用 ===
  /// 设计意图：统一的 AI 调用接口，自动包含上下文
  /// 上下文构建：包含连接的节点信息，让 AI 能理解关联内容
  Future<String> _callAIWithContext(String userMessage) async {
    // 构建上下文
    final contextBuilder = StringBuffer();

    if (widget.connectedNodes.isNotEmpty) {
      contextBuilder.writeln('Context: I am connected to these nodes:');
      for (final node in widget.connectedNodes) {
        contextBuilder.writeln(
          '- ${node.title}: ${node.content ?? "(no content)"}',
        );
      }
      contextBuilder.writeln();
    }

    contextBuilder.writeln('User: $userMessage');

    return _callAI(contextBuilder.toString());
  }

  /// 调用 AI 服务
  ///
  /// 架构说明：这是所有 AI 调用的统一入口点
  /// 扩展方式：子类可以覆盖此方法以修改 AI 行为
  Future<String> _callAI(String prompt) async {
    final provider = _getAIProvider();
    return provider.generate(prompt);
  }

  /// 获取 AI Provider
  ///
  /// 根据设置创建相应的 AI Provider
  AIProvider _getAIProvider() {
    final settingsService = context.read<SettingsService>();

    // 验证配置
    if (!settingsService.isAIConfigured) {
      throw Exception('AI not configured. Please configure AI settings first.');
    }

    // 创建对应的 Provider
    if (settingsService.aiProvider == 'anthropic') {
      return AnthropicProvider(
        apiKey: settingsService.aiApiKey!,
        model: settingsService.aiModel,
        baseUrl: settingsService.aiBaseUrl,
      );
    } else if (settingsService.aiProvider == 'zhipuai') {
      return ZhipuAIProvider(
        apiKey: settingsService.aiApiKey!,
        model: settingsService.aiModel,
        baseUrl: settingsService.aiBaseUrl,
      );
    } else {
      return OpenAIProvider(
        apiKey: settingsService.aiApiKey!,
        model: settingsService.aiModel,
        baseUrl: settingsService.aiBaseUrl,
      );
    }
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false, isSystem: true));
    });
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: isUser, isSystem: false));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<ThemeService>().themeData;

    return Dialog(
      child: Container(
        width: 700,
        height: 600,
        color: theme.backgrounds.primary,
        child: Column(
          children: [
            // === Header ===
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: theme.ui.divider.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  // AI 图标
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.status.info.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.smart_toy,
                      color: theme.status.info,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 标题和信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.aiNode.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Connected to ${widget.connectedNodes.length} node(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.text.onDark.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 关闭按钮
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // === Chat Area ===
            Expanded(
              child: ColoredBox(
                color: theme.backgrounds.secondary,
                child: _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.smart_toy,
                              size: 64,
                              color: theme.ui.icon.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Start a conversation with AI',
                              style: TextStyle(
                                color: theme.text.onDark.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          return _buildMessageWidget(message, theme);
                        },
                      ),
              ),
            ),

            // === Input Area ===
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.ui.divider.withValues(alpha: 0.5),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: 'Type a message or /command...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (value) {
                        if (!_isLoading) {
                          _sendMessage(value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isLoading
                        ? null
                        : () => _sendMessage(_messageController.text),
                    icon: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(theme.ui.icon),
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageWidget(_ChatMessage message, AppThemeData theme) {
    if (message.isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.status.info.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.status.info.withValues(alpha: 0.3)),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            fontSize: 12,
            color: theme.text.onDark,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 450),
        decoration: BoxDecoration(
          color: isUser
              ? theme.ui.icon.withValues(alpha: 0.8)
              : theme.backgrounds.tertiary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : theme.text.onDark,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// === 架构说明：辅助类 ===

/// 聊天消息数据模型
class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
    required this.isSystem,
  });

  final String text;
  final bool isUser;
  final bool isSystem;
}

/// 消息构建器
///
/// 架构说明：提供给命令处理器使用，用于在处理过程中添加消息
/// 这样命令处理器可以逐步反馈进度，而不是一次性返回结果
class _ChatMessageBuilder {
  const _ChatMessageBuilder({
    required this.addMessage,
    required this.addSystemMessage,
  });

  final void Function(String text, bool isUser) addMessage;
  final void Function(String text) addSystemMessage;
}
