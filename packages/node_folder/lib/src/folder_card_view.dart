/// FolderCardView —— 文件夹卡片体（FolderHook kind='graph' 呈现，M7.1）。
///
/// 画布上的文件夹节点 = 容器入口卡片（点击 = 渲染其 'open' Hook）。
/// 只画内容（位置无关）——画布语义（定位/拖拽/菜单）由画布宿主提供。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

/// 文件夹卡片体（标题 + 容器提示）。
class FolderCardView extends StatelessWidget {
  /// 注入文件夹节点与国际化服务。
  const FolderCardView({super.key, required this.node, required this.i18n});

  /// 文件夹节点（kind == 'folder'）。
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
            const Icon(Icons.folder, size: 16),
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
            i18n.t('node.type.folder'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
      ],
    );
  }
}
