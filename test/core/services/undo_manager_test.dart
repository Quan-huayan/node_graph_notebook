import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/services/undo_manager.dart';
import 'package:node_graph_notebook/core/services/commands/command.dart';

// Mock Command for testing
class TestCommand extends Command {
  TestCommand({
    required this.description,
    this.executeCount = 0,
    this.undoCount = 0,
  });

  @override
  final String description;

  final int executeCount;
  final int undoCount;

  var actualExecuteCount = 0;
  var actualUndoCount = 0;

  @override
  Future<void> execute() async {
    actualExecuteCount++;
  }

  @override
  Future<void> undo() async {
    actualUndoCount++;
  }

  void resetCounts() {
    actualExecuteCount = 0;
    actualUndoCount = 0;
  }
}

void main() {
  group('UndoManager', () {
    late UndoManager undoManager;

    setUp(() {
      undoManager = UndoManager();
    });

    group('Initial State', () {
      test('should start with empty undo stack', () {
        expect(undoManager.canUndo, false);
      });

      test('should start with empty redo stack', () {
        expect(undoManager.canRedo, false);
      });
    });

    group('execute', () {
      test('should execute command and add to undo stack', () async {
        final command = TestCommand(description: 'Test Command');

        await undoManager.execute(command);

        expect(undoManager.canUndo, true);
        expect(undoManager.canRedo, false);
        expect(command.actualExecuteCount, 1);
      });

      test('should clear redo stack when executing new command', () async {
        final command1 = TestCommand(description: 'Command 1');
        final command2 = TestCommand(description: 'Command 2');

        await undoManager.execute(command1);
        await undoManager.undo(); // Move to redo stack
        expect(undoManager.canRedo, true);

        await undoManager.execute(command2); // Should clear redo stack

        expect(undoManager.canRedo, false);
        expect(undoManager.canUndo, true);
      });

      test('should notify listeners after execute', () async {
        var notified = false;
        undoManager.addListener(() {
          notified = true;
        });

        final command = TestCommand(description: 'Test Command');
        await undoManager.execute(command);

        expect(notified, true);
      });

      test('should limit undo stack size to 50', () async {
        // Create 51 commands
        final commands = List.generate(
          51,
          (i) => TestCommand(description: 'Command $i'),
        );

        for (final command in commands) {
          await undoManager.execute(command);
        }

        // After executing 51 commands, only the last 50 should be in the stack
        expect(undoManager.canUndo, true);

        // Undo all - should only have 50 to undo
        var undoCount = 0;
        while (undoManager.canUndo) {
          await undoManager.undo();
          undoCount++;
        }

        expect(undoCount, 50);
      });

      test('should remove oldest command when stack exceeds limit', () async {
        // Fill the stack to capacity
        for (var i = 0; i < 50; i++) {
          final command = TestCommand(description: 'Command $i');
          await undoManager.execute(command);
        }

        // Add one more
        final command51 = TestCommand(description: 'Command 51');
        await undoManager.execute(command51);

        // First command should be removed
        var undoCount = 0;
        while (undoManager.canUndo) {
          await undoManager.undo();
          undoCount++;
        }

        expect(undoCount, 50); // Still 50, not 51
      });
    });

    group('undo', () {
      test('should undo last command', () async {
        final command = TestCommand(description: 'Test Command');

        await undoManager.execute(command);
        expect(command.actualExecuteCount, 1);
        expect(command.actualUndoCount, 0);

        await undoManager.undo();

        expect(command.actualExecuteCount, 1);
        expect(command.actualUndoCount, 1);
        expect(undoManager.canUndo, false);
        expect(undoManager.canRedo, true);
      });

      test('should move command from undo stack to redo stack', () async {
        final command1 = TestCommand(description: 'Command 1');
        final command2 = TestCommand(description: 'Command 2');

        await undoManager.execute(command1);
        await undoManager.execute(command2);

        expect(undoManager.canUndo, true);

        await undoManager.undo();

        expect(undoManager.canUndo, true); // Still can undo command1
        expect(undoManager.canRedo, true);
      });

      test('should do nothing when undo stack is empty', () async {
        final command = TestCommand(description: 'Test Command');

        await undoManager.execute(command);
        await undoManager.undo();

        expect(undoManager.canUndo, false);

        // Should not throw
        await undoManager.undo();

        expect(command.actualUndoCount, 1); // Still 1, not 2
      });

      test('should notify listeners after undo', () async {
        final command = TestCommand(description: 'Test Command');
        await undoManager.execute(command);

        var notified = false;
        undoManager.addListener(() {
          notified = true;
        });

        await undoManager.undo();

        expect(notified, true);
      });

      test('should undo multiple commands in LIFO order', () async {
        final command1 = TestCommand(description: 'Command 1');
        final command2 = TestCommand(description: 'Command 2');
        final command3 = TestCommand(description: 'Command 3');

        await undoManager.execute(command1);
        await undoManager.execute(command2);
        await undoManager.execute(command3);

        await undoManager.undo();
        expect(command3.actualUndoCount, 1);
        expect(command2.actualUndoCount, 0);

        await undoManager.undo();
        expect(command2.actualUndoCount, 1);
        expect(command1.actualUndoCount, 0);

        await undoManager.undo();
        expect(command1.actualUndoCount, 1);
      });
    });

    group('redo', () {
      test('should redo last undone command', () async {
        final command = TestCommand(description: 'Test Command');

        await undoManager.execute(command);
        await undoManager.undo();

        expect(command.actualExecuteCount, 1);
        expect(command.actualUndoCount, 1);

        await undoManager.redo();

        expect(command.actualExecuteCount, 2);
        expect(command.actualUndoCount, 1);
        expect(undoManager.canRedo, false);
        expect(undoManager.canUndo, true);
      });

      test('should move command from redo stack back to undo stack', () async {
        final command1 = TestCommand(description: 'Command 1');
        final command2 = TestCommand(description: 'Command 2');

        await undoManager.execute(command1);
        await undoManager.execute(command2);
        await undoManager.undo();

        expect(undoManager.canRedo, true);

        await undoManager.redo();

        expect(undoManager.canRedo, false);
        expect(undoManager.canUndo, true);
      });

      test('should do nothing when redo stack is empty', () async {
        final command = TestCommand(description: 'Test Command');

        await undoManager.execute(command);

        expect(undoManager.canRedo, false);

        // Should not throw
        await undoManager.redo();

        expect(command.actualExecuteCount, 1); // Still 1, not 2
      });

      test('should notify listeners after redo', () async {
        final command = TestCommand(description: 'Test Command');
        await undoManager.execute(command);
        await undoManager.undo();

        var notified = false;
        undoManager.addListener(() {
          notified = true;
        });

        await undoManager.redo();

        expect(notified, true);
      });

      test('should redo multiple commands in FIFO order', () async {
        final command1 = TestCommand(description: 'Command 1');
        final command2 = TestCommand(description: 'Command 2');
        final command3 = TestCommand(description: 'Command 3');

        await undoManager.execute(command1);
        await undoManager.execute(command2);
        await undoManager.execute(command3);

        // Undo all
        await undoManager.undo();
        await undoManager.undo();
        await undoManager.undo();

        // Redo all
        await undoManager.redo();
        expect(command1.actualExecuteCount, 2);

        await undoManager.redo();
        expect(command2.actualExecuteCount, 2);

        await undoManager.redo();
        expect(command3.actualExecuteCount, 2);
      });

      test('should clear redo stack when executing new command after undo', () async {
        final command1 = TestCommand(description: 'Command 1');
        final command2 = TestCommand(description: 'Command 2');

        await undoManager.execute(command1);
        await undoManager.execute(command2);
        await undoManager.undo();

        expect(undoManager.canRedo, true);

        final command3 = TestCommand(description: 'Command 3');
        await undoManager.execute(command3);

        expect(undoManager.canRedo, false);
      });
    });

    group('clear', () {
      test('should clear both undo and redo stacks', () async {
        final command1 = TestCommand(description: 'Command 1');
        final command2 = TestCommand(description: 'Command 2');

        await undoManager.execute(command1);
        await undoManager.execute(command2);
        await undoManager.undo();

        expect(undoManager.canUndo, true);
        expect(undoManager.canRedo, true);

        undoManager.clear();

        expect(undoManager.canUndo, false);
        expect(undoManager.canRedo, false);
      });

      test('should notify listeners after clear', () async {
        final command = TestCommand(description: 'Test Command');
        await undoManager.execute(command);

        var notified = false;
        undoManager.addListener(() {
          notified = true;
        });

        undoManager.clear();

        expect(notified, true);
      });

      test('should allow new commands after clear', () async {
        final command1 = TestCommand(description: 'Command 1');
        await undoManager.execute(command1);

        undoManager.clear();

        final command2 = TestCommand(description: 'Command 2');
        await undoManager.execute(command2);

        expect(undoManager.canUndo, true);
        expect(undoManager.canRedo, false);
      });
    });

    group('Complex Scenarios', () {
      test('should handle execute-undo-redo sequence correctly', () async {
        final command = TestCommand(description: 'Test Command');

        await undoManager.execute(command);
        expect(command.actualExecuteCount, 1);
        expect(command.actualUndoCount, 0);

        await undoManager.undo();
        expect(command.actualExecuteCount, 1);
        expect(command.actualUndoCount, 1);

        await undoManager.redo();
        expect(command.actualExecuteCount, 2);
        expect(command.actualUndoCount, 1);

        await undoManager.undo();
        expect(command.actualExecuteCount, 2);
        expect(command.actualUndoCount, 2);

        await undoManager.redo();
        expect(command.actualExecuteCount, 3);
        expect(command.actualUndoCount, 2);
      });

      test('should handle multiple undo-redo cycles', () async {
        final command1 = TestCommand(description: 'Command 1');
        final command2 = TestCommand(description: 'Command 2');

        await undoManager.execute(command1);
        await undoManager.execute(command2);

        // First undo-redo cycle
        await undoManager.undo();
        expect(command2.actualExecuteCount, 1);
        expect(command2.actualUndoCount, 1);

        await undoManager.redo();
        expect(command2.actualExecuteCount, 2);
        expect(command2.actualUndoCount, 1);

        // Second undo-redo cycle
        await undoManager.undo();
        expect(command2.actualExecuteCount, 2);
        expect(command2.actualUndoCount, 2);

        await undoManager.redo();
        expect(command2.actualExecuteCount, 3);
        expect(command2.actualUndoCount, 2);
      });

      test('should handle interleaved commands and undo operations', () async {
        final command1 = TestCommand(description: 'Command 1');
        final command2 = TestCommand(description: 'Command 2');
        final command3 = TestCommand(description: 'Command 3');

        await undoManager.execute(command1);
        await undoManager.execute(command2);
        await undoManager.undo(); // Undo command2
        await undoManager.execute(command3); // Should clear redo stack

        expect(undoManager.canRedo, false);
        expect(undoManager.canUndo, true);

        // Can undo command3 and command1, but not command2
        await undoManager.undo();
        await undoManager.undo();

        expect(undoManager.canUndo, false);
      });
    });

    group('Edge Cases', () {
      test('should handle rapid successive executes', () async {
        final commands = List.generate(
          10,
          (i) => TestCommand(description: 'Command $i'),
        );

        for (final command in commands) {
          await undoManager.execute(command);
        }

        expect(undoManager.canUndo, true);

        var count = 0;
        while (undoManager.canUndo) {
          await undoManager.undo();
          count++;
        }

        expect(count, 10);
      });

      test('should handle rapid successive undos', () async {
        for (var i = 0; i < 10; i++) {
          final command = TestCommand(description: 'Command $i');
          await undoManager.execute(command);
        }

        for (var i = 0; i < 10; i++) {
          await undoManager.undo();
        }

        expect(undoManager.canUndo, false);
        expect(undoManager.canRedo, true);
      });

      test('should handle rapid successive redos', () async {
        for (var i = 0; i < 10; i++) {
          final command = TestCommand(description: 'Command $i');
          await undoManager.execute(command);
        }

        for (var i = 0; i < 10; i++) {
          await undoManager.undo();
        }

        for (var i = 0; i < 10; i++) {
          await undoManager.redo();
        }

        expect(undoManager.canRedo, false);
        expect(undoManager.canUndo, true);
      });
    });
  });
}
