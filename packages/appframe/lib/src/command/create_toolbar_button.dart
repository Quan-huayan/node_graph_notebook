/// CreateToolbarButtonCommand —— 拖拽建工具栏按钮（M7.3，判据①）。
///
/// Flowing UI 语义："节点拖到工具栏 = 成为工具栏按钮（点击打开该
/// 节点）"。按钮 = 节点（All is Node）：新建 `kind == 'toolbar'`
/// 节点，metadata `{icon, tooltip, action: 'node.open', target:
/// sourceId}`——ToolbarHook 点击查 registry 的 targeted 动作
/// （'node.open' = 打开目标节点对话框，宿主级注册）。
///
/// 目标节点零变更（AI 等 L0 节点 references 不被污染）；已存在按钮
/// → 幂等更新 tooltip。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

import '../store/stored_node.dart';

/// 建工具栏按钮命令。
class CreateToolbarButtonCommand extends Command<CreateToolbarButtonCommand> {
  /// 携带源节点（拖入工具栏的节点）。
  const CreateToolbarButtonCommand({required this.sourceId});

  /// 源节点（按钮点击打开它）。
  final String sourceId;

  @override
  String get name => 'toolbar.create';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{'sourceId': sourceId};
}

/// 建按钮写结果（structure → 工具栏容器重挂枚举）。
class CreateToolbarButtonResult implements WriteResult {
  /// 携带按钮节点 id。
  const CreateToolbarButtonResult({required this.buttonId});

  /// 按钮节点 id。
  final String buttonId;

  @override
  Set<String> get affectedNodeIds => <String>{buttonId};

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  // 不可撤销理由（R3c，docs/review 总览 P0-3 / audit-appframe #5）：
  // 工具栏按钮 = UI 代理节点（M7.3"拖到工具栏 = 建打开该节点的按钮"），
  // 幂等创建/更新（tooltip 跟随源标题）。删除按钮本身有独立对偶
  // （DeleteNodeCommand 级联），本命令的"创建"语义被幂等覆盖写——
  // 构造对逆命令需"按钮是否已存在"的历史判定，超出本命令契约范围；
  // 显式声明不可撤销（03 §四：不可撤销写必须注明理由）。
  @override
  Command? get inverse => null;
}

/// 建按钮 Handler（写操作唯一执行者）。
class CreateToolbarButtonHandler
    extends
        CommandHandler<CreateToolbarButtonCommand, CreateToolbarButtonResult> {
  /// 注入结构存储（延迟解析）。
  CreateToolbarButtonHandler({required Graph Function() graphProvider})
    : _graphProvider = graphProvider;

  final Graph Function() _graphProvider;

  @override
  Type get commandType => CreateToolbarButtonCommand;

  @override
  Future<CreateToolbarButtonResult> handle(
    CreateToolbarButtonCommand command,
  ) async {
    final graph = _graphProvider();
    final source = graph.get(command.sourceId);
    if (source == null) {
      throw StateError('源节点不存在: ${command.sourceId}');
    }
    final buttonId = 'toolbar-open-${command.sourceId}';
    // 幂等：已存在 → 更新 tooltip（标题变更跟随），其余不变。
    final existing = graph.get(buttonId);
    final isAi = source.metadata['kind'] == 'ai';
    final metadata = <String, dynamic>{
      'kind': 'toolbar',
      'icon': isAi ? 'smart_toy' : 'open_in_new',
      'tooltip': source.title,
      'action': 'node.open',
      'target': command.sourceId,
    };
    if (existing != null) {
      graph.save(existing.copyWith(metadata: metadata));
    } else {
      graph.save(
        StoredNode(
          id: buttonId,
          title: source.title,
          metadata: metadata,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
    return CreateToolbarButtonResult(buttonId: buttonId);
  }
}
