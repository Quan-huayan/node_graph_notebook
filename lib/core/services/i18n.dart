import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 国际化服务
///
/// 提供多语言支持，通过插件动态更新翻译
/// 支持语言持久化，重启应用后自动恢复上次选择的语言
class I18n extends ChangeNotifier {
  /// 单例实例
  I18n();

  /// 获取当前上下文的 I18n 实例
  static I18n of(BuildContext context) => Provider.of<I18n>(context, listen: false);

  /// SharedPreferences 存储键
  static const String _prefsKey = 'i18n_language';

  /// 默认语言
  static const String _defaultLanguage = 'en';

  String _currentLanguage = _defaultLanguage;
  bool _isInitialized = false;

  /// 当前语言
  String get currentLanguage => _currentLanguage;

  /// 是否已初始化（从持久化存储加载）
  bool get isInitialized => _isInitialized;

  /// 初始化语言设置
  ///
  /// 从 SharedPreferences 加载用户上次选择的语言
  /// 如果没有保存的语言，使用默认语言
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_prefsKey);

      if (savedLanguage != null && supportsLanguage(savedLanguage)) {
        _currentLanguage = savedLanguage;
        debugPrint('[I18n] Loaded saved language: $_currentLanguage');
      } else {
        debugPrint('[I18n] Using default language: $_currentLanguage');
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[I18n] Failed to load saved language: $e');
      _isInitialized = true;
    }
  }

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
  /// 会自动保存到 SharedPreferences，下次启动时自动恢复
  Future<void> switchLanguage(String language) async {
    if (_currentLanguage == language) return;

    if (!supportsLanguage(language)) {
      debugPrint('[I18n] Unsupported language: $language');
      return;
    }

    _currentLanguage = language;
    notifyListeners();
    debugPrint('[I18n] Language switched to: $language');

    // 持久化语言选择
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, language);
      debugPrint('[I18n] Language saved to preferences');
    } catch (e) {
      debugPrint('[I18n] Failed to save language: $e');
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
      'AI Assistant functionality coming soon!': 'AI 助手功能即将推出！',
      'AI analysis feature': 'AI 分析功能',
      'Connection suggestion feature': '连接推荐功能',
      'Graph summary feature': '图摘要生成功能',
      'Node generation feature': '节点生成功能',
      'This feature requires AI service configuration': '此功能需要配置 AI 服务后才能使用',

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
      'AI Provider': 'AI 提供商',
      'Base URL': '基础URL',
      'Model Name': '模型名称',
      'API Key': 'API 密钥',
      'Enter your API key': '输入您的 API 密钥',
      'OpenAI': 'OpenAI',
      'Anthropic': 'Anthropic',
      'API Configuration': 'API 配置',
      'Get your API key from OpenAI or Anthropic': '从 OpenAI 或 Anthropic 获取您的 API 密钥',
      'Custom base URLs are supported': '支持自定义基础URL',
      'After configuration, use "Test AI Connection" to verify': '配置完成后，使用"测试 AI 连接"进行验证',
      'API Key is required': '需要 API 密钥',
      'AI configuration saved successfully': 'AI 配置已成功保存',
      'Error saving configuration': '保存配置时出错',
      'AI connection test initialized. Type a message to test.': 'AI 连接测试已初始化。输入消息进行测试。',
      'AI not configured. Please configure AI settings first.': 'AI 未配置。请先配置 AI 设置。',
      'Message sent and response received successfully': '消息已发送并成功收到响应',
      'Type a message below to start': '在下方输入消息开始',
      'Type your message...': '输入您的消息...',
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

      // === 编辑器相关 ===
      'Markdown Editor': 'Markdown 编辑器',
      'Bold': '粗体',
      'Italic': '斜体',
      'H1': '一级标题',
      'H2': '二级标题',
      'List': '列表',
      'Code': '代码',
      'Link': '链接',
      'Image': '图片',
      'No preview available': '无预览可用',
      'View as text': '文本视图',
      'View as rendered': '渲染视图',
      'Title cannot be empty': '标题不能为空',
      'Failed to save:': '保存失败：',
      'Failed to save node:': '保存节点失败：',
      'Enter note title': '输入笔记标题',
      'Write your note in Markdown...': '用 Markdown 编写您的笔记...',
      'Supports Markdown formatting': '支持 Markdown 格式',
      'Created:': '已创建：',
      'Failed to create node:': '创建节点失败：',
      'Selected': '已选择',
      'Concept': '概念',
      'Apply': '应用',
      'Added': '已添加',
      'removed': '已移除',
      'node(s)': '个节点',
      'Failed to update graph:': '更新图失败：',
      'No results found': '未找到结果',
      'Import & Export': '导入和导出',
      'Import Markdown File': '导入 Markdown 文件',
      'Import a single Markdown file': '导入单个 Markdown 文件',
      'Batch Import': '批量导入',
      'Import multiple Markdown files': '导入多个 Markdown 文件',
      'Import Graph': '导入图',
      'Import a saved graph file': '导入保存的图文件',
      'Graph import feature - Coming soon!': '图导入功能 - 即将推出！',
      'No graph available to export': '没有可导出的图',
      'Edit Metadata': '编辑元数据',
      'Manage Connections': '管理连接',
      'Add Icon': '添加图标',
      'Change Color': '更改颜色',
      'Duplicate': '复制',
      'Focus Node': '聚焦节点',
      'Select Color': '选择颜色',
      'Edit Node Metadata': '编辑节点元数据',
      'Folder nodes can contain other nodes': '文件夹节点可以包含其他节点',
      'Metadata updated': '元数据已更新',
      'Icon added:': '图标已添加：',
      'Icon removed': '图标已移除',
      'Select Icon': '选择图标',
      'Delete Node': '删除节点',
      'Deleted:': '已删除：',
      'Current:': '当前：',
      'Duplicate Node': '复制节点',
      'Create a copy of': '创建副本：',
      'Duplicated:': '已复制：',
      'Focusing on': '聚焦到：',
      'Export Graph': '导出图',
      'Export the current graph as JSON': '将当前图导出为 JSON',
      'Export as Markdown': '导出为 Markdown',
      'Export all nodes as Markdown files': '将所有节点导出为 Markdown 文件',
      'Export as Image': '导出为图片',
      'Export graph as PNG image': '将图导出为 PNG 图片',
      'Image export feature - Coming soon!': '图片导出功能 - 即将推出！',

      // === 布局相关 ===
      'Layout Algorithm': '布局算法',
      'Force Directed': '力导向布局',
      'Physics-based layout': '基于物理的布局',
      'Hierarchical': '层次布局',
      'Tree-based layout': '基于树的布局',
      'Circular': '环形布局',
      'Circle arrangement': '环形排列',
      'No nodes to layout. Create some nodes first.': '没有节点可布局。请先创建一些节点。',

      // === 节点操作 ===
      'Select All': '全选',
      'Clear': '清除',
      'Clear Filters': '清除过滤器',
      'No nodes found': '未找到节点',
      'Create your first graph to get started': '创建你的第一张图以开始使用',
      'Create Graph': '创建图',
      'Node is already in the graph': '节点已在图中',
      'Failed to add node:': '添加节点失败：',
      'Graph creation functionality coming soon!': '图创建功能即将推出！',
      'Are you sure you want to delete': '确定要删除',
      'Node': '节点',
      'Node deleted': '节点已删除',
      'Error deleting node:': '删除节点错误：',
      'Failed to delete node:': '删除节点失败：',
      'Remove from folder': '从文件夹移除',

      // === 工具栏和菜单 ===
      'Try Again': '重试',

      // === 链接处理 ===
      'Jump to node:': '跳转到节点：',
      'Cannot open link:': '无法打开链接：',
      'File link:': '文件链接：',
      'Unsupported protocol:': '不支持的协议：',
      'Internal link:': '内部链接：',

      // === Markdown 编辑器 ===
      'Edit': '编辑',
      'Preview': '预览',
      'Title': '标题',
      'Write your content in Markdown...': '用 Markdown 编写内容...',
      'Nothing to preview': '没有可预览的内容',
      'Node created': '节点已创建',
      'Node saved': '节点已保存',

      // === 节点选择器 ===
      'Search nodes...': '搜索节点...',
      'selected': '已选择',

      // === 删除节点 ===
      'Delete Node': '删除节点',
      'deleted': '已删除',

      // === 图视图 ===
      'Something went wrong': '出现错误',
      'An unknown error occurred': '发生未知错误',
      'No Graph Yet': '还没有图',

      // === 工具栏和菜单 ===
      'Toggle Connections': '切换连接显示',
      'Toggle Sidebar': '切换侧边栏',
      'Refresh': '刷新',
      'Create New Folder': '创建新文件夹',
      'New Folder': '新文件夹',
      'New folder created': '新文件夹已创建',
      'Failed to create folder:': '创建文件夹失败：',
      'No search plugin loaded': '未加载搜索插件',
      'Collapse Toolbar': '折叠工具栏',
      'Expand Toolbar': '展开工具栏',
      'Create Node': '创建节点',
      'Manage Graph Nodes': '管理图节点',
      'Layout': '布局',
      'Saved searches': '已保存的搜索',
      'Save as preset': '保存为预设',
      'Add tag': '添加标签',
      'Enter search query...': '输入搜索查询...',
      'Advanced Filters': '高级过滤器',
      'Title contains': '标题包含',
      'Content contains': '内容包含',
      'Please enter a search query first': '请先输入搜索查询',
      'Save Search': '保存搜索',
      'Preset Name': '预设名称',
      'Delete Preset': '删除预设',
      'Are you sure you want to delete this search preset?': '确定要删除此搜索预设吗？',

      // === 视图模式 ===
      'Title Only': '仅标题',
      'Title with Preview': '标题和预览',
      'Full Content': '完整内容',
      'Compact': '紧凑',

      // === 侧边栏 ===
      'Show Nodes': '显示节点',
      'Show Search': '显示搜索',

      // === 存储设置 ===
      'Current Location:': '当前位置：',
      'Choose a new storage location. All data will be stored in this location.': '选择新的存储位置。所有数据将存储在此位置。',
      'Warning: Changing the storage location will require restarting the app.': '警告：更改存储位置需要重启应用。',
      'Storage location reset. Please restart the app.': '存储位置已重置。请重启应用。',
      'Storage location changed to:': '存储位置已更改为：',
      'Restart': '重启',

      // === 关于对话框 ===
      'Node Graph Notebook': 'Node Graph Notebook',
      'A concept map-based note-taking application built with Flutter and Flame engine.': '基于概念地图的笔记应用，使用 Flutter 和 Flame 引擎构建。',
      'Features:': '特性：',
      'Visual node graph with Flame engine': '基于 Flame 引擎的可视化节点图',
      'Markdown editing support': 'Markdown 编辑支持',
      'Multiple node types (Content & Concept)': '多种节点类型（内容节点和概念节点）',
      '8 reference types for relationships': '8种关系引用类型',
      'Auto-layout algorithms': '自动布局算法',
      'Search and filter functionality': '搜索和过滤功能',

      // === 文档对话框 ===
      'Quick Start Guide': '快速入门指南',
      '1. Creating Nodes': '1. 创建节点',
      'Click the + button to create a new node': '点击 + 按钮创建新节点',
      'Choose between Content or Concept node type': '选择内容节点或概念节点类型',
      'Enter title and content': '输入标题和内容',
      '2. Connecting Nodes': '2. 连接节点',
      'Long press a node to open its menu': '长按节点打开菜单',
      'Select "Connect to..." to link nodes': '选择"连接到..."以链接节点',
      'Choose a reference type for the connection': '为连接选择引用类型',
      '3. Layout Options': '3. 布局选项',
      'Force Directed: Physics-based layout': '力导向：基于物理的布局',
      'Hierarchical: Tree-based layout': '层次：基于树的布局',
      'Circular: Circle arrangement': '环形：环形排列',
      'Concept Map: Concept-focused layout': '概念图：以概念为中心的布局',
      '4. Keyboard Shortcuts': '4. 键盘快捷键',
      'Ctrl+N: Create new node': 'Ctrl+N：创建新节点',
      'Ctrl+S: Save current node': 'Ctrl+S：保存当前节点',
      'Ctrl+F: Quick search': 'Ctrl+F：快速搜索',
      'Delete: Delete selected node': 'Delete：删除选中节点',

      // === 插件市场 ===
      'Markdown Enhancer': 'Markdown 增强器',
      'Enhanced markdown editing with advanced features': '具有高级功能的增强型 Markdown 编辑',
      'Mind Map': '思维导图',
      'Create mind maps from your nodes': '从您的节点创建思维导图',
      'Export Tools': '导出工具',
      'Additional export formats for your graphs': '为您的图表提供额外的导出格式',
      'Integrate AI capabilities into your workflow': '将 AI 功能集成到您的工作流中',
      'Theme Manager': '主题管理器',
      'Customize the appearance of your notebook': '自定义笔记本的外观',
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
