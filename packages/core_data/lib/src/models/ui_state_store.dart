/// UIStateStore 契约（02 §2.3）。
library;

/// 键变更监听（02 §2.3 失效语义，M7.2 D2 回填）。
typedef UIStateListener = void Function(String key);

/// UIStateStore —— 前端存储：外观状态。
///
/// 不含任何结构性数据（00 不变量 4.1 投影不变式）。
/// 键带容器上下文，避免 `position.<nodeId>` 碰撞：
///
/// ```
/// <domain>.<containerId>.<hookId>
/// position.graph.<folderId>        // 画布位置
/// expand.sidebar.<folderId>        // 侧边栏展开
/// camera.main.<rootHookId>         // 相机
/// selection.<containerId>.<hookId>
/// ```
abstract class UIStateStore {
  /// 读取键值；不存在返回 null。
  dynamic get(String key);

  /// 写入键值。
  void set(String key, dynamic value);

  /// 删除键；不存在为静默 no-op。
  void remove(String key);

  /// 按前缀读取（孤儿 GC：触达时对照 Graph 的 nodeId 存在性，
  /// 惰性清理不存在的键，02 §2.3）。
  Map<String, dynamic> getByPrefix(String prefix);

  /// 订阅键变更（02 §2.3 失效语义，M7.2 D2：**外部写入方**——可见性
  /// 对话框/未来插件——的外观直写需到达渲染方；渲染方按关心前缀过滤
  /// 定向刷新）。set/remove 触发（get/getByPrefix 不触发）。
  void attach(UIStateListener listener);

  /// 取消订阅。
  void detach(UIStateListener listener);
}
