/// FSUIStateStore 行为测试（02 §2.3：KV 文件 / 原子写 / 惰性加载 /
/// 键带容器上下文）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

void main() {
  group('FSUIStateStore（02 §2.3）', () {
    late Directory root;
    late FSUIStateStore store;

    setUp(() {
      root = createTempDir('ui_state');
      store = FSUIStateStore(dataRoot: root);
    });

    test('set/get/remove 基本 KV；get 不存在返回 null', () {
      expect(store.get('position.graph.hook1'), isNull);

      store.set('position.graph.hook1', <String, dynamic>{'x': 10, 'y': 20});
      expect(
        (store.get('position.graph.hook1') as Map<String, dynamic>)['x'],
        10,
      );

      store.remove('position.graph.hook1');
      expect(store.get('position.graph.hook1'), isNull);
    });

    test('键带容器上下文（修掉 position.<nodeId> 碰撞）', () {
      store.set('position.graph.nodeA', <String, dynamic>{'x': 1});
      store.set('position.sidebar.nodeA', <String, dynamic>{'x': 2});

      expect(
        (store.get('position.graph.nodeA') as Map<String, dynamic>)['x'],
        1,
      );
      expect(
        (store.get('position.sidebar.nodeA') as Map<String, dynamic>)['x'],
        2,
      );
    });

    test('getByPrefix 前缀读取（孤儿 GC 触达面）', () {
      store
        ..set('expand.sidebar.f1', true)
        ..set('expand.sidebar.f2', false)
        ..set('camera.main.root', <String, dynamic>{'z': 1});

      final expand = store.getByPrefix('expand.sidebar.');
      expect(expand.keys, <String>{'expand.sidebar.f1', 'expand.sidebar.f2'});
    });

    test('持久化：新实例从 ui-state.json 读回（重启恢复 §5.5）', () {
      store.set('position.graph.hook1', <String, dynamic>{'x': 42});

      final reopened = FSUIStateStore(dataRoot: root);

      expect(
        (reopened.get('position.graph.hook1') as Map<String, dynamic>)['x'],
        42,
      );
      expect(reopened.getByPrefix('position.graph.').keys, <String>{
        'position.graph.hook1',
      });
    });

    test('原子写：无 .tmp 残留', () {
      store.set('selection.main.hook1', true);

      final leftovers = root.listSync().where((e) => e.path.endsWith('.tmp'));
      expect(leftovers, isEmpty);
    });
  });
}
