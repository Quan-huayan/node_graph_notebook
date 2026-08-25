/// FolderPlugin —— 文件夹容器插件（M6 试金石，04 里程碑）。
///
/// 贡献：FolderConcept（容器判定）+ MoveNodesHandler（双写命令）。
/// 浓缩全部争议：UI 结构持久化（投影不变式）、侧边栏拖拽=数据命令
/// （三档判据）、环校验（拖 A 进 A 的后代）。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:plugon/plugon.dart';

import 'src/contain_concept.dart';
import 'src/folder_concept.dart';
import 'src/folder_create.dart';
import 'src/move_nodes.dart';

/// 文件夹插件。
class FolderPlugin extends Plugin {
  /// 插件实例。
  ///
  /// [servicesProvider] 宿主注入的**最新** provider 解析入口（M7 修正：
  /// plugon loadPlugin 会 dispose 旧 provider——onLoad 快照在多插件场景
  /// 失效；缺省 = onLoad 快照，兼容单插件测试）。注入见
  /// `HostRuntime.serviceProvider`。
  FolderPlugin({ServiceProvider Function()? servicesProvider})
    : _servicesProvider = servicesProvider;

  final ServiceProvider Function()? _servicesProvider;

  ServiceProvider? _snapshot;

  /// 服务解析：宿主入口（运行时最新）优先；缺省回退 onLoad 快照。
  // R13 豁免注释（docs/review 总览 P1-5 裁决）：生产路径永远经宿主注入的
  // servicesProvider 运行时求值（01 #47）；快照仅单插件测试兜底，非生产装配依赖。
  ServiceProvider get _provider => _servicesProvider?.call() ?? _snapshot!;

  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'com.example.folder',
    name: '文件夹插件',
    version: '1.0.0',
  );

  @override
  Future<void> onLoad(PluginContext context) async {
    // 快照兜底（单插件测试）；多插件场景由宿主注入最新 provider 入口。
    // R13 豁免注释（docs/review 总览 P1-5 裁决）：生产路径永远经宿主注入的
    // servicesProvider 运行时求值（01 #47）；快照仅单插件测试兜底，非生产装配依赖。
    _snapshot = context.services;
  }

  @override
  void registerExtensions(ExtensionRegistry registry) {
    // folder（L0）与 contain 关系（L1）两个 Concept。
    registry.addContribution(
      conceptPoint,
      const FolderConcept(),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      conceptPoint,
      const ContainConcept(),
      ownerPluginId: metadata.id,
    );
    registry.addContribution(
      commandHandlerPoint,
      MoveNodesHandler(graphProvider: () => _provider.get<Graph>()),
      ownerPluginId: metadata.id,
    );
    // P1-2：移动撤销的对偶 Handler（取消包含——恢复"无归属"状态）。
    registry.addContribution(
      commandHandlerPoint,
      UncontainHandler(graphProvider: () => _provider.get<Graph>()),
      ownerPluginId: metadata.id,
    );
    // B3：文件夹内新建（组合写 = 新笔记 + contain 实例；对偶撤销 =
    // DeleteNodeCommand 级联——一步撤销链闭合）。
    registry.addContribution(
      commandHandlerPoint,
      CreateNodeInFolderHandler(graphProvider: () => _provider.get<Graph>()),
      ownerPluginId: metadata.id,
    );
  }
}
