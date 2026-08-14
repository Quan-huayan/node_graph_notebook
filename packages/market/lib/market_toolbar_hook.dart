import 'package:appframe/ui/hooks/hook_bases.dart';
import 'package:appframe/ui/hooks/hook_contexts.dart';
import 'package:core/infrastructure/i18n.dart';
import 'package:flutter/material.dart';
import 'package:plugin/plugin.dart';
import 'package:provider/provider.dart';

import 'ui/pages/plugin_market_page.dart';

/// 插件市场工具栏钩子
class MarketToolbarHook extends MainToolbarHookRole {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'market_toolbar_hook',
    name: 'Market Toolbar Hook',
    version: '1.0.0',
    description: 'Provides plugin market button in toolbar',
  );

  @override
  HookPriority get priority => HookPriority.custom60;

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return const SizedBox.shrink();

    final i18n = _tryGetI18n(buildContext);

    if (i18n != null) {
      return Consumer<I18n>(
        builder: (_, i18n, _) => IconButton(
          icon: const Icon(Icons.extension),
          onPressed: () => _openPluginMarket(buildContext),
          tooltip: i18n.t('Plugin Market'),
        ),
      );
    }

    return IconButton(
      icon: const Icon(Icons.extension),
      onPressed: () => _openPluginMarket(buildContext),
      tooltip: 'Plugin Market',
    );
  }

  I18n? _tryGetI18n(BuildContext context) {
    try {
      return context.read<I18n?>();
    } catch (_) {
      return null;
    }
  }

  void _openPluginMarket(BuildContext buildContext) {
    Navigator.push(
      buildContext,
      MaterialPageRoute(builder: (_) => const PluginMarketPage()),
    );
  }
}
