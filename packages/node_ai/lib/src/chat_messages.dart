/// 对话消息序列化（01 拍板 #30）：消息历史 = chat 实例的 content
/// markdown——对话记录本身是文本，可被编辑器/git 管理（00 §3.2）。
///
/// 格式（可读、可 diff、可外部编辑）：
/// ```markdown
/// ## 对话（与「第一篇笔记」）
///
/// **用户**: 问题一
///
/// **AI**: 回答一
/// ```
library;

/// 消息角色（序列化前缀）。
enum ChatRole {
  /// 用户消息。
  user,

  /// AI 回复。
  ai,
}

/// 单条消息（解析后的呈现单元）。
class ChatMessage {
  /// 构造消息。
  const ChatMessage({required this.role, required this.text});

  /// 消息角色。
  final ChatRole role;

  /// 消息文本（原始 markdown 段落，不含前缀）。
  final String text;
}

/// 用户消息行前缀。
const String userMarker = '**用户**';

/// AI 回复行前缀。
const String aiMarker = '**AI**';

/// 追加一条消息到会话记录（返回新 content；空记录带头部）。
///
/// [chatTitle] 会话标题（消息记录头部展示）。
String appendMessage({
  required String? content,
  required ChatRole role,
  required String text,
  required String chatTitle,
}) {
  final buffer = StringBuffer();
  if (content != null && content.trim().isNotEmpty) {
    buffer
      ..writeln(content.trim())
      ..writeln();
  } else {
    buffer
      ..writeln('## 对话（与「$chatTitle」）')
      ..writeln();
  }
  buffer
    ..writeln('${_marker(role)}: ${text.trim()}')
    ..writeln();
  return buffer.toString().trim();
}

/// 解析会话记录为消息列表（按行前缀切分，抗外部编辑）。
///
/// 无法识别的行（如手工编辑的文本）被合并进前一条消息——
/// 解析绝不崩溃（对话记录是用户数据）。
List<ChatMessage> parseMessages(String? content) {
  if (content == null || content.trim().isEmpty) {
    return <ChatMessage>[];
  }
  final messages = <ChatMessage>[];
  ChatMessage? current;
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    if (trimmed.startsWith('$userMarker:')) {
      current = ChatMessage(
        role: ChatRole.user,
        text: trimmed.substring(userMarker.length + 1).trim(),
      );
      messages.add(current);
    } else if (trimmed.startsWith('$aiMarker:')) {
      current = ChatMessage(
        role: ChatRole.ai,
        text: trimmed.substring(aiMarker.length + 1).trim(),
      );
      messages.add(current);
    } else if (current != null && !trimmed.startsWith('## ')) {
      // 续行（手工换行的消息体）合并进当前消息。
      current = ChatMessage(
        role: current.role,
        text: '${current.text}\n$trimmed',
      );
      messages[messages.length - 1] = current;
    }
  }
  return messages;
}

String _marker(ChatRole role) => role == ChatRole.user ? userMarker : aiMarker;
