/// AI 面板命令（M7.3，判据①）：CreateAIPanelCommand —— 拖 AI 节点入
/// 侧边栏 = 钉「AI 对话」面板 tab。
///
/// 面板 = **L1 实例节点**（references {sidebar, ai}）——AIConcept 要求
/// references 为空（L0），AI 节点零变更；面板节点被 SidebarTabsView
/// 枚举（references.sidebar == root）自动成为侧边栏 tab。
library;

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';

/// 建 AI 面板命令。
class CreateAIPanelCommand extends Command<CreateAIPanelCommand> {
  /// 携带 AI 节点与侧边栏根容器。
  const CreateAIPanelCommand({
    required this.aiNodeId,
    required this.sidebarRootId,
  });

  /// AI 节点 id（kind == 'ai'）。
  final String aiNodeId;

  /// 侧边栏根容器 id（references.sidebar 指向）。
  final String sidebarRootId;

  @override
  String get name => 'ai.attach-panel';

  @override
  Map<String, dynamic> get payload => <String, dynamic>{
    'aiNodeId': aiNodeId,
    'sidebarRootId': sidebarRootId,
  };
}

/// 建面板写结果（structure → 侧边栏 tab 枚举重挂）。
class CreateAIPanelResult implements WriteResult {
  /// 携带面板节点 id。
  const CreateAIPanelResult({required this.panelId});

  /// 面板节点 id。
  final String panelId;

  @override
  Set<String> get affectedNodeIds => <String>{panelId};

  @override
  ChangeKind get changeKind => ChangeKind.structure;

  @override
  Command? get inverse => null;
}

/// 建面板 Handler（写操作唯一执行者）：
/// 1. 既有面板（ai + sidebar 匹配）→ 幂等返回
/// 2. 环校验（面板引用 {sidebar, ai}——L1 无环）
/// 3. 落盘 → structure 结果
class CreateAIPanelHandler
    extends CommandHandler<CreateAIPanelCommand, CreateAIPanelResult> {
  /// 注入结构存储（延迟解析）与环校验器。
  CreateAIPanelHandler({
    required Graph Function() graphProvider,
    AcyclicChecker? checker,
  }) : _graphProvider = graphProvider,
       _checker = checker ?? const AcyclicChecker();

  final Graph Function() _graphProvider;
  final AcyclicChecker _checker;

  @override
  Type get commandType => CreateAIPanelCommand;

  @override
  Future<CreateAIPanelResult> handle(CreateAIPanelCommand command) async {
    final graph = _graphProvider();
    // 幂等：同 AI 节点已有面板 → 复用（拖拽多次不重复钉）。
    final existing = graph
        .getAll()
        .where(
          (n) =>
              n.references['ai'] == command.aiNodeId &&
              n.references['sidebar'] != null,
        )
        .firstOrNull;
    if (existing != null) {
      return CreateAIPanelResult(panelId: existing.id);
    }
    final panelId = 'ai-panel-${command.aiNodeId}';
    final newRefs = <String, String>{
      'sidebar': command.sidebarRootId,
      'ai': command.aiNodeId,
    };
    // 环校验（双保险：drop 预判 + Handler 二次，00 §2.3 执行点）。
    final cycle = _checker.check(
      affectedRefs: <String, Set<String>>{panelId: newRefs.values.toSet()},
      graph: graph,
    );
    if (cycle != null) {
      throw CycleError(cycle);
    }
    final now = DateTime.now();
    graph.save(
      StoredNode(
        id: panelId,
        title: 'AI 对话',
        references: newRefs,
        metadata: const <String, dynamic>{'kind': 'ai-panel'},
        createdAt: now,
        updatedAt: now,
      ),
    );
    return CreateAIPanelResult(panelId: panelId);
  }
}
