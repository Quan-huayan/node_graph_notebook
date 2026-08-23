/// openNodeDialog —— 打开节点 = 渲染其 Hook 的共用外壳（M7.2 D1 裁决：
/// 发起方负责外壳——本助手收敛四处重复实现：host_runtime 'node.open'、
/// note_row_view、search_panel、标签/最近面板）。
///
/// 附带最近打开语义（Phase C）：打开记录写 UIStateStore `recent.<ts>`
/// （判据②——Obsidian 最近文件同语义，重启保持）；容量裁剪（>20 删最旧）。
library;

import 'package:flutter/material.dart';

import '../host/host_runtime.dart';
import 'hook_view.dart';

/// 打开节点对话框（640x480——各处既有行为一致）。
Future<void> openNodeDialog(
  BuildContext context,
  HostRuntime host,
  String nodeId, {
  double width = 640,
  double height = 480,
}) async {
  _recordRecent(host, nodeId);
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                tooltip: host.i18nService.t('dialog.close'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Expanded(
              child: HookView(
                host: host,
                nodeId: nodeId,
                kind: 'open',
                recycleOnDispose: true,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 最近打开记录（UIStateStore `recent.<ts>`；容量 20，超量删最旧）。
///
/// `recent.*` 键是判据② 外观（跨会话保持，Obsidian 最近文件同语义）；
/// 清键随节点删除由 DeleteNodeHandler 级联（recent 前缀清理，Phase C）。
void _recordRecent(HostRuntime host, String nodeId) {
  final store = host.uiStateStore;
  const prefix = 'recent.';
  store.set('$prefix${DateTime.now().microsecondsSinceEpoch}', nodeId);
  final existing = store.getByPrefix(prefix).keys.toList()..sort();
  const cap = 20;
  final overflow = existing.length - cap;
  for (var i = 0; i < overflow; i++) {
    store.remove(existing[i]);
  }
}