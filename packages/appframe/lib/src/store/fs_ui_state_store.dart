/// FSUIStateStore —— UIStateStore 的文件系统实现（02 §2.3）。
///
/// `data/ui-state.json` KV 文件：量小（可视窗口，架构 §1 选型），
/// 原子写（tmp + rename），惰性加载（首次触达读盘）。
/// 不含任何结构性数据（00 不变量 4.1 投影不变式）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:core_data/core_data.dart';
import 'package:flutter/foundation.dart'; // debugPrint（R9 兜底诊断日志）

/// UIStateStore 的文件系统实现（JSON KV）。
class FSUIStateStore implements UIStateStore {
  /// 以数据根目录初始化（`ui-state.json` 惰性加载）。
  FSUIStateStore({required Directory dataRoot})
    : _file = File('${dataRoot.path}${Platform.pathSeparator}ui-state.json');

  final File _file;

  Map<String, dynamic>? _cache;
  bool _dirty = false;

  /// 键变更监听器（M7.2 D2：外部写入方 → 渲染方定向刷新）。
  final List<UIStateListener> _listeners = <UIStateListener>[];

  Map<String, dynamic> _ensureLoaded() {
    if (_cache != null) {
      return _cache!;
    }
    if (_file.existsSync()) {
      try {
        _cache = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
        return _cache!;
      } on FormatException {
        // 损坏的 ui-state.json 已知形态 1（R9 类型化，audit-appframe #3）：
        // JSON 语法损坏 → 重建为空 KV（外观状态可丢，结构不可丢）。
        _cache = <String, dynamic>{};
        return _cache!;
      } on TypeError {
        // 损坏的 ui-state.json 已知形态 2（顶层非 Map / 键值类型错）。
        _cache = <String, dynamic>{};
        return _cache!;
      } catch (error) {
        // 存储兜底豁免（R9 注释，docs/review 总览 P0-1 裁决）：损坏外观
        // 文件不应使整个应用不可启动；未知异常保留诊断痕迹（debugPrint）
        // 后同样降级为空 KV（结构权威在 graph，外观可丢不可崩）。
        debugPrint('ui-state.json 损坏降级: $error');
        _cache = <String, dynamic>{};
        return _cache!;
      }
    }
    _cache = <String, dynamic>{};
    return _cache!;
  }

  void _flush() {
    if (!_dirty) {
      return;
    }
    _file.parent.createSync(recursive: true);
    final tmp = File('${_file.path}.tmp');
    tmp.writeAsStringSync(jsonEncode(_ensureLoaded()), flush: true);
    tmp.renameSync(_file.path);
    _dirty = false;
  }

  @override
  dynamic get(String key) => _ensureLoaded()[key];

  @override
  void set(String key, dynamic value) {
    _ensureLoaded()[key] = value;
    _dirty = true;
    _flush();
    _notify(key);
  }

  @override
  void remove(String key) {
    if (_ensureLoaded().remove(key) != null) {
      _dirty = true;
      _flush();
      _notify(key);
    }
  }

  @override
  void attach(UIStateListener listener) => _listeners.add(listener);

  @override
  void detach(UIStateListener listener) => _listeners.remove(listener);

  /// 键变更广播（快照遍历——监听器内增删订阅安全）。
  void _notify(String key) {
    for (final listener in List<UIStateListener>.of(_listeners)) {
      listener(key);
    }
  }

  @override
  Map<String, dynamic> getByPrefix(String prefix) {
    final all = _ensureLoaded();
    // 孤儿 GC 由 UI 管理器对照 Graph 惰性清理（02 §2.3）；本存储只读。
    return <String, dynamic>{
      for (final entry in all.entries)
        if (entry.key.startsWith(prefix)) entry.key: entry.value,
    };
  }
}
