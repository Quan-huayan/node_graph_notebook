/// M5 插件化契约测试（04 §1.1/§1.4/§1.5）：
/// 扩展点贡献 → 查询侧派生 → 降级渲染联动（§5.4）。
library;

import 'package:core/core.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/plugon.dart';

import 'support/in_memory_graph.dart';
import 'support/recording.dart';

void main() {
  group('插件扩展点（04 §1.1）', () {
    test('Concept 贡献 → findFor 匹配；禁用 → 兜底（零同步降级）', () {
      final extensions = ExtensionRegistry()
        ..registerExtensionPoint(conceptPoint);
      final folder = RecordingConcept(id: 'folder', matchNodeIds: const {'n1'});
      extensions.addContribution(
        conceptPoint,
        folder,
        ownerPluginId: 'plugin-a',
      );
      extensions.setPluginActive('plugin-a', true);
      final registry = PluginConceptRegistry(extensions: extensions);

      // 活跃：命中 folder。
      expect(registry.findFor(_node('n1')).id, 'folder');
      expect(registry.findFor(_node('other')).id, fallbackConceptId);

      // 禁用：贡献停用 → 无命中 → 兜底（00 不变量 4.3-3 永不空洞）。
      extensions.setPluginActive('plugin-a', false);
      expect(registry.findFor(_node('n1')), same(registry.fallback));
    });

    test('卸载 → removeOwner 清除贡献（owner 清理自动）', () {
      final extensions = ExtensionRegistry()
        ..registerExtensionPoint(conceptPoint);
      extensions.addContribution(
        conceptPoint,
        RecordingConcept(id: 'a', matchNodeIds: const {'n1'}),
        ownerPluginId: 'plugin-a',
      );
      extensions.setPluginActive('plugin-a', true);
      final registry = PluginConceptRegistry(extensions: extensions);

      extensions.removeOwner('plugin-a');

      expect(registry.findFor(_node('n1')), same(registry.fallback));
      expect(extensions.hasContributions(conceptPoint), isFalse);
    });

    test('CommandHandler 扩展点贡献 → dispatch 路由', () async {
      final extensions = ExtensionRegistry()
        ..registerExtensionPoint(commandHandlerPoint);
      final bus = PluginCommandBus(extensions: extensions);
      final handler = _RecordingHandler();
      extensions.addContribution(
        commandHandlerPoint,
        handler,
        ownerPluginId: 'plugin-a',
      );
      extensions.setPluginActive('plugin-a', true);

      final result = await bus.dispatch<_TestCommand, _TestResult>(
        const _TestCommand(),
      );

      expect(handler.handleCount, 1);
      expect(result.changeKind, ChangeKind.data);
    });

    test('禁用插件 → 其 Handler 不再路由（快速失败 StateError）', () async {
      final extensions = ExtensionRegistry()
        ..registerExtensionPoint(commandHandlerPoint);
      final bus = PluginCommandBus(extensions: extensions);
      extensions.addContribution(
        commandHandlerPoint,
        _RecordingHandler(),
        ownerPluginId: 'plugin-a',
      );
      extensions.setPluginActive('plugin-a', true);
      extensions.setPluginActive('plugin-a', false);

      expect(
        () => bus.dispatch<_TestCommand, _TestResult>(const _TestCommand()),
        throwsA(isA<StateError>()),
      );
    });

    test('§5.4 端到端：禁用 → onConceptsChanged → 物化 Hook 兜底重物化', () {
      final graph = InMemoryGraph()..save(_node('n1'));
      final extensions = ExtensionRegistry()
        ..registerExtensionPoint(conceptPoint);
      final folder = RecordingConcept(id: 'folder', matchNodeIds: const {'n1'});
      extensions.addContribution(
        conceptPoint,
        folder,
        ownerPluginId: 'plugin-a',
      );
      extensions.setPluginActive('plugin-a', true);

      final index = HookIndex();
      final window = WindowManagerImpl();
      final manager = WindowedUIManager(
        graph: graph,
        concepts: PluginConceptRegistry(extensions: extensions),
        index: index,
        window: window,
        materializer: MaterializerImpl(
          graph: graph,
          concepts: PluginConceptRegistry(extensions: extensions),
          window: window,
          index: index,
          renderRoot: TestRenderContext(),
        ),
        query: FixedViewportQuery(const <String>['n1']),
      );
      manager.onViewportChanged(
        const ValueRect(x: 0, y: 0, width: 10, height: 10),
      );
      expect(folder.created, hasLength(1)); // folder Hook 已物化。

      // 禁用插件 → 降级联动（宿主在 setPluginActive 后调用）。
      extensions.setPluginActive('plugin-a', false);
      manager.onConceptsChanged();

      // 兜底重物化：新 Hook 是 FallbackHook（普通笔记，永不空洞）。
      expect(manager.window.isMaterialized('n1'), isTrue);
      expect(manager.window.hookOf(index.hookIds.first), isA<FallbackHook>());
    });
  });
}

Node _node(String id) => TestNode(id: id, title: '节点 $id');

class _TestCommand extends Command<_TestCommand> {
  const _TestCommand();

  @override
  String get name => 'test';

  @override
  Map<String, dynamic> get payload => const <String, dynamic>{};
}

class _TestResult implements WriteResult {
  const _TestResult();

  @override
  Set<String> get affectedNodeIds => const <String>{'n1'};

  @override
  ChangeKind get changeKind => ChangeKind.data;

  @override
  Command? get inverse => null;
}

class _RecordingHandler extends CommandHandler<_TestCommand, _TestResult> {
  int handleCount = 0;

  @override
  Future<_TestResult> handle(_TestCommand command) async {
    handleCount++;
    return const _TestResult();
  }

  @override
  Type get commandType => _TestCommand;
}
