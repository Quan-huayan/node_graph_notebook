/// NoteCardView —— 笔记卡片体（EditorHook kind='graph' 呈现，M7.1）。
///
/// 画布成员卡片 = 成员节点自己的 Hook 渲染（00"UI 是 Hook 构成的图"）：
/// 本视图只画内容（位置无关）——定位/拖拽/右键菜单等画布语义由画布
/// 宿主（node_graph NodeCard 壳）提供，插件互相不依赖（04 §三 约束 3）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

/// 笔记卡片体（标题 + 内容预览）。
class NoteCardView extends StatelessWidget {
  /// 注入笔记节点与国际化服务。
  const NoteCardView({super.key, required this.node, required this.i18n});

  /// 笔记节点。
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
            const Icon(Icons.description, size: 16),
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
            node.content?.trim().replaceAll(RegExp(r'\s+'), ' ') ??
                i18n.t('note.noContent'),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
