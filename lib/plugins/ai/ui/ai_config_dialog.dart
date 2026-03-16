import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/services.dart';

/// AI 配置对话框
class AIConfigDialog extends StatefulWidget {
  /// 创建 AI 配置对话框
  ///
  /// [settingsService] - 设置服务实例
  const AIConfigDialog({super.key, required this.settingsService});

  /// 设置服务实例
  final SettingsService settingsService;

  @override
  State<AIConfigDialog> createState() => _AIConfigDialogState();
}

class _AIConfigDialogState extends State<AIConfigDialog> {
  late TextEditingController _baseUrlController;
  late TextEditingController _modelController;
  late TextEditingController _apiKeyController;
  late String _selectedProvider;
  bool _showApiKey = false;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.settingsService.aiProvider;
    _baseUrlController = TextEditingController(
      text: widget.settingsService.aiBaseUrl,
    );
    _modelController = TextEditingController(
      text: widget.settingsService.aiModel,
    );
    _apiKeyController = TextEditingController(
      text: widget.settingsService.aiApiKey ?? '',
    );
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _modelController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.read<ThemeService>().themeData;

    return AlertDialog(
      backgroundColor: theme.backgrounds.primary,
      title: const Row(
        children: [
          Icon(Icons.smart_toy_outlined),
          SizedBox(width: 8),
          Text('AI Configuration'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI 服务提供商选择
              const Text(
                'AI Provider',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'openai',
                    label: Text('OpenAI'),
                    icon: Icon(Icons.cloud),
                  ),
                  ButtonSegment(
                    value: 'anthropic',
                    label: Text('Anthropic'),
                    icon: Icon(Icons.cloud),
                  ),
                ],
                selected: {_selectedProvider},
                onSelectionChanged: (Set<String> newSelection) {
                  setState(() {
                    _selectedProvider = newSelection.first;
                    // 根据提供商更新默认值
                    if (_selectedProvider == 'openai') {
                      _baseUrlController.text = 'https://api.openai.com/v1';
                      _modelController.text = 'gpt-4';
                    } else {
                      _baseUrlController.text = 'https://api.anthropic.com';
                      _modelController.text = 'claude-3-sonnet-20240229';
                    }
                  });
                },
              ),
              const SizedBox(height: 24),

              // Base URL
              const Text(
                'Base URL',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _baseUrlController,
                decoration: InputDecoration(
                  hintText: _selectedProvider == 'openai'
                      ? 'https://api.openai.com/v1'
                      : 'https://api.anthropic.com',
                  border: const OutlineInputBorder(),
                  iconColor: theme.ui.icon,
                ),
              ),
              const SizedBox(height: 16),

              // Model
              const Text(
                'Model Name',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _modelController,
                decoration: InputDecoration(
                  hintText: _selectedProvider == 'openai'
                      ? 'gpt-4'
                      : 'claude-3-sonnet-20240229',
                  border: const OutlineInputBorder(),
                  iconColor: theme.ui.icon,
                ),
              ),
              const SizedBox(height: 16),

              // API Key
              const Text(
                'API Key',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                obscureText: !_showApiKey,
                decoration: InputDecoration(
                  hintText: 'Enter your API key',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showApiKey ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        _showApiKey = !_showApiKey;
                      });
                    },
                  ),
                  iconColor: theme.ui.icon,
                ),
              ),
              const SizedBox(height: 16),

              // 信息提示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.status.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.status.info.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.status.info,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'API Configuration',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Get your API key from OpenAI or Anthropic',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• Custom base URLs are supported',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '• After configuration, use "Test AI Connection" to verify',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveConfiguration,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveConfiguration() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Key is required'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      await widget.settingsService.setAIProvider(_selectedProvider);
      await widget.settingsService.setAIBaseUrl(_baseUrlController.text);
      await widget.settingsService.setAIModel(_modelController.text);
      await widget.settingsService.setAIApiKey(_apiKeyController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI configuration saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving configuration: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}
