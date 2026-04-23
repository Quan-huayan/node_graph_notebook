import 'dart:async';

/// 插件通信接口
///
/// 提供插件间的消息传递机制
abstract class PluginCommunication {
  /// 发送消息到指定插件
  ///
  /// [pluginId] 目标插件ID
  /// [message] 消息类型
  /// [data] 消息数据
  /// 返回插件的响应
  Future<dynamic> sendMessage(String pluginId, String message, dynamic data);

  /// 注册消息处理器
  ///
  /// [message] 消息类型
  /// [handler] 消息处理函数
  void registerMessageHandler(String message, Function(dynamic data) handler);

  /// 注销消息处理器
  ///
  /// [message] 消息类型
  void unregisterMessageHandler(String message);

  /// 消息流
  ///
  /// 用于订阅所有消息
  Stream<PluginMessage> get messageStream;
}

/// 插件消息
class PluginMessage {
  /// 构造函数
  const PluginMessage({
    required this.fromPluginId,
    required this.message,
    required this.data,
    required this.timestamp,
  });

  /// 发送插件ID
  final String fromPluginId;

  /// 消息类型
  final String message;

  /// 消息数据
  final dynamic data;

  /// 时间戳
  final DateTime timestamp;
}

/// 插件通信实现
class PluginCommunicationImpl implements PluginCommunication {
  /// 消息处理器映射
  final Map<String, List<Function(dynamic)>> _handlers = {};

  /// 消息流控制器
  final _messageStreamController = StreamController<PluginMessage>.broadcast();

  @override
  Future<dynamic> sendMessage(
    String pluginId,
    String message,
    dynamic data,
  ) async {
    final pluginMessage = PluginMessage(
      fromPluginId: 'system',
      message: message,
      data: data,
      timestamp: DateTime.now(),
    );
    
    _messageStreamController.add(pluginMessage);
    
    if (_handlers.containsKey(message)) {
      dynamic lastResult;
      for (final handler in _handlers[message]!) {
        final result = handler(data);
        if (result is Future) {
          lastResult = await result;
        } else {
          lastResult = result;
        }
      }
      return lastResult;
    }
    
    return null;
  }

  @override
  void registerMessageHandler(String message, Function(dynamic data) handler) {
    if (!_handlers.containsKey(message)) {
      _handlers[message] = [];
    }
    _handlers[message]!.add(handler);
  }

  @override
  void unregisterMessageHandler(String message) {
    _handlers.remove(message);
  }

  @override
  Stream<PluginMessage> get messageStream => _messageStreamController.stream;

  /// 处理接收到的消息
  void handleMessage(PluginMessage message) {
    if (_handlers.containsKey(message.message)) {
      for (final handler in _handlers[message.message]!) {
        handler(message.data);
      }
    }
  }

  /// 释放资源
  void dispose() {
    _messageStreamController.close();
    _handlers.clear();
  }
}
