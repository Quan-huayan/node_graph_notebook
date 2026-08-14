/// 核心模块导出
///
/// 提供应用程序的核心功能和框架抽象
library;

// 命令系统
export 'cqrs/commands/command_bus.dart';
// 事件系统
export 'cqrs/commands/events/app_events.dart';
export 'cqrs/commands/models/command_context.dart';
export 'cqrs/commands/models/command_handler.dart';
export 'cqrs/commands/models/middleware.dart';
export 'cqrs/handlers/advanced_search_handler.dart';
export 'cqrs/handlers/get_current_graph_handler.dart';
export 'cqrs/handlers/graph_query_handler.dart';
export 'cqrs/handlers/list_nodes_handler.dart';
export 'cqrs/handlers/load_graph_handler.dart';
export 'cqrs/handlers/load_node_handler.dart';
export 'cqrs/handlers/load_nodes_by_ids_handler.dart';
export 'cqrs/handlers/search_index_handler.dart';
export 'cqrs/handlers/search_nodes_handler.dart';
// CQRS 查询系统
export 'cqrs/materialized_views/search_index_view.dart';
export 'cqrs/queries/advanced_search_query.dart';
export 'cqrs/queries/get_current_graph_query.dart';
export 'cqrs/queries/graph_query.dart';
export 'cqrs/queries/list_nodes_query.dart';
export 'cqrs/queries/load_graph_query.dart';
export 'cqrs/queries/load_node_query.dart';
export 'cqrs/queries/load_nodes_by_ids_query.dart';
export 'cqrs/queries/search_index_query.dart';
export 'cqrs/queries/search_nodes_query.dart';
export 'cqrs/query/query.dart';
export 'cqrs/query/query_bus.dart';
export 'cqrs/read_models/node_read_model.dart';
// 执行系统
export 'execution/cpu_task.dart';
export 'execution/execution_engine.dart';
export 'execution/gpu_executor.dart';
export 'execution/task_registry.dart';
// 图数据结构
export 'graph/adjacency_list.dart';
export 'infrastructure/i18n.dart';
export 'infrastructure/settings_registry.dart';
export 'infrastructure/theme_registry.dart';
// 中间件
export 'middleware/middleware.dart';
// 核心模型
export 'models/models.dart';
// UI 布局服务
export 'plugin/hook/ui_layout_service.dart';
// 插件系统
export 'plugin/plugin.dart';
// Old plugin_context / plugin_manager deleted — now in packages/plugin/
// 数据访问
export 'repositories/repositories.dart';
// 公开工具类
export 'utils/files.dart';
export 'utils/logger.dart';
export 'utils/safe_callback.dart';
