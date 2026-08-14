/// ShellSignals —— 壳层信号服务（P1-4：跨插件 UI 协调的会话态通道）。
///
/// 判据③：会话态（当前侧边栏 tab 等）**不落盘**（UIStateStore 是判据②
/// 外观通道）——信号只通知、不持久化。AppShell 全局快捷键 → 信号 →
/// 侧边栏视图（node_folder）响应：壳与插件零依赖，通道 = 壳层服务。
library;

import 'package:flutter/foundation.dart';

/// 壳层信号服务（HostRuntime 注册为 plugon 单例）。
class ShellSignals extends ChangeNotifier {
  /// Ctrl+F：聚焦搜索面板（侧边栏切到搜索 tab）。
  void requestSearchFocus() => notifyListeners();
}
