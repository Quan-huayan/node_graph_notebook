/// EditorPlugin —— Markdown 编辑器插件（M7 修正，Hook 承载 UI）。
///
/// 贡献：NoteConcept（普通笔记归属——点击笔记 = 渲染其 Hook = 编辑器
/// 视图）+ SaveNoteHandler（写命令——保存 = 写路径，03 §四）。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:plugon/plugon.dart';

import 'src/editor_concept.dart';
import 'src/save_note.dart';

/// 编辑器插件。
class EditorPlugin extends Plugin {
  /// 插件实例。
  ///
  /// [servicesProvider] 宿主最新 provider 入口（M7 修正，见
  /// HostRuntime.serviceProvider；缺省 = onLoad 快照，兼容单插件测试）。
  EditorPlugin({ServiceProvider Function()? servicesProvider})
    : _servicesProvider = servicesProvider;

  final ServiceProvider Function()? _servicesProvider;

  ServiceProvider? _snapshot;

  /// 服务解析：宿主入口（运行时最新）优先；缺省回退 onLoad 快照。
  ServiceProvider get _services => _servicesProvider?.call() ?? _snapshot!;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.editor',
    name: '编辑器插件',
    version: '1.0.0',
  );

  @override
  Future<void> onLoad(PluginContext context) async {
    // R13 豁免注释（docs/review 总览 P1-5 裁决）：生产路径永远经宿主注入的
    // servicesProvider 运行时求值（01 #47）；快照仅单插件测试兜底，非生产
    // 装配依赖。
    _snapshot = context.services;
  }

  @override
  void registerExtensions(ExtensionRegistry registry) {
    registry.addContribution(
      conceptPoint,
      const NoteConcept(),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      SaveNoteHandler(graphProvider: () => _services.get<Graph>()),
      ownerPluginId: metadata.id,
    );
  }
}
