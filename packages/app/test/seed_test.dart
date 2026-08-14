/// 种子升级测试（M7 修正——旧数据升级）：
///
/// 1. 空库 → 全量播种（root/folderA/canvas/aiNode/工具栏按钮/notes）
/// 2. 已有旧数据（root 存在、无 canvas/aiNode/toolbar）→ **基础设施补齐**
///    （画布/AI/工具栏按钮——缺失即功能缺失），**示例内容不复活**
///    （用户删除的 folderA 不补回）
/// 3. 幂等：重复播种不重复创建
library;

import 'dart:io';

import 'package:app/main.dart' as app;
import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late HostRuntime host;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ngn_seed');
    addTearDown(() {
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    host = HostRuntime(dataRoot: root);
  });

  test('空库 → 全量播种（示例 + 基础设施）', () {
    app.seedIfEmpty(host);
    expect(host.graph.get('root'), isNotNull);
    expect(host.graph.get('folderA'), isNotNull);
    expect(host.graph.get('canvas'), isNotNull);
    expect(host.graph.get('aiNode'), isNotNull);
    expect(host.graph.get('toolbar-canvas'), isNotNull);
    expect(host.graph.get('toolbar-settings'), isNotNull);
    expect(host.graph.get('toolbar-market'), isNotNull);
    expect(host.graph.get('contain-root-folderA'), isNotNull);
    // 位置键（判据②）。
    expect(host.uiStateStore.get(canvasPositionKey('noteB')), isNotNull);
  });

  test('旧数据升级：基础设施补齐，示例内容不复活', () {
    // 模拟旧数据：只有 root（无 canvas/aiNode/toolbar/folderA——
    // folderA 被用户删除）。
    final now = DateTime.now();
    host.graph.save(
      StoredNode(
        id: 'root',
        title: '根目录',
        metadata: const <String, dynamic>{'kind': 'folder'},
        createdAt: now,
        updatedAt: now,
      ),
    );
    app.seedIfEmpty(host);
    // 基础设施补齐（功能依赖）。
    expect(host.graph.get('canvas'), isNotNull);
    expect(host.graph.get('aiNode'), isNotNull);
    expect(host.graph.get('toolbar-canvas'), isNotNull);
    expect(host.graph.get('toolbar-settings'), isNotNull);
    expect(host.graph.get('toolbar-market'), isNotNull);
    // 示例内容不复活（用户删除的内容）。
    expect(host.graph.get('folderA'), isNull);
    expect(host.graph.get('noteB'), isNull);
  });

  test('幂等：重复播种不重复创建', () {
    app.seedIfEmpty(host);
    final countBefore = host.graph.getAll().length;
    app.seedIfEmpty(host);
    expect(host.graph.getAll().length, countBefore);
  });
}
