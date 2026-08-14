/// node_ai —— AI 集成插件（M7 杀手演示，01 拍板 #30-32）。
///
/// 杀手演示（00）：把一篇笔记拖进 AI 节点——它重新解释自己的形态，
/// 变成一段对话。同一个数据实体在不同容器中流动并变形，全程无数据副本。
///
/// 模型（01 拍板 #30）：
/// - **AI 节点 = L0-node**（references 恒空，`metadata.kind == 'ai'`）
/// - **对话会话 = chat 实例（L1-node）**：`references = {ai, source}`
/// - **消息历史 = chat 实例 content**（markdown 序列化）
///
/// 发送 = 两命令拆分（#31）：AppendMessageCommand（快）+ AskAICommand
/// （长任务 Handler，03 §四：回复走写路径，不阻塞 UI）。
library;

export 'ai_plugin.dart';
export 'src/ai_card_view.dart';
export 'src/ai_chat_view.dart';
export 'src/ai_concept.dart';
export 'src/ai_panel_commands.dart';
export 'src/ai_panel_concept.dart';
export 'src/ai_provider.dart';
export 'src/ai_provider_config.dart';
export 'src/ai_settings.dart';
export 'src/chat_commands.dart';
export 'src/chat_concept.dart';
export 'src/chat_messages.dart';
export 'src/function_calling/ai_tool.dart';
export 'src/function_calling/ai_tool_parameter_validator.dart';
export 'src/function_calling/ai_tool_registry.dart';
export 'src/function_calling/function_calling_loop.dart';
export 'src/function_calling/tools/connect_nodes_tool.dart';
export 'src/function_calling/tools/create_node_tool.dart';
export 'src/function_calling/tools/delete_node_tool.dart';
export 'src/function_calling/tools/list_nodes_tool.dart';
export 'src/function_calling/tools/search_nodes_tool.dart';
export 'src/function_calling/tools/update_node_tool.dart';
