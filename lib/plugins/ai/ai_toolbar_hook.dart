import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import '../../../core/services/i18n.dart';

/// AI助手工具栏钩子
class AIToolbarHook extends MainToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'ai_toolbar_hook',
    name: 'AI Toolbar Hook',
    version: '1.0.0',
    description: 'Provides AI assistant button in toolbar',
  );

  @override
  HookPriority get priority => HookPriority.custom70; // 主工具栏右三位置

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return const SizedBox.shrink();

    // 使用Consumer监听语言变化
    return Consumer<I18n>(
      builder: (ctx, i18n, child) => IconButton(
          icon: const Icon(Icons.smart_toy),
          onPressed: () => _addAIAssistant(context),
          tooltip: i18n.t('AI Assistant'),
        ),
    );
  }

  void _addAIAssistant(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    final i18n = I18n.of(buildContext);

    try {
      // 通过命令总线执行创建AI助手节点的命令
      // 这里需要在AI插件中实现相应的命令和处理器
      ScaffoldMessenger.of(buildContext).showSnackBar(
        SnackBar(
          content: Text(i18n.t('AI Assistant functionality coming soon!')),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        buildContext,
      ).showSnackBar(SnackBar(content: Text('${i18n.t('Failed to add AI Assistant:')}: $e')));
    }
  }
}
