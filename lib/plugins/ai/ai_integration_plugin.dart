import 'package:flutter/material.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';

/// AI 集成 Hook
///
/// 提供 AI 功能：节点分析、连接建议、图摘要等
class AIIntegrationPlugin extends MainToolbarHookBase {
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
                _showNotImplemented(buildContext, '节点分析功能');
              },
            ),
            ListTile(
              leading: const Icon(Icons.hub),
              title: const Text('推荐连接'),
              subtitle: const Text('AI 分析并推荐节点连接'),
              onTap: () {
                Navigator.pop(ctx);
                _showNotImplemented(buildContext, '连接推荐功能');
              },
            ),
            ListTile(
              leading: const Icon(Icons.summarize),
              title: const Text('生成图摘要'),
              subtitle: const Text('AI 生成整张图的摘要'),
              onTap: () {
                Navigator.pop(ctx);
                _showNotImplemented(buildContext, '图摘要生成功能');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('生成节点'),
              subtitle: const Text('使用 AI 生成新节点内容'),
              onTap: () {
                Navigator.pop(ctx);
                _showNotImplemented(buildContext, '节点生成功能');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 显示未实现提示
  void _showNotImplemented(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature 功能需要配置 AI 服务后才能使用'),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
