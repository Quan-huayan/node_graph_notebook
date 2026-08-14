/// SettingsEntriesView —— 设置容器打开呈现（M7.2 阶段 C 修正：
/// 用户裁决——**条目表单 inline 铺开，零嵌套弹框**）。
///
/// 打开设置 = 一个可滚动视图：每个条目 = 子 Hook 的 **open 形态**
/// 直接内联渲染（02 §3.2：父 Hook 驱动子 Hook，不代替子渲染——
/// 主题选择器 / AI key 输入 / 语言选择都在同一页）。外壳（对话框/
/// 关闭）由发起方（settings 插件）提供一次，无二层弹框。
/// M7.2（F 样式）：条目分组卡片（Card + 间距，设置页可读性）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import 'settings_container.dart';

/// 设置条目表单列表（设置容器 'open' 形态）。
class SettingsEntriesView extends StatelessWidget {
  /// 注入宿主与设置容器节点。
  const SettingsEntriesView({
    super.key,
    required this.host,
    required this.node,
  });

  /// 宿主组合根。
  final HostRuntime host;

  /// 设置容器节点（kind == 'settings-root'）。
  final Node node;

  @override
  Widget build(BuildContext context) {
    final childIds =
        const SettingsContainerConcept().childNodeIdsOf(node, host.graph) ??
        const <String>[];
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      children: <Widget>[
        for (final childId in childIds)
          // 分组卡片：每个设置条目 = 独立卡片（M7.2 F 样式）。
          Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: HookView(host: host, nodeId: childId, kind: 'open'),
          ),
      ],
    );
  }
}
