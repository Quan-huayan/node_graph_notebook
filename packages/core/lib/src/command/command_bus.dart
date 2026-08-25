/// CommandBus —— 命令路由侧（04 §1.1：注册归 plugon 扩展点，路由归我们）。
///
/// 写后通知：CommandBus 完成写命令后，把 WriteResult 交给注册的通知器。
/// 单播桥（UI 管理器）+ 插件观察订阅——不是 EventBus：
/// 无事件对象、无优先级、无广播语义，只有"写完成"这一个信号（03 §四）。
library;

import 'command.dart';

/// 写后通知器：CommandBus 完成写命令后，把 WriteResult 交给注册的通知器。
///
/// 插件观察契约（03 §5.2）：订阅必须实现 Disposable 并在 onUnload 关闭
/// ——硬规则，代码审查强制执行（plugon 的 disposeOwner 不管理订阅）。
abstract class WriteNotifier {
  /// 注册写后监听（UI 管理器单播桥 / 插件观察订阅）。
  void attach(void Function(WriteResult) listener);

  /// 注销监听（插件 onUnload 必须 detach——硬规则）。
  void detach(void Function(WriteResult) listener);
}

/// 命令总线：集中命令分发，中间件管道包裹 Handler（04 资产盘点带走实现）。
///
/// Handler 注册由 plugon `ExtensionPoint<CommandHandler>` 贡献
/// （04 §1.1）；本总线只做路由与写后通知。
abstract class CommandBus {
  /// 注册 Handler（按命令类型路由；注册归 plugon 扩展点，M5 接入）。
  void register<C extends Command, R extends WriteResult>(
    CommandHandler<C, R> handler,
  );

  /// 分发命令 → 找到 Handler 执行 → 完成写后交给 WriteNotifier。
  Future<R> dispatch<C extends Command, R>(C command);
}

/// 命令总线默认实现（路由 + 写后通知单播桥）。
///
/// 失败行为（架构 §3）：未注册命令 → StateError（配置错误）；
/// Handler 内环校验失败 → CycleError（由 Handler 抛出）。
///
/// 与 PluginCommandBus 的关系（audit-core #10 记录）：**生产装配用
/// PluginCommandBus**（扩展点路由，HostRuntime 接线）；本实现是插件订阅
/// 方案成熟前的最小总线示例，保留作契约参考/独立测试，非生产依赖。
class CommandBusImpl implements CommandBus, WriteNotifier {
  /// 路由表：commandType → handler。
  final Map<Type, CommandHandler<Command, WriteResult>> _handlers =
      <Type, CommandHandler<Command, WriteResult>>{};

  /// 写后监听（UI 管理器单播桥 + 插件订阅）。
  final List<void Function(WriteResult)> _listeners =
      <void Function(WriteResult)>[];

  @override
  void register<C extends Command, R extends WriteResult>(
    CommandHandler<C, R> handler,
  ) {
    _handlers[handler.commandType] =
        handler as CommandHandler<Command, WriteResult>;
  }

  @override
  Future<R> dispatch<C extends Command, R>(C command) async {
    final handler = _handlers[command.runtimeType];
    if (handler == null) {
      throw StateError('未注册命令的处理器: ${command.runtimeType}');
    }
    final result = await handler.handle(command as Command);
    for (final listener in _listeners) {
      listener(result);
    }
    return result as R;
  }

  @override
  void attach(void Function(WriteResult) listener) {
    _listeners.add(listener);
  }

  @override
  void detach(void Function(WriteResult) listener) {
    _listeners.remove(listener);
  }
}
