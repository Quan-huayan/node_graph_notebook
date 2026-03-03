import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// 撤销/重做管理器
class UndoManager extends ChangeNotifier {
  UndoManager();

  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];
  static const int _maxStackSize = 50;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  /// 执行命令
  Future<void> execute(Command command) async {
    await command.execute();
    _undoStack.add(command);
    _redoStack.clear();

    // 限制栈大小
    if (_undoStack.length > _maxStackSize) {
      _undoStack.removeAt(0);
    }

    notifyListeners();
  }

  /// 撤销
  Future<void> undo() async {
    if (!canUndo) return;

    final command = _undoStack.removeLast();
    await command.undo();
    _redoStack.add(command);

    notifyListeners();
  }

  /// 重做
  Future<void> redo() async {
    if (!canRedo) return;

    final command = _redoStack.removeLast();
    await command.execute();
    _undoStack.add(command);

    notifyListeners();
  }

  /// 清空历史
  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    notifyListeners();
  }
}

/// 命令接口
abstract class Command {
  Future<void> execute();
  Future<void> undo();

  String get description;
}

/// 创建节点命令
class CreateNodeCommand implements Command {
  CreateNodeCommand({
    required this.onCreate,
    required this.onDelete,
  });

  final Function(Node) onCreate;
  final Function(String) onDelete;
  late Node _node;

  @override
  Future<void> execute() async {
    _node = await onCreate(_node);
  }

  @override
  Future<void> undo() async {
    onDelete(_node.id);
  }

  @override
  String get description => 'Create Node';
}

/// 更新节点命令
class UpdateNodeCommand implements Command {
  UpdateNodeCommand({
    required this.oldNode,
    required this.newNode,
    required this.onUpdate,
  });

  final Node oldNode;
  final Node newNode;
  final Function(Node) onUpdate;

  @override
  Future<void> execute() async {
    await onUpdate(newNode);
  }

  @override
  Future<void> undo() async {
    await onUpdate(oldNode);
  }

  @override
  String get description => 'Update Node';
}

/// 删除节点命令
class DeleteNodeCommand implements Command {
  DeleteNodeCommand({
    required this.onDelete,
    required this.onRestore,
  });

  final Function(String) onDelete;
  final Function(Node) onRestore;
  late Node _deletedNode;

  @override
  Future<void> execute() async {
    _deletedNode = await onDelete(_deletedNode.id);
  }

  @override
  Future<void> undo() async {
    await onRestore(_deletedNode);
  }

  @override
  String get description => 'Delete Node';
}

/// 连接节点命令
class ConnectNodesCommand implements Command {
  ConnectNodesCommand({
    required this.onConnect,
    required this.onDisconnect,
  });

  final Function() onConnect;
  final Function() onDisconnect;

  @override
  Future<void> execute() async {
    await onConnect();
  }

  @override
  Future<void> undo() async {
    await onDisconnect();
  }

  @override
  String get description => 'Connect Nodes';
}
