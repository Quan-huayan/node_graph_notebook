import 'package:appframe/ui/hooks/hook_bases.dart';
import 'package:appframe/ui/hooks/hook_contexts.dart';
import 'package:core/infrastructure/i18n.dart';
import 'package:flutter/material.dart';
import 'package:plugin/plugin.dart';
import 'package:provider/provider.dart';

import 'ui/import_export_page.dart';

/// 导入导出工具栏钩子
class ConverterToolbarHook extends MainToolbarHookRole {
  @override
  HookMetadata get metadata => const HookMetadata(
    id: 'converter_toolbar_hook',
    name: 'Converter Toolbar Hook',
    version: '1.0.0',
    description: 'Provides import/export button in toolbar',
  );

  @override
  HookPriority get priority => HookPriority.custom80; // 主工具栏右四位置

  @override
  Widget renderToolbar(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return const SizedBox.shrink();

    // 使用Consumer监听语言变化
    return Consumer<I18n>(
      builder: (ctx, i18n, child) => IconButton(
          icon: const Icon(Icons.import_export),
          onPressed: () => _openImportExportPage(context),
          tooltip: i18n.t('Import & Export'),
        ),
    );
  }

  void _openImportExportPage(MainToolbarHookContext context) {
    final buildContext = context.data['buildContext'] as BuildContext?;
    if (buildContext == null) return;

    Navigator.push(
      buildContext,
      MaterialPageRoute(builder: (ctx) => const ImportExportPage()),
    );
  }
}
