import 'package:appframe/ui/hooks/hook_bases.dart';
import 'package:appframe/ui/hooks/hook_contexts.dart';
import 'package:core/infrastructure/i18n.dart';
import 'package:flutter/material.dart';
import 'package:plugin/plugin.dart';
import 'package:provider/provider.dart';

/// AI 集成 Hook
///
/// 提供 AI 功能：节点分析、连接建议、图摘要等
class AIIntegrationHook extends MainToolbarHookRole {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'ai_integration',
    name: 'AI Integration',
    version: '1.0.0',
    description: 'AI-powered node analysis and connection suggestions',
  );

  @override
  HookPriority get priority => HookPriority.medium;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return const SizedBox.shrink();

    // 使用Consumer监听语言变化
    return Consumer<I18n>(
      builder: (ctx, i18n, child) => IconButton(
          icon: const Icon(Icons.psychology, color: Colors.purple),
          tooltip: i18n.t('AI Tools'),
          onPressed: () => _showAIMenu(context),
        ),
    );
  }

  /// 显示 AI 菜单
  void _showAIMenu(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;

    if (buildContext == null) {
      debugPrint('AIIntegrationHook: BuildContext not found');
      return;
    }

    final i18n = I18n.of(buildContext);

    showModalBottomSheet(
      context: buildContext,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.analytics),
              title: Text(i18n.t('Analyze selected nodes')),
              subtitle: Text(i18n.t('Use AI to analyze node content')),
              onTap: () {
                Navigator.pop(ctx);
                _showNotImplemented(buildContext, i18n.t('AI analysis feature'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.hub),
              title: Text(i18n.t('Suggest connections')),
              subtitle: Text(i18n.t('AI analysis and suggest node connections')),
              onTap: () {
                Navigator.pop(ctx);
                _showNotImplemented(buildContext, i18n.t('Connection suggestion feature'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize),
              title: Text(i18n.t('Generate graph summary')),
              subtitle: Text(i18n.t('AI generates summary of the graph')),
              onTap: () {
                Navigator.pop(ctx);
                _showNotImplemented(buildContext, i18n.t('Graph summary feature'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: Text(i18n.t('Generate node')),
              subtitle: Text(i18n.t('Use AI to generate new node content')),
              onTap: () {
                Navigator.pop(ctx);
                _showNotImplemented(buildContext, i18n.t('Node generation feature'));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 显示未实现提示
  void _showNotImplemented(BuildContext context, String feature) {
    final i18n = I18n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(i18n.t('This feature requires AI service configuration')),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
