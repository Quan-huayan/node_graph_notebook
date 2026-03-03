# Node Graph Notebook

一个基于概念地图的可视化笔记应用，采用 Flutter 框架开发，支持 Markdown 编辑、AI 辅助生成、插件扩展等功能。

## ✨ 核心特性

### 1. 统一节点模型
- **一切皆节点**：内容节点、概念节点（关系即节点）统一为 Node 模型
- **灵活连接**：支持单向、双向、分类、层级等多种关系类型
- **概念地图**：将关系本身也视为节点，支持高阶关系

### 2. Markdown ↔ 节点转换
- **智能导入**：将 Markdown 文件自动拆分为节点
- **灵活导出**：将节点图合并为 Markdown 文档
- **拆分策略**：按标题、分割符、AI 智能、自定义正则
- **自动提取**：识别 `[[wiki_links]]`、`#tags`、Frontmatter

### 3. AI 辅助功能
- **内容生成**：根据提示自动生成节点内容
- **关系推荐**：智能分析并推荐节点间的连接
- **概念提取**：识别高阶关系，创建概念节点
- **智能问答**：基于笔记内容回答问题
- **多 AI 支持**：OpenAI GPT、Anthropic Claude、本地 Ollama

### 4. 可视化节点图
- **Flame 引擎**：流畅的 2D 交互体验
- **自由布局**：拖拽节点到任意位置
- **自动布局**：力导向、层级、环形、概念地图布局
- **视图切换**：普通图、概念地图、混合模式

### 5. 插件系统（类 Obsidian）
- **完整 API**：访问节点、图、AI、UI 等功能
- **事件钩子**：生命周期、事件、数据、UI 钩子
- **权限管理**：安全的插件沙箱隔离
- **易于开发**：清晰的插件接口和示例

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- 开发平台：Windows / macOS / Linux / Android / iOS

### 安装

```bash
# 克隆项目
git clone https://github.com/yourusername/node_graph_notebook.git
cd node_graph_notebook

# 安装依赖
flutter pub get

# 运行应用
flutter run
```

### 配置

首次运行会创建 `data/` 目录结构：

```
data/
├── nodes/          # 节点 Markdown 文件
├── graphs/         # 图结构 JSON
├── plugins/        # 插件目录
└── settings/       # 应用设置
```

## 📖 使用指南

### 创建节点

1. 右键点击空白区域 → "新建节点"
2. 输入标题和内容
3. 支持完整的 Markdown 语法

### 建立连接

1. 从节点边缘拖拽到另一个节点
2. 选择连接类型（单向、双向、分类等）
3. 可添加连接标签

### 转换 Markdown

1. 点击 "导入 Markdown"
2. 选择文件或目录
3. 配置拆分规则
4. 自动创建节点和连接

### AI 生成

1. 打开 AI 助手面板
2. 输入提示词
3. 选择生成模式（节点、关系、概念）
4. 确认后自动创建

### 视图切换

- **普通图**：标准的节点-边图
- **概念地图**：关系作为节点显示
- **混合模式**：同时显示两种节点

## 🛠️ 开发

### 项目结构

```
lib/
├── core/              # 核心模块
│   ├── models/        # 数据模型
│   ├── repositories/  # 数据访问
│   └── services/      # 业务逻辑
├── converter/         # Markdown 转换
├── ai/                # AI 功能
├── flame/             # Flame 渲染
├── plugins/           # 插件系统
├── ui/                # UI 界面
└── utils/             # 工具类
```

### 运行测试

```bash
# 单元测试
flutter test test/unit/

# Widget 测试
flutter test test/widget/

# 集成测试
flutter test integration_test/
```

### 代码生成

```bash
# JSON 序列化代码
flutter pub run build_runner build
```

### 代码格式化

```bash
# 格式化所有代码
dart format .

# 检查格式
dart format --output=none --set-exit-if-changed .
```

## 📚 文档

- [系统架构](docs/architecture/system_architecture.md)
- [数据模型](docs/architecture/data_model.md)
- [API 设计](docs/architecture/api_design.md)
- [编码规范](docs/architecture/coding_standards.md)
- [转换功能](docs/features/converter_feature.md)
- [AI 功能](docs/features/ai_feature.md)

## 🔌 插件开发

### 快速示例

```dart
import 'package:node_graph_notebook/plugins/plugin_api.dart';

class MyPlugin extends Plugin {
  @override
  String get id => 'my-plugin';
  String get name => 'My Plugin';
  String get version => '1.0.0';

  @override
  void onLoad(PluginAPI api) {
    // 监听节点创建事件
    api.events.onNodeCreate.listen((node) {
      print('Node created: ${node.title}');
    });

    // 注册命令
    api.ui.registerCommand(PluginCommand(
      id: 'my-command',
      name: 'My Command',
      callback: () => print('Command executed'),
    ));
  }
}
```

### 插件清单

```json
{
  "id": "my-plugin",
  "name": "My Plugin",
  "version": "1.0.0",
  "main": "my_plugin.dart",
  "permissions": ["read:nodes", "write:nodes"],
  "commands": [
    {
      "id": "my-command",
      "name": "My Command"
    }
  ]
}
```

## 🤝 贡献

欢迎贡献！请遵循以下步骤：

1. Fork 项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

### 代码规范

- 遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart)
- 所有公共 API 需要文档注释
- 通过 `dart analyze` 和 `flutter test`
- 参考项目 [编码规范](docs/architecture/coding_standards.md)

## 📝 路线图

### v0.1.0 - MVP（已完成）✅
- ✅ 项目架构设计
- ✅ 完整数据模型
- ✅ 文档和配置
- ✅ 核心功能实现

**当前可用功能：**
- ✅ 节点创建（内容节点/概念节点）
- ✅ Markdown 编辑器和预览
- ✅ Flame 节点可视化
- ✅ 节点拖拽交互
- ✅ 节点连接管理
- ✅ 节点搜索（快速/高级）
- ✅ 自动布局算法
- ✅ 文件系统持久化
- ✅ Provider 状态管理

### v0.5.0 - 核心功能（开发中）
- ⏳ Markdown ↔ 节点转换
- ⏳ AI 内容生成
- ⏳ 撤销/重做
- ⏳ 导出功能（PDF/图片）
- ⏳ 键盘快捷键

### v1.0.0 - 完整功能
- ⏳ 插件系统
- ⏳ 云同步支持
- ⏳ 移动端适配
- ⏳ 完整测试覆盖

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🙏 致谢

- [Flutter](https://flutter.dev) - 跨平台 UI 框架
- [Flame](https://flame-engine.org) - Flutter 游戏引擎
- [flutter_markdown](https://pub.dev/packages/flutter_markdown) - Markdown 渲染
- [Obsidian](https://obsidian.md) - 灵感来源

## 📮 联系方式

- 项目主页：[GitHub](https://github.com/yourusername/node_graph_notebook)
- 问题反馈：[Issues](https://github.com/yourusername/node_graph_notebook/issues)
- 邮箱：your.email@example.com

---

**Node Graph Notebook** - 用概念地图重新思考笔记组织方式 🚀
