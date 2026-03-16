/// Hook 点 ID 枚举
enum HookPointId {
  /// 主工具栏
  mainToolbar,

  /// 节点上下文菜单
  nodeContextMenu,

  /// 图上下文菜单
  graphContextMenu,

  /// 侧边栏顶部
  sidebarTop,

  /// 侧边栏底部
  sidebarBottom,

  /// 状态栏
  statusBar,

  /// 节点编辑器
  nodeEditor,

  /// 导入导出
  importExport,

  /// 设置
  settings,

  /// 帮助
  help,
}

/// Hook 点信息
class HookPoint {
  /// 创建一个新的 Hook 点实例。
  ///
  /// [id] Hook 点 ID
  /// [name] Hook 点名称
  /// [description] Hook 点描述
  const HookPoint({
    required this.id,
    required this.name,
    required this.description,
  });

  /// Hook 点 ID
  final HookPointId id; 
  /// Hook 点名称
  final String name;
  /// Hook 点描述
  final String description; 
}

/// 标准 Hook 点
class StandardHookPoints {
  /// 主工具栏 Hook 点
  static const HookPoint mainToolbar = HookPoint(
    id: HookPointId.mainToolbar,
    name: 'Main Toolbar',
    description: 'Main toolbar at the top of the application',
  );

  /// 节点上下文菜单 Hook 点
  static const HookPoint nodeContextMenu = HookPoint(
    id: HookPointId.nodeContextMenu,
    name: 'Node Context Menu',
    description: 'Context menu when right-clicking on a node',
  );

  /// 图上下文菜单 Hook 点
  static const HookPoint graphContextMenu = HookPoint(
    id: HookPointId.graphContextMenu,
    name: 'Graph Context Menu',
    description: 'Context menu when right-clicking on the graph background',
  );

  /// 侧边栏顶部 Hook 点
  static const HookPoint sidebarTop = HookPoint(
    id: HookPointId.sidebarTop,
    name: 'Sidebar Top',
    description: 'Top section of the sidebar',
  );

  /// 侧边栏底部 Hook 点
  static const HookPoint sidebarBottom = HookPoint(
    id: HookPointId.sidebarBottom,
    name: 'Sidebar Bottom',
    description: 'Bottom section of the sidebar',
  );

  /// 状态栏 Hook 点
  static const HookPoint statusBar = HookPoint(
    id: HookPointId.statusBar,
    name: 'Status Bar',
    description: 'Status bar at the bottom of the application',
  );

  /// 节点编辑器 Hook 点
  static const HookPoint nodeEditor = HookPoint(
    id: HookPointId.nodeEditor,
    name: 'Node Editor',
    description: 'Node content editor',
  );

  /// 导入导出 Hook 点
  static const HookPoint importExport = HookPoint(
    id: HookPointId.importExport,
    name: 'Import/Export',
    description: 'Import/export functionality',
  );

  /// 设置 Hook 点
  static const HookPoint settings = HookPoint(
    id: HookPointId.settings,
    name: 'Settings',
    description: 'Application settings',
  );

  /// 帮助 Hook 点
  static const HookPoint help = HookPoint(
    id: HookPointId.help,
    name: 'Help',
    description: 'Help and documentation',
  );

  /// 获取所有标准 Hook 点
  static List<HookPoint> getAll() => [
      mainToolbar,
      nodeContextMenu,
      graphContextMenu,
      sidebarTop,
      sidebarBottom,
      statusBar,
      nodeEditor,
      importExport,
      settings,
      help,
    ];

  /// 根据 ID 获取 Hook 点
  static HookPoint? getById(HookPointId id) => getAll().firstWhere((point) => point.id == id);
}
