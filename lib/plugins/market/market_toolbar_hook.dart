import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/plugin/ui_hooks/hook_base.dart';
import '../../../core/plugin/ui_hooks/hook_context.dart';
import '../../../core/plugin/ui_hooks/hook_metadata.dart';
import '../../../core/plugin/ui_hooks/hook_priority.dart';
import '../../../core/services/i18n.dart';
import '../../../ui/pages/plugin_market_page.dart';

/// 插件市场工具栏钩子
class MarketToolbarHook extends MainToolbarHookBase {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'market_toolbar_hook',
    name: 'Market Toolbar Hook',
    version: '1.0.0',
    description: 'Provides plugin market button in toolbar',
  );

  @override
  HookPriority get priority => HookPriority.custom600;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return const SizedBox.shrink();

    // 使用Consumer监听语言变化
    return Consumer<I18n>(
      builder: (ctx, i18n, child) => IconButton(
          icon: const Icon(Icons.extension),
          onPressed: () => _openPluginMarket(context),
          tooltip: i18n.t('Plugin Market'),
        ),
    );
  }

  void _openPluginMarket(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    Navigator.push(
      buildContext,
      MaterialPageRoute(builder: (ctx) => const PluginMarketPage()),
    );
  }
}
