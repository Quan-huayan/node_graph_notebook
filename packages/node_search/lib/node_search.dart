/// node_search —— 搜索插件（M7，01 拍板 #36）。
///
/// 标题/内容包含匹配（大小写不敏感）——纯查询服务（读侧，02 §1.5：
/// 读优化归实现层，不引入总线抽象）。服务经 plugon DI 注册。
library;

export 'search_plugin.dart';
export 'src/search_panel.dart';
export 'src/search_service.dart';
export 'src/tags_panel.dart';
