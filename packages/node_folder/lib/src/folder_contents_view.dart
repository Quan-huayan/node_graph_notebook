/// FolderContentsView —— 文件夹打开呈现（M7.2，D1 弹框归属落地）。
///
/// 打开文件夹 = 渲染其 Hook（02 §1.2 形态由 kind 决定）：'open' 形态 =
/// **子级列表**（容器打开呈现的完整性 = 各 Concept 自己的责任，02 §3.2b
/// 回填）——子级 = HookView 递归（02 §3.2：父 Hook 驱动子 Hook，
/// 不代替子渲染；笔记行 = NoteRowView 侧栏形态，子文件夹 = 平铺）。
/// 外壳（对话框/关闭）由发起方提供（画布 = CanvasConcept 责任）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import 'contain_concept.dart';

/// 文件夹内容列表（'open' 形态）。
class FolderContentsView extends StatelessWidget {
  /// 注入宿主与文件夹节点。
  const FolderContentsView({super.key, required this.host, required this.node});

  /// 宿主组合根。
  final HostRuntime host;

  /// 文件夹节点（kind == 'folder'）。
  final Node node;

  @override
  Widget build(BuildContext context) {
    // 子级 = 容器语义推导（00 推论 3：contain 读侧反查）。
    final childIds = childrenOf(host.graph, node.id).toList();
    if (childIds.isEmpty) {
      return Center(child: Text(host.i18nService.t('folder.empty')));
    }
    return ListView(
      children: <Widget>[
        for (final childId in childIds)
          HookView(host: host, nodeId: childId, kind: 'sidebar'),
      ],
    );
  }
}
