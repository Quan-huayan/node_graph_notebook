/// HostRuntime 组合根测试（架构 §4 启动序列 / §5.4 降级联动）。
library;

import 'dart:io';

import 'package:appframe/appframe.dart';
import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/plugon.dart';

import 'support/in_memory_graph.dart';

/// 测试插件：贡献 folder Concept + 一个写命令。
class _FolderPlugin extends Plugin {
  _FolderPlugin({required this.concept});

  final _FolderConcept concept;

  @override
  PluginMetadata get metadata =>
      const PluginMetadata(id: 'test.folder', name: '测试文件夹', version: '1.0.0');

  @override
  void registerExtensions(ExtensionRegistry registry) {
    registry.addContribution(
      conceptPoint,
      concept,
      ownerPluginId: 'test.folder',
    );
    registry.addContribution(
      commandHandlerPoint,
      _CreateNodeHandler(),
      ownerPluginId: 'test.folder',
    );
  }
}

class _FolderConcept extends Concept {
  _FolderConcept({required this.matchNodeIds});

  final Set<String> matchNodeIds;

  @override
  String get id => 'test.folder';

  @override
  String get name => '文件夹';

  @override
  String get description => '测试文件夹容器';

  @override
  Set<String> get slots => const <String>{'children'};

  @override
  Set<String> get requiredSlots => const <String>{};

  @override
  Map<String, MetadataField> get metadataSchema =>
      const <String, MetadataField>{};

  @override
  Set<String> get requiredMetadataKeys => const <String>{};

  @override
  ContentRequirement get contentRequirement => ContentRequirement.optional;

  @override
  bool validate(Node node) => matchNodeIds.contains(node.id);

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('测试不创建实例');
  }

  @override
  Hook createHook(Node instance, HookContext context) => _FolderHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

class _FolderHook extends Hook {
  _FolderHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {}
}

class _CreateNodeCommand extends Command<_CreateNodeCommand> {
  const _CreateNodeCommand();

  @override
  String get name => 'test.create';

  @override
  Map<String, dynamic> get payload => const <String, dynamic>{};
}

class _CreateNodeResult implements WriteResult {
  const _CreateNodeResult();

  @override
  Set<String> get affectedNodeIds => const <String>{'created'};

  @override
  ChangeKind get changeKind => ChangeKind.data;

  @override
  Command? get inverse => null;
}

class _CreateNodeHandler
    extends CommandHandler<_CreateNodeCommand, _CreateNodeResult> {
  int handleCount = 0;

  @override
  Future<_CreateNodeResult> handle(_CreateNodeCommand command) async {
    handleCount++;
    return const _CreateNodeResult();
  }

  @override
  Type get commandType => _CreateNodeCommand;
}

void main() {
  group('HostRuntime（架构 §4 启动序列）', () {
    late Directory root;

    setUp(() {
      root = Directory.systemTemp.createTempSync('ngn_host');
      addTearDown(() {
        if (root.existsSync()) {
          root.deleteSync(recursive: true);
        }
      });
    });

    test('启动：插件加载 → 扩展注册 → 根物化（前端图建立）', () async {
      final host = HostRuntime(dataRoot: root, renderRoot: TestRenderContext());
      // 用 host.graph 落盘（真实 FSTGraph）；root 引用 folder1。
      host.graph.save(
        TestNode(
          id: 'root',
          title: '根',
          references: const <String, String>{'children': 'folder1'},
        ),
      );
      host.graph.save(TestNode(id: 'folder1', title: '文件夹1'));
      final folder = _FolderConcept(matchNodeIds: const {'root', 'folder1'});

      await host.start(
        plugins: <Plugin>[_FolderPlugin(concept: folder)],
        rootNodeId: 'root',
        rootKind: 'graph',
      );

      expect(host.started, isTrue);
      // 扩展贡献生效：findFor 匹配 folder。
      expect(host.concepts.findFor(host.graph.get('root')!).id, 'test.folder');
      // 前端图建立：根 + 子物化。
      expect(host.hookIndex.isMaterialized('root'), isTrue);
      expect(host.hookIndex.isMaterialized('folder1'), isTrue);
      expect(
        host.pluginManager.getPluginState('test.folder'),
        PluginState.enabled,
      );
    });

    test('插件贡献的 Handler 经扩展点路由', () async {
      final host = HostRuntime(dataRoot: root);
      final plugin = _FolderPlugin(
        concept: _FolderConcept(matchNodeIds: const {}),
      );
      await host.start(plugins: <Plugin>[plugin], rootNodeId: 'root');

      final result = await host.commandBus
          .dispatch<_CreateNodeCommand, _CreateNodeResult>(
            const _CreateNodeCommand(),
          );

      expect(result.changeKind, ChangeKind.data);
    });

    test('§5.4 降级：禁用插件 → 兜底重物化（永不空洞）', () async {
      final host = HostRuntime(dataRoot: root);
      host.graph.save(TestNode(id: 'root', title: '根'));
      final folder = _FolderConcept(matchNodeIds: const {'root'});

      await host.start(
        plugins: <Plugin>[_FolderPlugin(concept: folder)],
        rootNodeId: 'root',
      );

      await host.disablePlugin('test.folder');

      // 降级：findFor 无命中 → 兜底；物化 Hook 已重物化为 FallbackHook
      // （hookId 生成规则 nodeId@kind 不变，Hook 实例类型变化）。
      expect(
        host.concepts.findFor(host.graph.get('root')!),
        same(host.concepts.fallback),
      );
      expect(host.hookIndex.isMaterialized('root'), isTrue);
      expect(
        host.window.hookOf(host.hookIndex.hookIds.first),
        isA<FallbackHook>(),
      );
    });

    test('卸载插件 → removeOwner 清理（贡献消失）', () async {
      final host = HostRuntime(dataRoot: root);
      host.graph.save(TestNode(id: 'root', title: '根'));
      final folder = _FolderConcept(matchNodeIds: const {'root'});

      await host.start(
        plugins: <Plugin>[_FolderPlugin(concept: folder)],
        rootNodeId: 'root',
      );
      await host.unloadPlugin('test.folder');

      expect(
        host.concepts.findFor(host.graph.get('root')!),
        same(host.concepts.fallback),
      );
      // M7 修正：宿主贡献（ToolbarConcept，owner null）恒活跃——插件
      // 卸载只清理插件贡献，宿主级贡献不随插件消失。
      expect(
        host.extensions
            .getActive(conceptPoint)
            .any((c) => c.id == 'com.appframe:toolbar'),
        isTrue,
      );
      expect(
        host.extensions
            .getActive(conceptPoint)
            .any((c) => c.id == 'test.folder'),
        isFalse,
      );
    });
  });
}

/// 测试渲染目标（HostRuntime 注入）。
class TestRenderContext implements RenderContext {
  @override
  RenderContext createChildContext(Hook childHook) => TestRenderContext();
}
