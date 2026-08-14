/// AICardView —— AI 节点卡片体（AIHook kind='graph' 呈现，M7.1）。
///
/// 画布上的 AI 节点 = 会话入口卡片（点击 = 渲染其 'open' Hook =
/// 对话视图，"拖进 AI 节点 → 变对话"的画布形态）。只画内容
/// （位置无关）——画布语义（定位/拖拽/菜单）由画布宿主提供。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

/// AI 节点卡片体（标题 + 对话入口提示）。
class AICardView extends StatelessWidget {
  /// 注入 AI 节点与国际化服务。
  const AICardView({super.key, required this.node, required this.i18n});

  /// AI 节点（kind == 'ai'）。
  final Node node;

  /// 国际化服务（壳层文案）。
  final I18nService i18n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.smart_toy, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                node.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Text(
            i18n.t('ai.chat'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}
