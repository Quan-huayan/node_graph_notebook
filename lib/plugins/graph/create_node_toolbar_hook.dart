import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import '../../../core/services/i18n.dart';
import 'ui/create_node_dialog.dart';

/// 创建节点工具栏钩子
///
/// 注册到 graph.toolbar hook point，用于可拖动工具栏
class CreateNodeToolbarHook extends GraphToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'create_node_toolbar_hook',
    name: 'Create Node Toolbar Hook',
    version: '1.0.0',
    description: 'Provides create node button in graph toolbar',
  );

  @override
  HookPriority get priority => HookPriority.custom100;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return const SizedBox.shrink();

    // 使用Consumer监听语言变化
    return Consumer<I18n>(
      builder: (ctx, i18n, child) => IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _showCreateNodeDialog(context),
          tooltip: i18n.t('Create Node'),
        ),
    );
  }

  void _showCreateNodeDialog(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    showDialog(context: buildContext, builder: (ctx) => const CreateNodeDialog());
  }
}
