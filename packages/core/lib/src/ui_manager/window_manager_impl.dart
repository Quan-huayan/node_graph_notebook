/// WindowManagerImpl —— 窗口化登记实现（02 §3.3，10⁶ 前提）。
///
/// hookId ↔ (nodeId, containerHook, kind) 双向登记；
/// kind 追溯链：子 Hook 的 kind = 容器 kind（物化时继承）。
///
/// 失败行为（架构 §3）：回收非物化 Hook → 静默 no-op。
library;

import 'package:core_data/core_data.dart';

import 'window.dart';

/// 窗口化登记的具体实现。
class WindowManagerImpl implements WindowManager {
  final Map<String, _Entry> _entries = <String, _Entry>{};
  final Map<String, Set<String>> _byNode = <String, Set<String>>{};

  /// 物化登记：hook 挂到 containerHook 下（kind 为容器 kind）。
  @override
  void attach(Hook hook, Hook? containerHook, String kind) {
    _entries[hook.hookId] = _Entry(
      hook: hook,
      containerHook: containerHook,
      kind: kind,
    );
    _byNode.putIfAbsent(hook.nodeId, () => <String>{}).add(hook.hookId);
  }

  @override
  bool isMaterialized(String nodeId, {String? kind}) {
    final hookIds = _byNode[nodeId];
    if (hookIds == null || hookIds.isEmpty) {
      return false;
    }
    if (kind == null) {
      return true;
    }
    // kind 感知：同一节点多容器多 Hook（M7.1 kindOf 区分）。
    return hookIds.any((hookId) => _entries[hookId]?.kind == kind);
  }

  /// 回收：非物化 hookId → 静默 no-op。
  @override
  void recycle(String hookId) {
    final entry = _entries.remove(hookId);
    if (entry == null) {
      return;
    }
    _byNode[entry.hook.nodeId]?.remove(hookId);
    if (_byNode[entry.hook.nodeId]?.isEmpty ?? false) {
      _byNode.remove(entry.hook.nodeId);
    }
  }

  /// 已物化 Hook 查询（失效广播/渲染循环用）。
  Hook? hookOf(String hookId) => _entries[hookId]?.hook;

  /// 已物化 Hook 的 kind（子物化继承）。
  String? kindOf(String hookId) => _entries[hookId]?.kind;

  /// 容器 Hook（回收子树时用；根容器为 null）。
  Hook? containerOf(String hookId) => _entries[hookId]?.containerHook;

  /// 已物化 hookId 集合（渲染循环遍历）。
  Iterable<String> get hookIds => _entries.keys;
}

class _Entry {
  const _Entry({
    required this.hook,
    required this.containerHook,
    required this.kind,
  });

  final Hook hook;
  final Hook? containerHook;
  final String kind;
}
