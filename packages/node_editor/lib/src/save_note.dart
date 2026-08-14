/// SaveNoteCommand —— 笔记保存命令（M7 editor 插件，纯 DTO + Handler）。
///
/// 编辑保存 = 写路径（00 不变量 4.4-1：Hook/UI 不直接写 Graph）——
/// 对话框收集表单 → dispatch → Handler copyWith 落盘 → 写后通知 →
/// 画布/侧边栏重渲染。与 graph 插件的 UpdateNodeCommand 语义等价，
/// 但属本插件自有（plugins 互相不依赖，04 §三 约束 3）。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

/// 保存笔记命令。
class SaveNoteCommand extends Command<SaveNoteCommand> {
  /// 携带目标与变更字段（null = 不变）。
  const SaveNoteCommand({required this.nodeId, this.title, this.content});

  /// 目标节点。
  final String nodeId;

  /// 新标题（null = 不变）。
  final String? title;

  /// 新内容（null = 不变）。
  final String? content;

  @override
  String get name => 'editor.save';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'nodeId': nodeId,
    'title': title,
    'content': content,
  };
}

/// 保存写结果（data：重绘粒度）。
class SaveNoteResult implements WriteResult {
  /// 携带受影响节点与对偶命令（P1-2：撤销 = 恢复旧标题/内容）。
  const SaveNoteResult({required this.affectedNodeIds, this.inverse});

  @override
  final Set<String> affectedNodeIds;

  @override
  ChangeKind get changeKind => ChangeKind.data;

  @override
  final Command? inverse;
}

/// 保存 Handler（写操作唯一执行者，01-D）。
class SaveNoteHandler extends CommandHandler<SaveNoteCommand, SaveNoteResult> {
  /// [graphProvider] 延迟解析结构存储。
  SaveNoteHandler({required Graph Function() graphProvider})
    : _graphProvider = graphProvider;

  final Graph Function() _graphProvider;

  @override
  Type get commandType => SaveNoteCommand;

  @override
  Future<SaveNoteResult> handle(SaveNoteCommand command) async {
    final graph = _graphProvider();
    final node = graph.get(command.nodeId);
    if (node == null) {
      throw StateError('节点不存在: ${command.nodeId}');
    }
    // P1-2：落盘前捕获旧值（对偶命令 = 恢复旧标题/内容）。
    final previousTitle = node.title;
    final previousContent = node.content;
    graph.save(node.copyWith(title: command.title, content: command.content));
    return SaveNoteResult(
      affectedNodeIds: <String>{command.nodeId},
      inverse: SaveNoteCommand(
        nodeId: command.nodeId,
        title: previousTitle,
        content: previousContent,
      ),
    );
  }
}
