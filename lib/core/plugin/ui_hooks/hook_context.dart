import '../../models/node.dart';

/// Hook 上下文基础类
abstract class HookContext {
  HookContext(this.data);

  final Map<String, dynamic> data;

  /// 获取数据
  T? get<T>(String key) {
    final value = data[key];
    return value is T ? value : null;
  }

  /// 设置数据
  void set(String key, dynamic value) {
    data[key] = value;
  }

  /// 检查是否有数据
  bool contains(String key) {
    return data.containsKey(key);
  }
}

/// 主工具栏 Hook 上下文
class MainToolbarHookContext extends HookContext {
  MainToolbarHookContext(super.data);

  /// 是否显示标题
  bool get showTitle => get<bool>('showTitle') ?? true;

  /// 是否显示搜索
  bool get showSearch => get<bool>('showSearch') ?? true;
}

/// 节点上下文菜单 Hook 上下文
class NodeContextMenuHookContext extends HookContext {
  NodeContextMenuHookContext(super.data);

  /// 当前节点
  Node? get node => get<Node>('node');

  /// 是否为选中状态
  bool get isSelected => get<bool>('isSelected') ?? false;
}

/// 图上下文菜单 Hook 上下文
class GraphContextMenuHookContext extends HookContext {
  GraphContextMenuHookContext(super.data);

  /// 鼠标位置
  Offset? get mousePosition => get<Offset>('mousePosition');

  /// 选中的节点数量
  int get selectedNodeCount => get<int>('selectedNodeCount') ?? 0;
}

/// 侧边栏 Hook 上下文
class SidebarHookContext extends HookContext {
  SidebarHookContext(super.data);

  /// 是否展开
  bool get isExpanded => get<bool>('isExpanded') ?? true;

  /// 侧边栏宽度
  double get width => get<double>('width') ?? 250;
}

/// 状态栏 Hook 上下文
class StatusBarHookContext extends HookContext {
  StatusBarHookContext(super.data);

  /// 节点数量
  int get nodeCount => get<int>('nodeCount') ?? 0;

  /// 连接数量
  int get connectionCount => get<int>('connectionCount') ?? 0;

  /// 当前模式
  String get currentMode => get<String>('currentMode') ?? 'browse';
}

/// 节点编辑器 Hook 上下文
class NodeEditorHookContext extends HookContext {
  NodeEditorHookContext(super.data);

  /// 当前节点
  Node? get node => get<Node>('node');

  /// 是否为只读模式
  bool get isReadOnly => get<bool>('isReadOnly') ?? false;
}

/// 导入导出 Hook 上下文
class ImportExportHookContext extends HookContext {
  ImportExportHookContext(super.data);

  /// 支持的导入格式
  List<String> get importFormats => get<List<String>>('importFormats') ?? [];

  /// 支持的导出格式
  List<String> get exportFormats => get<List<String>>('exportFormats') ?? [];
}

/// 设置 Hook 上下文
class SettingsHookContext extends HookContext {
  SettingsHookContext(super.data);

  /// 当前设置
  Map<String, dynamic> get currentSettings => get<Map<String, dynamic>>('currentSettings') ?? {};
}

/// 帮助 Hook 上下文
class HelpHookContext extends HookContext {
  HelpHookContext(super.data);

  /// 帮助文档列表
  List<HelpItem> get helpItems => get<List<HelpItem>>('helpItems') ?? [];
}

/// 帮助项
class HelpItem {
  HelpItem({
    required this.title,
    required this.content,
    this.icon,
  });

  final String title;
  final String content;
  final String? icon;
}

/// 偏移量
class Offset {
  Offset(this.dx, this.dy);

  final double dx;
  final double dy;
}
