/// AIChatView —— 对话视图（M7 修正，Hook 承载 UI）。
///
/// AIHook.render 挂载本视图（kind = 'open'——点击 AI 节点 = 渲染其
/// Hook = 对话视图，00"拖进 AI 节点 → 变对话"的呈现）。**服务注入**
/// （graph/commandBus——不依赖组合根 host）；无对话框外壳（HookView
/// 的宿主提供容器）。发送 = 两命令拆分（01 拍板 #31：AppendMessage
/// 快命令 + AskAI 长任务）。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import 'ai_provider.dart';
import 'ai_provider_config.dart';
import 'chat_commands.dart';
import 'chat_concept.dart';
import 'chat_messages.dart';

/// 对话视图（消息列表 + 会话选择 + 输入框）。
class AIChatView extends StatefulWidget {
  /// 注入结构存储、命令总线、AI 节点、配置与国际化服务
  /// （服务注入，M7 修正；P0-4 增配置/i18n——Mock 状态明示 + 失败文案）。
  const AIChatView({
    super.key,
    required this.graph,
    required this.commandBus,
    required this.aiNodeId,
    required this.config,
    required this.i18n,
    this.padding = const EdgeInsets.all(16),
  });

  /// 结构存储。
  final Graph graph;

  /// 命令总线。
  final CommandBus commandBus;

  /// AI 节点 id（kind == 'ai'）。
  final String aiNodeId;

  /// LLM 后端配置（Mock 状态判定）。
  final AIProviderConfig config;

  /// 国际化服务（壳层文案）。
  final I18nService i18n;

  /// 内边距（宿主容器适配）。
  final EdgeInsets padding;

  @override
  State<AIChatView> createState() => _AIChatViewState();
}

class _AIChatViewState extends State<AIChatView> {
  final TextEditingController _input = TextEditingController();
  late final void Function(WriteResult) _onWrite;
  String? _selectedSourceId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 写后通知 → 刷新（消息落盘即重渲染；dispose 关闭，03 §五 硬规则）。
    _onWrite = (_) {
      if (mounted) {
        setState(() {});
      }
    };
    (widget.commandBus as WriteNotifier).attach(_onWrite);
  }

  @override
  void dispose() {
    (widget.commandBus as WriteNotifier).detach(_onWrite);
    _input.dispose();
    super.dispose();
  }

  /// 会话列表（读侧反查：references.ai == 本节点的 chat 实例的 source）。
  List<String> _sources() =>
      chatsOf(widget.graph, widget.aiNodeId).toList()..sort();

  @override
  Widget build(BuildContext context) {
    final sources = _sources();
    final selected = _selectedSourceId ?? sources.firstOrNull;
    return Padding(
      padding: widget.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sessionList(sources, selected),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null
                ? _emptyHint(context)
                : _conversation(context, selected),
          ),
        ],
      ),
    );
  }

  /// 会话列表（左侧）。
  Widget _sessionList(List<String> sources, String? selected) => SizedBox(
    width: 160,
    child: sources.isEmpty
        ? Center(
            child: Text(
              widget.i18n.t('ai.noSessions'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        : ListView(
            children: [
              for (final sourceId in sources)
                ListTile(
                  dense: true,
                  selected: sourceId == selected,
                  leading: const Icon(Icons.forum_outlined, size: 18),
                  title: Text(
                    widget.graph.get(sourceId)?.title ?? sourceId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => setState(() => _selectedSourceId = sourceId),
                ),
            ],
          ),
  );

  /// 空态提示（无会话：引导拖入）。
  Widget _emptyHint(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            widget.i18n.t('ai.dropHint'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 对话区（消息流 + 输入框）。
  Widget _conversation(BuildContext context, String sourceId) {
    final chat = chatOfSource(widget.graph, sourceId);
    final messages = chat == null
        ? <ChatMessage>[]
        : parseMessages(chat.content);
    final source = widget.graph.get(sourceId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            widget.i18n
                .t('ai.chatWith')
                .replaceFirst('%s', source?.title ?? sourceId),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const Divider(height: 1),
        // Mock 模式明示（P0-4）：未配置 key 时回复是演示内容——
        // 用户必须一眼知道"AI 没坏，是没配置"。
        if (widget.config.apiKey.isEmpty)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.i18n.t('ai.mockBanner'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: messages.isEmpty
              ? Center(
                  child: Text(
                    widget.i18n.t('ai.firstMessage'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    for (final message in messages)
                      _MessageBubble(
                        message: message,
                        i18n: widget.i18n,
                        color: message.role == ChatRole.user
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                        align: message.role == ChatRole.user
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                      ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  enabled: !_busy,
                  decoration: InputDecoration(
                    hintText: widget.i18n.t('ai.inputHint'),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _send(context),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : () => _send(context),
                child: Text(widget.i18n.t('ai.send')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 发送（01 拍板 #31 两命令拆分：快命令 + 长任务）。
  Future<void> _send(BuildContext context) async {
    // M7.3 修正：无会话时 _selectedSourceId 为空——旧代码先 `!` 解包
    // 再判空（"Null check operator used on a null value"——空会话 AI
    // 节点点发送即崩）。先判空再反查。
    final selected = _selectedSourceId;
    final chat = selected == null ? null : chatOfSource(widget.graph, selected);
    if (chat == null || _input.text.trim().isEmpty || _busy) {
      return;
    }
    final message = _input.text.trim();
    _input.clear();
    setState(() => _busy = true);
    try {
      await widget.commandBus
          .dispatch<AppendMessageCommand, AppendMessageResult>(
            AppendMessageCommand(chatId: chat.id, message: message),
          );
      // 长任务：AIProvider 回复 → 落盘 → 写后通知（复用写路径，03 §四）。
      await widget.commandBus.dispatch<AskAICommand, AskAIResult>(
        AskAICommand(chatId: chat.id),
      );
    } on AIProviderException catch (e) {
      // API 层错误（非 200 / 空 choices / 网络异常已由 OpenAIProvider
      // 包装为 AIProviderException——断网/DNS 不再静默）。
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.i18n.t('ai.failed').replaceFirst('%s', e.message),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${widget.i18n.t('ai.networkFailed')}（$error）',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

/// 消息气泡。
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.color,
    required this.align,
    required this.i18n,
  });

  final ChatMessage message;
  final Color color;
  final CrossAxisAlignment align;

  /// 国际化服务（气泡角色标签）。
  final I18nService i18n;

  @override
  Widget build(BuildContext context) {
    final label = message.role == ChatRole.user ? i18n.t('ai.you') : 'AI';
    return Align(
      alignment: align == CrossAxisAlignment.end
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: align,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 2),
            Text(message.text, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
