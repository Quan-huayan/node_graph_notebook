import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/plugon_flutter.dart';
import 'package:provider/provider.dart';

class _TrackingNotifier extends ChangeNotifier {
  _TrackingNotifier([this.value = 0]);
  int value;
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class _PlainService {
  _PlainService(this.value);
  int value;
}

class _HostService {
  _HostService();
}

/// 通过 flutter 扩展注册 notifier 的插件。
class _NotifierPlugin extends Plugin {
  _NotifierPlugin(this.notifier);

  final _TrackingNotifier notifier;

  @override
  PluginMetadata get metadata =>
      const PluginMetadata(id: 'np', name: 'NP', version: '1.0.0');

  @override
  void registerServices(ServiceCollection services) {
    services.addNotifier(notifier); // owner 由 owned 视图自动盖章
  }
}

void main() {
  group('Provider 适配', () {
    test('addNotifier（实例）→ ChangeNotifierProvider', () {
      final collection = ServiceCollection();
      collection.addNotifier<_TrackingNotifier>(
        _TrackingNotifier(7),
        owner: 'p1',
      );
      final provider = collection.build();

      final providers = buildProviders(provider);

      expect(
        providers.single,
        isA<ChangeNotifierProvider<_TrackingNotifier>>(),
      );
    });

    test('addValue（普通实例）→ Provider', () {
      final collection = ServiceCollection();
      collection.addValue<_PlainService>(_PlainService(1));
      final provider = collection.build();

      final providers = buildProviders(provider);

      expect(providers.single, isA<Provider<_PlainService>>());
    });

    test('addFactory 懒实例化——buildProviders 调用不触发工厂', () {
      var created = 0;
      final collection = ServiceCollection();
      collection.addFactory<_PlainService>((sp) {
        created++;
        return _PlainService(1);
      });
      final provider = collection.build();

      buildProviders(provider);

      expect(created, 0, reason: 'create: 风格的 provider 在 widget 挂载时才实例化');
    });

    testWidgets('树中解析到的实例与 DI 单例一致，且跨 buildProviders 调用稳定', (tester) async {
      final collection = ServiceCollection();
      collection.addFactory<_PlainService>((sp) => _PlainService(1));
      final provider = collection.build();

      _PlainService? captured;
      Widget tree() => MultiProvider(
        providers: buildProviders(provider),
        child: Builder(
          builder: (context) {
            captured = context.read<_PlainService>();
            return const SizedBox();
          },
        ),
      );

      await tester.pumpWidget(tree());
      final first = captured!;
      expect(
        first,
        same(provider.get<_PlainService>()),
        reason: 'widget 树解析的正是 DI 单例',
      );

      await tester.pumpWidget(tree());
      expect(captured, same(first), reason: '重复构建仍包装同一实例');
    });

    test('activeOwners 过滤禁用插件的 provider，宿主服务始终保留', () {
      final collection = ServiceCollection();
      collection.addNotifier(_TrackingNotifier(1), owner: 'p1');
      collection.addValue(_PlainService(2), owner: 'p2');
      collection.addValue(_HostService()); // 宿主所有
      final provider = collection.build();

      final providers = buildProviders(provider, activeOwners: {'p1'});

      expect(providers.length, 2, reason: 'p2 被过滤，宿主保留');
    });

    testWidgets('MultiProvider 树中可通过 context.watch 解析服务', (tester) async {
      final collection = ServiceCollection();
      collection.addNotifier(_TrackingNotifier(42));
      final provider = collection.build();

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: buildProviders(provider),
            child: Builder(
              builder: (context) {
                final n = context.watch<_TrackingNotifier>();
                return Text('value=${n.value}');
              },
            ),
          ),
        ),
      );

      expect(find.text('value=42'), findsOneWidget);
    });

    test('插件卸载时 DI 关闭其拥有的 notifier 单例（修复 disposeOwner 语义）', () async {
      final notifier = _TrackingNotifier();
      final collection = ServiceCollection();
      final manager = PluginManager(services: collection);
      await manager.loadPlugin(_NotifierPlugin(notifier));

      manager.services.get<_TrackingNotifier>();
      await manager.unloadPlugin('np');

      expect(
        notifier.disposed,
        isTrue,
        reason: 'addNotifier 注册时挂 onDispose，卸载由 DI 关闭',
      );
      expect(manager.services.tryGet<_TrackingNotifier>(), isNull);
    });
  });
}
