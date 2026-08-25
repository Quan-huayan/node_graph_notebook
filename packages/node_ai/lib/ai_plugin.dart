/// AiPlugin —— AI 集成插件（M7 杀手演示，01 拍板 #30-32）。
///
/// 贡献：AIConcept（L0 容器）+ ChatConcept（L1 会话实例）+
/// DropIntoAIHandler / AppendMessageHandler / AskAIHandler（写命令）。
/// 服务：AIProvider（plugon DI 注册，默认 Mock——按 archive/ai 方式，
/// 01 拍板 #31；OpenAI key 配置留 settings 迭代）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:plugon/plugon.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/ai_concept.dart';
import 'src/ai_panel_commands.dart';
import 'src/ai_panel_concept.dart';
import 'src/ai_provider.dart';
import 'src/ai_provider_config.dart';
import 'src/ai_settings.dart';
import 'src/chat_commands.dart';
import 'src/chat_concept.dart';
import 'src/chat_handlers.dart';
import 'src/function_calling/ai_tool.dart';
import 'src/function_calling/ai_tool_registry.dart';
import 'src/function_calling/tools/connect_nodes_tool.dart';
import 'src/function_calling/tools/create_node_tool.dart';
import 'src/function_calling/tools/delete_node_tool.dart';
import 'src/function_calling/tools/list_nodes_tool.dart';
import 'src/function_calling/tools/search_nodes_tool.dart';
import 'src/function_calling/tools/update_node_tool.dart';

/// AI 插件。
class AiPlugin extends Plugin {
  /// 插件实例。
  ///
  /// [servicesProvider] 宿主注入的**最新** provider 解析入口（M7 修正：
  /// plugon loadPlugin 会 dispose 旧 provider——onLoad 快照在多插件场景
  /// 失效；缺省 = onLoad 快照，兼容单插件测试）。注入见
  /// `HostRuntime.serviceProvider`。
  /// [prefs] 设置持久化（P1-1：app 层注入，AIProviderConfig 读回上次
  /// key/model/baseUrl 并自动保存；null = 纯内存）。
  AiPlugin({
    AIProvider? provider,
    ServiceProvider Function()? servicesProvider,
    SharedPreferences? prefs,
  }) : _provider = provider,
       _servicesProvider = servicesProvider,
       _prefs = prefs;

  final AIProvider? _provider;
  final ServiceProvider Function()? _servicesProvider;
  final SharedPreferences? _prefs;

  ServiceProvider? _snapshot;

  /// 服务解析：宿主入口（运行时最新）优先；缺省回退 onLoad 快照。
  ServiceProvider get _services => _servicesProvider?.call() ?? _snapshot!;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.ai',
    name: 'AI 插件',
    version: '1.0.0',
  );

  @override
  Future<void> onLoad(PluginContext context) async {
    // R13 豁免注释（docs/review 总览 P1-5 裁决）：生产路径永远经宿主注入
    // 的 servicesProvider 运行时求值（01 #47）；快照仅单插件测试兜底，
    // 非生产装配依赖。
    _snapshot = context.services;
  }

  @override
  void registerServices(ServiceCollection services) {
    // LLM 后端（01 拍板 #31）：AIProvider 作为插件服务注册。
    // M7.2 阶段 C（AI key 设置恢复）：默认经 ConfigAIProvider——
    // 设置表单改 key 即时生效（空 key = Mock，非空 = OpenAI）。
    services
      ..addSingleton<AIProviderConfig>(
        // P1-1：factory 内 attach（每次装配新 provider 时绑定持久化——
        // 多仓库切换新建实例同样恢复上次配置）。
        (sp) => AIProviderConfig()..attach(_prefs),
      )
      ..addSingleton<AIProvider>(
        (sp) => _provider ?? ConfigAIProvider(sp.get<AIProviderConfig>()),
      )
      // M7.3（Function Calling）：工具注册表服务——factory 内预装内置
      // 工具（节点操作经 CommandBus dispatch 判据①）。预装在 factory
      // 而非 onLoad：plugon 每次 loadPlugin 重建 provider——onLoad 的
      // 副作用（注册工具）在重建后丢失，factory 每次构建都带工具。
      ..addSingleton<AIToolRegistry>(
        (sp) => AIToolRegistry()
          ..registerTools(<AITool>[
            const CreateNodeTool(),
            const UpdateNodeTool(),
            const DeleteNodeTool(),
            const ConnectNodesTool(),
            const ListNodesTool(),
            const SearchNodesTool(),
          ], pluginId: 'com.example.ai'),
      )
      // M7.3（Flowing UI 语义分发）：拖 AI 节点入侧边栏 = 钉「AI 对话」
      // 面板 tab（last-wins 覆盖宿主缺省 folder 语义；非 AI 节点 → null
      // 走默认）。graph 经闭包运行时解析（provider 每次构建）。
      ..addSingleton<SidebarDropSemantics>(
        (sp) => ({required draggedNodeId, required targetContainerId}) {
          final graph = sp.get<Graph>();
          final dragged = graph.get(draggedNodeId);
          if (dragged != null && const AIConcept().validate(dragged)) {
            return CreateAIPanelCommand(
              aiNodeId: draggedNodeId,
              sidebarRootId: targetContainerId,
            );
          }
          return null;
        },
      )
      // M8（组合根回调移除，01 拍板 #32 反转）：画布卡片拖入语义
      // last-wins 覆盖——**目标 = AI 节点 → DropIntoAICommand**（数据
      // 命令，判据① 建/更新会话）；非 AI 目标 → null（宿主缺省 =
      // 画布默认连接语义）。判定归系统（语义服务家族），app 组合根
      // 不再注入回调（消灭"每加一个跨插件交互就往 app 顶层加回调"）。
      ..addSingleton<CanvasCardDropSemantics>(
        (sp) => ({required draggedId, required targetId}) {
          final graph = sp.get<Graph>();
          final target = graph.get(targetId);
          if (target != null && const AIConcept().validate(target)) {
            return DropIntoAICommand(aiNodeId: targetId, sourceId: draggedId);
          }
          return null;
        },
      );
  }

  @override
  void registerExtensions(ExtensionRegistry registry) {
    registry.addContribution(
      conceptPoint,
      const AIConcept(),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      conceptPoint,
      // M7.2 阶段 C：AI 设置条目（聚合归设置容器，references 反查）。
      const AISettingsConcept(),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      conceptPoint,
      const ChatConcept(),
      ownerPluginId: metadata.id,
    );
    // M7.3：AI 侧边栏面板（references {sidebar, ai}，L1 实例）。
    registry.addContribution(
      conceptPoint,
      const AIPanelConcept(),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      DropIntoAIHandler(graphProvider: () => _services.get<Graph>()),
      ownerPluginId: metadata.id,
    );
    // M7.3：钉面板命令（拖 AI 节点入侧边栏，判据①）。
    registry.addContribution(
      commandHandlerPoint,
      CreateAIPanelHandler(graphProvider: () => _services.get<Graph>()),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      AppendMessageHandler(graphProvider: () => _services.get<Graph>()),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      AskAIHandler(
        graphProvider: () => _services.get<Graph>(),
        providerProvider: () => _services.get<AIProvider>(),
        // M7.3（Function Calling）：工具注册表 + 命令总线（工具经
        // dispatch 执行写操作，判据①）。
        toolRegistryProvider: () => _services.get<AIToolRegistry>(),
        commandBusProvider: () => _services.get<CommandBus>(),
      ),
      ownerPluginId: metadata.id,
    );
  }
}
