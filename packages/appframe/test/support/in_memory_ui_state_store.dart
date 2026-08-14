/// 测试夹具：内存 UIStateStore（appframe/node_graph 测试用）。
library;

import 'package:core_data/core_data.dart';

/// 内存外观存储（KV 直存，无持久化；M7.2 D2：含观察者通道）。
class InMemoryUIStateStore implements UIStateStore {
  final Map<String, dynamic> _store = <String, dynamic>{};
  final List<UIStateListener> _listeners = <UIStateListener>[];

  @override
  dynamic get(String key) => _store[key];

  @override
  Map<String, dynamic> getByPrefix(String prefix) => <String, dynamic>{
    for (final entry in _store.entries)
      if (entry.key.startsWith(prefix)) entry.key: entry.value,
  };

  @override
  void remove(String key) {
    if (_store.remove(key) != null) {
      _notify(key);
    }
  }

  @override
  void set(String key, dynamic value) {
    _store[key] = value;
    _notify(key);
  }

  @override
  void attach(UIStateListener listener) => _listeners.add(listener);

  @override
  void detach(UIStateListener listener) => _listeners.remove(listener);

  void _notify(String key) {
    for (final listener in List<UIStateListener>.of(_listeners)) {
      listener(key);
    }
  }
}
