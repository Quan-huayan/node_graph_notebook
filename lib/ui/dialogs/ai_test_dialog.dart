import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../ai/ai_service.dart';
import '../../core/services/services.dart';
import '../../core/services/theme/app_theme.dart';

/// AI 测试对话框
class AITestDialog extends StatefulWidget {
  const AITestDialog({super.key});

  @override
  State<AITestDialog> createState() => _AITestDialogState();
}

class _AITestDialogState extends State<AITestDialog> {
  late TextEditingController _messageController;
  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _addSystemMessage('AI connection test initialized. Type a message to test.');
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: false,
          isSystem: true,
        ),
      );
    });
  }

  void _addMessage(String text, bool isUser) {
    setState(() {
      _messages.add(
        _ChatMessage(
          text: text,
          isUser: isUser,
          isSystem: false,
        ),
      );
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty) return;

    _addMessage(text, true);
    _messageController.clear();

    setState(() {
      _isLoading = true;
    });

    try {
      final settingsService = context.read<SettingsService>();
      final aiService = context.read<AIServiceImpl>();

      // 验证配置
      if (!settingsService.isAIConfigured) {
        _addSystemMessage('❌ AI not configured. Please configure AI settings first.');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 创建对应的 Provider
      final AIProvider provider;
      if (settingsService.aiProvider == 'anthropic') {
        provider = AnthropicProvider(
          apiKey: settingsService.aiApiKey!,
          model: settingsService.aiModel,
          baseUrl: settingsService.aiBaseUrl,
        );
      } else {
        provider = OpenAIProvider(
          apiKey: settingsService.aiApiKey!,
          model: settingsService.aiModel,
          baseUrl: settingsService.aiBaseUrl,
        );
      }

      // 设置 Provider
      aiService.setProvider(provider);

      // 调用 AI
      final response = await provider.generate(text);
      _addMessage(response, false);
      _addSystemMessage('✓ Message sent and response received successfully');
    } catch (e) {
      _addSystemMessage('❌ Error: ${e.toString()}');
      debugPrint('AI Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppThemeData theme = context.read<ThemeService>().themeData;

    return Dialog(
      child: Container(
        width: 600,
        height: 500,
        color: theme.backgrounds.primary,
        child: Column(
          children: [
            // Header
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
                  Icon(
                    Icons.chat_bubble_outline,
                    color: theme.ui.icon,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Test AI Connection',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Chat Area
            Expanded(
              child: ColoredBox(
                color: theme.backgrounds.secondary,
                child: _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Type a message below to start',
                          style: Theme.of(context).textTheme.bodyMedium,
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

            // Input Area
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
                        hintText: 'Type your message...',
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
                              valueColor: AlwaysStoppedAnimation(
                                theme.ui.icon,
                              ),
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
          border: Border.all(
            color: theme.status.info.withValues(alpha: 0.3),
          ),
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
        constraints: const BoxConstraints(maxWidth: 400),
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

class _ChatMessage {
  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.isSystem,
  });

  final String text;
  final bool isUser;
  final bool isSystem;
}
