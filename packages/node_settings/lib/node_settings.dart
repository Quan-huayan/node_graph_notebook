/// node_settings —— 设置插件（M7，01 拍板 #39；M7.2 主题接线 +
/// 阶段 C 设置容器化）。
///
/// 设置容器节点（子级 = references.settings 反查——各插件贡献自己的
/// 设置条目与 Concept，聚合 = Hook Tree，零新机制）+ 主题条目
/// （编辑壳层 ThemeController，M7.2 E3：MaterialApp 即时响应）。
library;

export 'settings_plugin.dart';
export 'src/appearance_settings.dart';
export 'src/settings_container.dart';
export 'src/settings_entries_view.dart';
export 'src/theme_settings.dart';
export 'src/vault_settings.dart';
