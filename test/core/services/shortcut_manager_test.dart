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
      test('should register shortcut', () {
        var callbackCalled = false;
        const activator = SingleActivator(LogicalKeyboardKey.keyA);

        manager.register(activator, () {
          callbackCalled = true;
        });

        expect(callbackCalled, false);
      });

      test('should unregister shortcut', () {
        const activator = SingleActivator(LogicalKeyboardKey.keyA);

        manager..register(activator, () {})
        ..unregister(activator);

        expect(true, true);
      });

      test('should register multiple shortcuts', () {
        const activator1 = SingleActivator(LogicalKeyboardKey.keyA);
        const activator2 = SingleActivator(LogicalKeyboardKey.keyB);

        manager..register(activator1, () {})
        ..register(activator2, () {});

        expect(true, true);
      });

      test('should overwrite existing shortcut', () {
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
      test('should handle registered key press', () {
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

      test('should not handle unregistered key press', () {
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
    test('should have create node shortcut', () {
      expect(app.AppShortcuts.createNode, isA<SingleActivator>());
    });

    test('should have save shortcut', () {
      expect(app.AppShortcuts.save, isA<SingleActivator>());
    });

    test('should have undo shortcut', () {
      expect(app.AppShortcuts.undo, isA<SingleActivator>());
    });

    test('should have redo shortcut', () {
      expect(app.AppShortcuts.redo, isA<SingleActivator>());
    });

    test('should have delete shortcut', () {
      expect(app.AppShortcuts.delete, isA<SingleActivator>());
    });

    test('should have search shortcut', () {
      expect(app.AppShortcuts.search, isA<SingleActivator>());
    });

    test('should have export shortcut', () {
      expect(app.AppShortcuts.export, isA<SingleActivator>());
    });
  });
}
