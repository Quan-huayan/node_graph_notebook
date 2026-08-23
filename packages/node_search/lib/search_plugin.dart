/// SearchPlugin —— 搜索插件（M7，01 拍板 #36；M7.2 侧边栏面板化）。
///
/// 注册 SearchService（plugon DI）+ SearchPanelConcept（kind ==
/// 'search-panel'，references.sidebar 指向侧边栏根——SidebarTabsView
/// 枚举，搜索面板在侧边栏，用户裁决：旧版搜索即在侧边栏）。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:plugon/plugon.dart';

import 'src/search_panel.dart';
import 'src/search_service.dart';
import 'src/tags_panel.dart';

/// 搜索插件。
class SearchPlugin extends Plugin {
  /// 插件实例（无状态）。
  SearchPlugin();

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.search',
    name: '搜索插件',
    version: '1.0.0',
  );

  @override
  void registerServices(ServiceCollection services) {
    // 依赖 Graph（宿主注册）——闭包延迟解析（registerServices 阶段
    // 无 provider，解析发生在插件加载完成后）。
    services.addSingleton<SearchService>(
      (sp) => SearchService(graph: sp.get<Graph>()),
    );
  }

  @override
  void registerExtensions(ExtensionRegistry registry) {
    // M7.2：搜索面板（侧边栏 Tab 子 Hook）。
    registry.addContribution(
      conceptPoint,
      const SearchPanelConcept(),
      ownerPluginId: metadata.id,
    );
    // A2：标签面板（kind 'tags-panel'——同 search-panel 的侧边栏 Tab 机制）。
    registry.addContribution(
      conceptPoint,
      const TagsPanelConcept(),
      ownerPluginId: metadata.id,
    );
  }
}
