/// 危险操作确认对话框（P1-5：侧边栏删除入口共用外壳与文案）。
///
/// node_editor / node_folder / node_graph 均依赖 appframe——删除确认
/// 的壳与文案（翻译表 node.deleteTitle/deleteConfirm）共享，禁止
/// 各插件手写副本（纪律 #6：文案必须走语言包）。
library;

import 'package:flutter/material.dart';

import '../i18n/i18n_service.dart';

/// 删除节点确认（返回 true = 用户确认）。
///
/// [title] 目标节点标题（插入确认文案占位符 %s）。
Future<bool> showDeleteNodeConfirm(
  BuildContext context, {
  required I18nService i18n,
  required String title,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(i18n.t('node.deleteTitle')),
      content: Text(i18n.t('node.deleteConfirm').replaceFirst('%s', title)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(i18n.t('dialog.cancel')),
        ),
        // 危险操作确认按钮用错误色（UX：破坏性动作必须与主操作视觉
        // 区分——防误触确认；取消按钮保持中性）。文案仍走语言包。
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(i18n.t('node.delete')),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
