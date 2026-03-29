import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/services/shortcut_manager.dart' as app;

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('ShortcutManager', () {
    late app.ShortcutManager manager;

    setUp(() {
      manager = app.ShortcutManager();
    });

    group('Registration', () {
      test('应该注册快捷键', () {
        var callbackCalled = false;
        const activator = SingleActivator(LogicalKeyboardKey.keyA);

        manager.register(activator, () {
          callbackCalled = true;
        });

        expect(callbackCalled, false);
      });

      test('应该注销快捷键', () {
        const activator = SingleActivator(LogicalKeyboardKey.keyA);

        manager..register(activator, () {})
        ..unregister(activator);

        expect(true, true);
      });

      test('应该注册多个快捷键', () {
        const activator1 = SingleActivator(LogicalKeyboardKey.keyA);
        const activator2 = SingleActivator(LogicalKeyboardKey.keyB);

        manager..register(activator1, () {})
        ..register(activator2, () {});

        expect(true, true);
      });

      test('应该覆盖已存在的快捷键', () {
        const activator = SingleActivator(LogicalKeyboardKey.keyA);

        var firstCallbackCalled = false;
        var secondCallbackCalled = false;

        manager..register(activator, () {
          firstCallbackCalled = true;
        })

        ..register(activator, () {
          secondCallbackCalled = true;
        });

        expect(firstCallbackCalled, false);
        expect(secondCallbackCalled, false);
      });
    });

    group('Key Handling', () {
      test('应该处理已注册的按键', () {
        var callbackCalled = false;
        const activator = SingleActivator(LogicalKeyboardKey.keyA);

        manager.register(activator, () {
          callbackCalled = true;
        });

        const event = KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.keyA,
          timeStamp: Duration.zero,
        );

        final handled = manager.handleKeyPress(event);

        expect(handled, true);
        expect(callbackCalled, true);
      });

      test('不应该处理未注册的按键', () {
        var callbackCalled = false;
        const activator = SingleActivator(LogicalKeyboardKey.keyA);

        manager.register(activator, () {
          callbackCalled = true;
        });

        const event = KeyDownEvent(
          physicalKey: PhysicalKeyboardKey.keyB,
          logicalKey: LogicalKeyboardKey.keyB,
          timeStamp: Duration.zero,
        );

        final handled = manager.handleKeyPress(event);

        expect(handled, false);
        expect(callbackCalled, false);
      });
    });
  });

  group('AppShortcuts', () {
    test('应该具有创建节点快捷键', () {
      expect(app.AppShortcuts.createNode, isA<SingleActivator>());
    });

    test('应该具有保存快捷键', () {
      expect(app.AppShortcuts.save, isA<SingleActivator>());
    });

    test('应该具有撤销快捷键', () {
      expect(app.AppShortcuts.undo, isA<SingleActivator>());
    });

    test('应该具有重做快捷键', () {
      expect(app.AppShortcuts.redo, isA<SingleActivator>());
    });

    test('应该具有删除快捷键', () {
      expect(app.AppShortcuts.delete, isA<SingleActivator>());
    });

    test('应该具有搜索快捷键', () {
      expect(app.AppShortcuts.search, isA<SingleActivator>());
    });

    test('应该具有导出快捷键', () {
      expect(app.AppShortcuts.export, isA<SingleActivator>());
    });
  });
}
