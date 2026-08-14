/// ToolbarConcept —— 工具栏按钮 UI 节点（M7 修正，00"All is Node"落地）。
///
/// **工具栏按钮 = 节点**：`metadata.kind == 'toolbar'` 的节点由本
/// Concept 渲染为 AppBar 按钮（Hook 体系承载 UI——不发明 UI 扩展点）：
/// - `metadata['icon']` — 图标名（Material Icons 名，字典在呈现层）
/// - `metadata['tooltip']` — 悬停提示
/// - `metadata['action']` — 动作名（点击查 `ToolbarActionRegistry`）
///
/// 动作 = 插件注册（`ToolbarActionRegistry` 服务，plugon DI 现有机制）：
/// 插件 onLoad 注册 `(BuildContext) → 打开自己的对话框`——**插件的 UI
/// 全在插件内**，app 只播种按钮节点（组装职责）。
///
/// 按钮动作 = 打开对话框等 **UI 行为**（非 Node 数据写——00 不变量
/// 4.4-1 约束数据写；UI 行为直接执行不经命令总线）。
library;

import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import '../host/host_runtime.dart';
import '../render/flutter_render_context.dart';

/// 工具栏目标动作（携带按钮节点引用的目标节点——拖拽建按钮场景，
/// M7.3）。
typedef ToolbarTargetedAction =
    void Function(BuildContext context, String targetId);

/// 工具栏动作注册表（服务——插件注册按钮动作，plugon DI 解析）。
///
/// 动作签名带 BuildContext：插件的对话框逻辑在插件内
/// （插件 UI 零依赖组合根）。
/// M7.3：`registerTargeted` 目标动作——按钮节点 metadata 带 `target`
/// （拖拽建按钮：点击打开目标节点对话框）。
class ToolbarActionRegistry {
  /// 注册动作（name → 回调）。
  void register(String name, void Function(BuildContext context) action) {
    _actions[name] = action;
  }

  /// 查动作（未注册 → null）。
  void Function(BuildContext context)? lookup(String name) => _actions[name];

  /// 注册目标动作（name → 回调，携带目标节点 id）。
  void registerTargeted(String name, ToolbarTargetedAction action) {
    _targetedActions[name] = action;
  }

  /// 查目标动作（未注册 → null）。
  ToolbarTargetedAction? lookupTargeted(String name) => _targetedActions[name];

  /// 清空全部（vault 切换时旧 host 实例整体丢弃，无需调用；保留
  /// 供测试/动态装配复用）。
  void unregisterAll() {
    _actions.clear();
    _targetedActions.clear();
  }

  final Map<String, void Function(BuildContext context)> _actions =
      <String, void Function(BuildContext context)>{};

  final Map<String, ToolbarTargetedAction> _targetedActions =
      <String, ToolbarTargetedAction>{};
}

/// 工具栏按钮 Concept（appframe 内置——UI 节点机制，非插件私有）。
class ToolbarConcept extends Concept {
  /// 无状态（可 const 装配）。
  const ToolbarConcept();

  @override
  String get id => 'com.appframe:toolbar';

  @override
  String get name => '工具栏按钮';

  @override
  String get description => '工具栏 UI 节点（kind == toolbar，动作 = metadata.action）';

  @override
  Set<String> get slots => const <String>{};

  @override
  Set<String> get requiredSlots => const <String>{};

  @override
  Map<String, MetadataField> get metadataSchema =>
      const <String, MetadataField>{
        'kind': MetadataField(name: 'kind', type: MetadataType.string),
        'icon': MetadataField(name: 'icon', type: MetadataType.string),
        'tooltip': MetadataField(name: 'tooltip', type: MetadataType.string),
        'action': MetadataField(name: 'action', type: MetadataType.string),
        'target': MetadataField(name: 'target', type: MetadataType.string),
      };

  @override
  Set<String> get requiredMetadataKeys => const <String>{'kind'};

  @override
  ContentRequirement get contentRequirement => ContentRequirement.none;

  @override
  bool validate(Node node) => node.metadata['kind'] == 'toolbar';

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('工具栏节点由宿主播种/插件创建（写路径）');
  }

  @override
  Hook createHook(Node instance, HookContext context) => ToolbarHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
    instance: instance,
  );
}

/// 工具栏按钮 Hook（渲染 IconButton，点击查 registry 执行动作）。
class ToolbarHook extends Hook {
  /// 构造（携带节点数据——渲染读取）。
  ToolbarHook({
    required this.nodeId,
    required this.hookId,
    required this.instance,
  });

  @override
  final String nodeId;

  @override
  final String hookId;

  /// 按钮节点（渲染读取 metadata）。
  final Node instance;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    final flutterContext = context as FlutterRenderContext;
    final host = flutterContext.host;
    final sink = flutterContext.sink;
    if (host == null || sink == null) {
      return; // 测试环境：无宿主/收集器 → 不渲染。
    }
    // M7.1（物化实例复用）：render 时重读自己 Node（02 §3.4 主动读）——
    // 失效后定向重建渲染的是新数据，不持有陈旧快照。
    final node = host.graph.get(nodeId) ?? instance;
    final iconName = node.metadata['icon'] as String?;
    final tooltip = node.metadata['tooltip'] as String? ?? node.title;
    final action = node.metadata['action'] as String?;
    // Builder 捕获 widget context——动作执行（打开对话框）需要它。
    sink.add(
      Builder(
        builder: (context) => IconButton(
          icon: Icon(_iconFor(iconName)),
          tooltip: tooltip,
          onPressed: action == null
              ? null
              : () => _runAction(host, action, context),
        ),
      ),
    );
  }

  /// 执行动作（查 ToolbarActionRegistry——插件注册的 UI 行为）。
  /// M7.3 目标动作优先：按钮节点 metadata['target']（拖拽建按钮的
  /// 目标节点）命中 targeted 注册 → 携带 target 调用。
  void _runAction(HostRuntime host, String action, BuildContext context) {
    final registry = host.serviceProvider.get<ToolbarActionRegistry>();
    final node = host.graph.get(nodeId) ?? instance;
    final target = node.metadata['target'] as String?;
    final targeted = registry.lookupTargeted(action);
    if (targeted != null && target != null) {
      targeted(context, target);
      return;
    }
    final handler = registry.lookup(action);
    if (handler == null) {
      // 未注册动作 → 静默（插件未加载/未注册——按钮节点是数据，
      // 动作是插件能力，缺省无行为）。
      return;
    }
    handler(context);
  }

  IconData _iconFor(String? name) {
    // Material Icons 名字典（M7 常用集——图标名是数据，字典是呈现）。
    switch (name) {
      case 'graphic_eq':
        return Icons.graphic_eq;
      case 'settings':
        return Icons.settings_outlined;
      case 'storefront':
        return Icons.storefront_outlined;
      case 'smart_toy':
        return Icons.smart_toy_outlined;
      case 'extension':
        return Icons.extension_outlined;
      case 'search':
        return Icons.search;
      case 'import_export':
        return Icons.import_export;
      case 'open_in_new':
        return Icons.open_in_new;
      default:
        return Icons.circle_outlined;
    }
  }
}
