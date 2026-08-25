/// PluginCommandBus —— 从 plugon 扩展点路由的命令总线（04 §1.1）。
///
/// Handler 注册归 plugon（`commandHandlerPoint` 贡献，owner 清理自动）；
/// 本实现只做路由与写后通知。dispatch 优先查直接注册表（宿主级
/// handler），未命中查扩展点活跃贡献（按 commandType）。
///
/// 失败行为（架构 §3）：无任何匹配 → StateError（配置错误快速失败）；
/// Handler 内环校验失败 → CycleError。
library;

import 'package:plugon/plugon.dart';

import '../registry/extension_points.dart';
import 'command.dart';
import 'command_bus.dart';
import 'undo_manager.dart';

/// 从扩展点路由的命令总线实现（**生产装配用**，HostRuntime 接线；
/// 与 command_bus.dart 的 CommandBusImpl 关系见其文档注释，audit-core #10）。
class PluginCommandBus implements CommandBus, WriteNotifier {
  /// 注入扩展注册表（活跃贡献 = 路由源）。
  PluginCommandBus({required this.extensions});

  /// plugon 扩展注册表。
  final ExtensionRegistry extensions;

  /// 宿主级直接注册（register 兼容；M5 起主要来源 = 扩展点贡献）。
  final Map<Type, CommandHandler<Command, WriteResult>> _handlers =
      <Type, CommandHandler<Command, WriteResult>>{};

  /// 写后监听（UI 管理器单播桥 + 插件订阅）。
  final List<void Function(WriteResult)> _listeners =
      <void Function(WriteResult)>[];

  /// 撤销管理器（宿主装配时挂接；null = 无撤销，测试兼容）。
  UndoManager? undoManager;

  @override
  void register<C extends Command, R extends WriteResult>(
    CommandHandler<C, R> handler,
  ) {
    _handlers[handler.commandType] =
        handler as CommandHandler<Command, WriteResult>;
  }

  @override
  Future<R> dispatch<C extends Command, R>(C command) async {
    final result = await executeRaw(command);
    // 撤销记录（03 §四）：成功写后 result.inverse 入栈——
    // undo/redo 走 executeRaw（不记录，见 UndoManager）。
    undoManager?.record(result);
    return result as R;
  }

  /// 原始执行：路由 → Handler → 写后通知（不记录撤销）。
  ///
  /// [UndoManager] 的 dispatchRaw 通道——撤销/重做必须经此执行，
  /// 否则对偶命令的结果会把原命令重新压回撤销栈（撤销失效）。
  Future<WriteResult> executeRaw(Command command) async {
    final handler =
        _handlers[command.runtimeType] ?? _handlerFromExtensions(command);
    if (handler == null) {
      throw StateError('未注册命令的处理器: ${command.runtimeType}');
    }
    final result = await handler.handle(command);
    for (final listener in _listeners) {
      listener(result);
    }
    return result;
  }

  /// 扩展点活跃贡献中按 commandType 匹配的 Handler（O(handlers)，量小）。
  CommandHandler<Command, WriteResult>? _handlerFromExtensions(
    Command command,
  ) {
    for (final handler in extensions.getActive(commandHandlerPoint)) {
      if (handler.commandType == command.runtimeType) {
        return handler;
      }
    }
    return null;
  }

  @override
  void attach(void Function(WriteResult) listener) {
    _listeners.add(listener);
  }

  @override
  void detach(void Function(WriteResult) listener) {
    _listeners.remove(listener);
  }

  /// 写后广播（M7：Lua 宿主 API 同步写——C 回调无法 await dispatch，
  /// 同步执行后经本入口广播"写完成"信号；语义与 dispatch 完成后的
  /// 广播一致：WriteResult → 监听者）。
  void notifyListeners(WriteResult result) {
    for (final listener in _listeners) {
      listener(result);
    }
  }
}
