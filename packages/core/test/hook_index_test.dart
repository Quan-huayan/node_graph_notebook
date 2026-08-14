/// HookIndex 契约测试 ×2（architecture.md §9）：物化 / 未物化广播。
///
/// 对应 02 §3.4 增量粒度第一层：失效路由 O(1)，通知按 nodeId 路由，
/// 未物化节点变更 = 无渲染成本。
library;

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('HookIndex（02 §3.4 nodeId → hookId）', () {
    test('物化：materialize 后 lookup 返回全部挂载的 hookId', () {
      final index = HookIndex();

      index.materialize('hook-1', 'node-a');
      index.materialize('hook-2', 'node-a'); // 同一 Node 多容器多 Hook
      index.materialize('hook-3', 'node-b');

      expect(index.lookup('node-a'), <String>{'hook-1', 'hook-2'});
      expect(index.lookup('node-b'), <String>{'hook-3'});
      expect(index.isMaterialized('node-a'), isTrue);
    });

    test('未物化广播：未物化 nodeId 返回空集不抛，无渲染成本', () {
      final index = HookIndex();

      index.materialize('hook-1', 'node-a');

      // 未物化节点（如 10⁶ 库中视口外的节点）lookup 为空。
      expect(index.lookup('far-away-node'), isEmpty);
      expect(index.isMaterialized('far-away-node'), isFalse);
      // onNodeChanged 保留路由契约（索引行无变更，不抛）。
      index.onNodeChanged('far-away-node');
    });

    test('recycle：回收后不再物化（窗口化，02 §3.3）', () {
      final index = HookIndex();

      index.materialize('hook-1', 'node-a');
      index.recycle('hook-1');

      expect(index.lookup('node-a'), isEmpty);
      expect(index.isMaterialized('node-a'), isFalse);
    });

    test('repoint：重指向到新 nodeId（降级渲染，architecture.md §5.4）', () {
      final index = HookIndex();

      index.materialize('hook-1', 'node-a');
      index.repoint('hook-1', 'node-a', 'node-b');

      expect(index.lookup('node-a'), isEmpty);
      expect(index.lookup('node-b'), <String>{'hook-1'});
    });
  });
}
