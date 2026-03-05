import 'package:flutter/foundation.dart';
import '../../core/models/enums.dart';

/// UI 状态管理
class UIModel extends ChangeNotifier {
  NodeViewMode _nodeViewMode = NodeViewMode.titleWithPreview;
  bool _showConnections = true;
  BackgroundStyle _backgroundStyle = BackgroundStyle.grid;
  bool _isSidebarOpen = true;
  String _selectedTab = 'nodes';

  NodeViewMode get nodeViewMode => _nodeViewMode;
  NodeViewMode get defaultViewMode => _nodeViewMode;
  bool get showConnections => _showConnections;
  BackgroundStyle get backgroundStyle => _backgroundStyle;
  bool get isSidebarOpen => _isSidebarOpen;
  String get selectedTab => _selectedTab;

  /// 设置节点显示模式
  void setNodeViewMode(NodeViewMode mode) {
    _nodeViewMode = mode;
    notifyListeners();
  }

  /// 设置默认节点显示模式（用于设置对话框）
  void setDefaultViewMode(NodeViewMode mode) {
    _nodeViewMode = mode;
    notifyListeners();
  }

  /// 切换连接线显示
  void toggleConnections() {
    _showConnections = !_showConnections;
    notifyListeners();
  }

  /// 设置连接线显示
  void setConnections(bool show) {
    _showConnections = show;
    notifyListeners();
  }

  /// 设置背景样式
  void setBackgroundStyle(BackgroundStyle style) {
    _backgroundStyle = style;
    notifyListeners();
  }

  /// 切换侧边栏
  void toggleSidebar() {
    _isSidebarOpen = !_isSidebarOpen;
    notifyListeners();
  }

  /// 设置侧边栏
  void setSidebar(bool open) {
    _isSidebarOpen = open;
    notifyListeners();
  }

  /// 打开侧边栏
  void openSidebar() {
    _isSidebarOpen = true;
    notifyListeners();
  }

  /// 关闭侧边栏
  void closeSidebar() {
    _isSidebarOpen = false;
    notifyListeners();
  }

  /// 选择标签页
  void selectTab(String tab) {
    _selectedTab = tab;
    notifyListeners();
  }
}
