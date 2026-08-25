/// 对话命令（M7 AI 插件，纯 DTO + Handler，03 §四）：
///
/// - **DropIntoAI**（拖笔记进 AI 节点）：创建/更新 chat 实例
///   （`{ai, source}`，同 contain 模式，01 拍板 #30）
/// - **AppendMessage**（快命令）：用户消息 append 到会话记录 → 写后通知
///   → UI 即时显示（01 拍板 #31：每条消息写 = 独立命令 + 独立通知）
/// - **AskAI**（长任务 Handler，03 §四）：读会话 + 笔记上下文 →
///   AIProvider 回复 → append 落盘（复用写路径，不阻塞 UI）
library;

import 'package:core/core.dart';

/// 拖笔记进 AI 节点命令（建立/更新对话会话）。
class DropIntoAICommand extends Command<DropIntoAICommand> {
  /// 携带目标 AI 节点与被拖入的笔记。
  const DropIntoAICommand({required this.aiNodeId, required this.sourceId});

  /// 目标 AI 节点（kind == 'ai'）。
  final String aiNodeId;

  /// 被拖入的笔记节点。
  final String sourceId;

  @override
  String get name => 'ai.drop';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'aiNodeId': aiNodeId,
    'sourceId': sourceId,
  };
}

/// 拖入写结果（structure：会话树重挂）。
class DropIntoAIResult implements WriteResult {
  /// 携带受影响节点（chat 实例 + AI 节点）。
  const DropIntoAIResult({required this.affectedNodeIds});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  @override
  Command? get inverse => null; // M7 显式不可撤销（撤销契约 03 §四）。
}

/// 追加用户消息命令（快命令：落盘即通知，UI 即时显示）。
class AppendMessageCommand extends Command<AppendMessageCommand> {
  /// 携带会话与消息文本。
  const AppendMessageCommand({required this.chatId, required this.message});

  /// 会话实例 id。
  final String chatId;

  /// 用户消息文本。
  final String message;

  @override
  String get name => 'ai.append';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'chatId': chatId,
    'message': message,
  };
}

/// 追加写结果（data：消息重绘粒度）。
class AppendMessageResult implements WriteResult {
  /// 携带受影响节点（chat 实例）。
  const AppendMessageResult({required this.affectedNodeIds});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.data;

  // R3c 不可撤销理由：消息追加 = 会话 content data 写，对偶需"删除某条
  // 消息"命令（词表不存在——会话写入单向追加）——显式不可撤销
  // （docs/review 总览 P0-3 / audit-node_ai #2）。
  @override
  Command? get inverse => null;
}

/// AI 回复命令（长任务 Handler：provider 调用期间不阻塞 UI——
/// Mock/HTTP 均 async；结果走写路径落盘，03 §四）。
class AskAICommand extends Command<AskAICommand> {
  /// 携带会话 id。
  const AskAICommand({required this.chatId});

  /// 会话实例 id。
  final String chatId;

  @override
  String get name => 'ai.ask';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{'chatId': chatId};
}

/// AI 回复写结果（data：消息重绘粒度；affected = chat + source）。
class AskAIResult implements WriteResult {
  /// 携带受影响节点（chat 实例）。
  const AskAIResult({required this.affectedNodeIds});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.data;

  // R3c 不可撤销理由：AskAI = 长任务回复落盘（会话 content 追加），对偶需
  // "回滚会话整轮回复"命令（词表不存在）——显式不可撤销
  // （docs/review 总览 P0-3 / audit-node_ai #2）。
  @override
  Command? get inverse => null;
}
