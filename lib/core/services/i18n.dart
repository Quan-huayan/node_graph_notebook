import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// 国际化服务
///
/// 提供多语言支持，通过插件动态更新翻译
class I18n extends ChangeNotifier {
  /// 单例实例
  I18n();

  /// 获取当前上下文的 I18n 实例
  static I18n of(BuildContext context) => Provider.of<I18n>(context, listen: false);

  String _currentLanguage = 'en';

  /// 当前语言
  String get currentLanguage => _currentLanguage;

  /// 翻译文本
  ///
  /// [key] 翻译键（通常是英文原文）
  /// 返回翻译后的文本，如果找不到翻译则返回原文本
  String t(String key) {
    final langMap = _translations[_currentLanguage];
    if (langMap == null) return key;
    return langMap[key] ?? key;
  }

  /// 切换语言
  ///
  /// [language] 语言代码（'en' 或 'zh'）
  void switchLanguage(String language) {
    if (_currentLanguage != language) {
      _currentLanguage = language;
      notifyListeners();
      debugPrint('[I18n] Language switched to: $language');
    }
  }

  /// 检查是否支持指定语言
  bool supportsLanguage(String language) => _translations.containsKey(language);

  /// 获取所有支持的语言
  List<String> get supportedLanguages => _translations.keys.toList();

  /// 翻译数据
  ///
  /// 可以通过插件动态更新
  final Map<String, Map<String, String>> _translations = {
    'en': {}, // 英文不需要翻译，保持原样
    'zh': {
      // === 通用 ===
      'Node Graph Notebook': 'Node Graph Notebook', // 标题不变
      'Home': '主页',
      'Settings': '设置',
      'About': '关于',
      'Delete': '删除',
      'Cancel': '取消',
      'Confirm': '确认',
      'Close': '关闭',
      'Save': '保存',
      'Rename': '重命名',
      'Create': '创建',
      'Install': '安装',
      'Uninstall': '卸载',
      'Documentation': '文档',
      'Language': '语言',
      'Select Language': '选择语言',

      // === 设置页面 ===
      'View project documentation': '查看项目文档',
      'Light': '浅色',
      'Always use light theme': '始终使用浅色主题',
      'Dark': '深色',
      'Always use dark theme': '始终使用深色主题',
      'System': '跟随系统',
      'Follow system settings': '跟随系统设置',

      // === 文件夹相关 ===
      'Folder': '文件夹',
      'Delete folder': '删除文件夹',
      'Are you sure you want to delete this folder?': '确定要删除此文件夹吗？',
      'This will delete all nodes in this folder.': '这将删除文件夹中的所有节点。',
      'No folder plugin loaded': '未加载文件夹插件',

      // === AI 相关 ===
      'AI Tools': 'AI 工具',
      'AI Assistant': 'AI 助手',
      'AI Configuration': 'AI 配置',
      'Analyze selected nodes': '分析选中节点',
      'Use AI to analyze node content': '使用 AI 分析节点内容',
      'Suggest connections': '推荐连接',
      'AI analysis and suggest node connections': 'AI 分析并推荐节点连接',
      'Generate graph summary': '生成图摘要',
      'AI generates summary of the graph': 'AI 生成整张图的摘要',
      'Generate node': '生成节点',
      'Use AI to generate new node content': '使用 AI 生成新节点内容',
      'Your AI assistant. Click to start a conversation!': '您的 AI 助手。点击开始对话！',
      'AI Assistant added to the graph!': 'AI 助手已添加到图中！',
      'Failed to add AI Assistant:': '添加 AI 助手失败：',
      'Import & Export': '导入和导出',
      'Not configured': '未配置',
      'Node Settings': '节点设置',

      // === 对话框 ===
      'Initializing...': '初始化中...',
      'Loading plugins...': '加载插件中...',
      'Retry': '重试',
      'OK': '确定',

      // === 主题相关 ===
      'Theme Mode': '主题模式',
      'Theme': '主题',
      'Storage': '存储',
      'Storage Path': '存储路径',
      'Select Storage Location': '选择存储位置',

      // === 插件相关 ===
      'Plugins': '插件',
      'Plugin Market': '插件市场',
      'Installed': '已安装',
      'Available': '可用',
      'Available Plugins': '可用插件',
      'Enable': '启用',
      'Disable': '禁用',
      'Version': '版本',
      'Author': '作者',
      'By:': '作者：',
      'Description': '描述',
      'Installing...': '安装中...',

      // === 设置页面 ===
      'Storage Settings': '存储设置',
      'Storage Location': '存储位置',
      'Default Location': '默认位置',
      'Storage Usage': '存储使用情况',
      'Theme Settings': '主题设置',
      'Color Theme': '颜色主题',
      'View Settings': '视图设置',
      'Show Connections': '显示连接',
      'Display connection lines between nodes': '显示节点间的连接线',
      'Show Sidebar': '显示侧边栏',
      'Display the node list sidebar': '显示节点列表侧边栏',
      'Show Grid': '显示网格',
      'Display background grid': '显示背景网格',
      'Default View Mode': '默认视图模式',
      'AI Settings': 'AI 设置',
      'Test AI Connection': '测试 AI 连接',
      'Chat with AI to test the configuration': '与 AI 聊天以测试配置',
      'Version 0.1.0': '版本 0.1.0',
      'Select Default View Mode': '选择默认视图模式',
      'About Node Graph Notebook': '关于 Node Graph Notebook',
      'Reset to Default': '重置为默认',
      'Reset to default storage location?': '重置为默认存储位置？',
      'Reset': '重置',
      'Choose New Location': '选择新位置',
      'Select Theme': '选择主题',

      // === 键盘快捷键 ===
      'Keyboard Shortcuts': '键盘快捷键',
      'Create New Node': '创建新节点',
      'Undo': '撤销',
      'Redo': '重做',
      'Delete Selected Node': '删除选中节点',
      'Search': '搜索',
      'Export': '导出',
      'Force Directed Layout': '力导向布局',
      'Hierarchical Layout': '层次布局',
      'Circular Layout': '环形布局',
      'Concept Map Layout': '概念图布局',

      // === 其他 ===
      'calculating': '计算中...',
      'nodes': '节点',
      'graphs': '图',
    },
  };

  /// 更新翻译数据
  ///
  /// [translations] 新的翻译数据
  void updateTranslations(Map<String, Map<String, String>> translations) {
    translations.forEach(addTranslations);
    notifyListeners();
  }

  /// 添加或更新翻译
  ///
  /// [language] 语言代码
  /// [key] 翻译键
  /// [value] 翻译值
  void addTranslation(String language, String key, String value) {
    if (!_translations.containsKey(language)) {
      _translations[language] = {};
    }
    _translations[language]![key] = value;
  }

  /// 批量添加翻译
  ///
  /// [language] 语言代码
  /// [translations] 翻译映射
  void addTranslations(String language, Map<String, String> translations) {
    if (!_translations.containsKey(language)) {
      _translations[language] = {};
    }
    _translations[language]!.addAll(translations);
  }

  @override
  String toString() => 'I18n(language: $_currentLanguage)';
}
