import 'models/command.dart';
import 'models/command_handler.dart';

/// 命令处理器注册表
///
/// 负责管理和注册命令处理器
class CommandHandlerRegistry {
  /// 命令处理器映射
  ///
  /// Key: 命令类型的运行时类型
  /// Value: 对应的命令处理器
  final Map<Type, CommandHandler> _handlers = {};

  /// 注册命令处理器
  ///
  /// [handler] 命令处理器实例
  /// [commandType] 命令类型
  void register<T extends Command>(
    CommandHandler<T> handler,
    Type commandType,
  ) {
    _handlers[commandType] = handler;
  }

  /// 获取命令处理器
  ///
  /// [commandType] 命令类型
  /// 返回对应的命令处理器，如果未找到返回 null
  CommandHandler? getHandler(Type commandType) => _handlers[commandType];

  /// 批量注册命令处理器
  ///
  /// [handlers] 命令处理器映射
  void registerAll(Map<Type, CommandHandler> handlers) {
    _handlers.addAll(handlers);
  }

  /// 注销命令处理器
  ///
  /// [commandType] 命令类型
  void unregister(Type commandType) {
    _handlers.remove(commandType);
  }

  /// 清空所有命令处理器
  void clear() {
    _handlers.clear();
  }

  /// 检查是否包含指定命令类型的处理器
  ///
  /// [commandType] 命令类型
  bool contains(Type commandType) => _handlers.containsKey(commandType);

  /// 获取注册的命令处理器数量
  int get size => _handlers.length;
}
