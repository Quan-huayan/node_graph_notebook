/// CanvasConcept —— 画布容器（M6 graph 插件，00 杀手演示"拖上画布→图节点"）。
///
/// 画布成员 = **外观位置**（判据②，01 拍板 M6 回填）：节点有
/// `position.graph.<nodeId>` 键（UIStateStore）才显示在画布上——
/// 拖上画布 = 位置直写，无任何结构写入（投影不变式 4.1）。
///
/// 识别 = 结构匹配：`metadata['kind'] == 'canvas'`（00 不变量 4.3-1）。
/// 画布自身是 L0-node（references 恒空）；成员不是 references 关系。
///
/// M7 修正（Hook 承载 UI）：CanvasHook.render 挂载 GraphCanvas——
/// 画布 UI 在 graph 插件内，打开/拖入语义经 FlutterRenderContext 的
/// 组装回调（app 零 UI，插件互相不依赖）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';

import 'canvas_widget.dart';

/// 画布 Concept（L0 容器）。
class CanvasConcept extends Concept {
  /// 无状态容器（可 const 装配）。
  const CanvasConcept();

  @override
  String get id => 'com.example.graph:canvas';

  @override
  String get name => '画布';

  @override
  String get description => '画布容器（成员 = 外观位置，拖入 = UIMove 直写）';

  /// L0：画布自身不引用任何 Node（成员由 UIStateStore 位置决定）。
  @override
  Set<String> get slots => const <String>{};

  @override
  Set<String> get requiredSlots => const <String>{};

  @override
  Map<String, MetadataField> get metadataSchema =>
      const <String, MetadataField>{
        'kind': MetadataField(name: 'kind', type: MetadataType.string),
      };

  @override
  Set<String> get requiredMetadataKeys => const <String>{'kind'};

  @override
  ContentRequirement get contentRequirement => ContentRequirement.none;

  @override
  bool validate(Node node) => node.metadata['kind'] == 'canvas';

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('画布实例由种子/导入流程创建');
  }

  @override
  Hook createHook(Node instance, HookContext context) =>
      CanvasHook(nodeId: instance.id, hookId: '${instance.id}@${context.kind}');

  @override
  DropSemantics askDropSemantics(Node node) =>
      // 容器判定（01-C / 03 §三）：接收 = 外观位置直写（判据②）。
      // 判定契约；真实落点坐标由画布宿主写入（askDropSemantics 无坐标载荷）。
      UIMove(canvasPositionKey(node.id), <String, dynamic>{'x': 0, 'y': 0});
}

/// 画布 Hook（容器视图面：drop 判定目标 + 相机键身份）。
class CanvasHook extends Hook {
  /// 画布容器 Hook。
  const CanvasHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    // M7 修正（Hook 承载 UI）：挂载画布（GraphCanvas）——画布 UI 在
    // graph 插件内；打开/拖入语义经渲染上下文的组装回调。
    // 非 Flutter 渲染目标（测试/其他后端）→ 静默（Hook 位置无关）。
    if (context is! FlutterRenderContext) {
      return;
    }
    final flutterContext = context;
    final host = flutterContext.host;
    final sink = flutterContext.sink;
    if (host == null || sink == null) {
      return; // 测试环境：无宿主/收集器 → 不渲染。
    }
    sink.add(GraphCanvas(host: host, onCardDrop: flutterContext.onCardDrop));
  }
}
