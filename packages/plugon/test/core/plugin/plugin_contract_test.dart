import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/core/di.dart';
import 'package:plugon/core/extensions.dart';
import 'package:plugon/core/plugin.dart';

class _EchoService {
  _EchoService(this.message);
  final String message;
}

class _OtherService {}

class _MinimalPlugin extends Plugin {
  _MinimalPlugin(this._metadata);

  final PluginMetadata _metadata;

  @override
  PluginMetadata get metadata => _metadata;
}

class _RegisteringPlugin extends Plugin {
  _RegisteringPlugin(this._metadata);

  final PluginMetadata _metadata;

  @override
  PluginMetadata get metadata => _metadata;

  @override
  void registerServices(ServiceCollection services) {
    services.addSingleton<_EchoService>((sp) => _EchoService('from-plugin'));
  }

  @override
  void registerExtensions(ExtensionRegistry registry) {
    registry.registerExtensionPoint(const ExtensionPoint<String>('mine'));
    registry.addContribution(
      const ExtensionPoint<String>('mine'),
      'contribution',
      ownerPluginId: metadata.id,
    );
  }
}

PluginContext _context(String pluginId, ServiceProvider services) =>
    PluginContext(
      pluginId: pluginId,
      metadata: PluginMetadata(id: pluginId, name: pluginId, version: '1.0.0'),
      services: services,
      extensions: ExtensionRegistry(),
    );

void main() {
  group('Plugin 契约', () {
    test('默认生命周期回调为空实现（可调用且不抛错）', () async {
      final plugin = _MinimalPlugin(
        const PluginMetadata(id: 'm', name: 'M', version: '1.0.0'),
      );
      final collection = ServiceCollection();
      final context = _context('m', collection.build());

      await plugin.onLoad(context);
      await plugin.onEnable();
      await plugin.onDisable();
      await plugin.onUnload();
    });

    test('metadata 支持 const 构造，依赖默认空、默认启用', () {
      const m = PluginMetadata(id: 'a', name: 'A', version: '1.0.0');
      expect(m.dependencies, isEmpty);
      expect(m.enabledByDefault, isTrue);
    });

    test('PluginContext.get 委托 provider；未注册抛 ServiceNotFoundException', () {
      final collection = ServiceCollection();
      collection.addSingleton<_EchoService>((sp) => _EchoService('hi'));
      final context = _context('p1', collection.build());

      expect(context.get<_EchoService>().message, 'hi');
      expect(context.tryGet<_EchoService>()?.message, 'hi');
      expect(
        () => context.get<_OtherService>(),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('context.pluginId 与 metadata.id 一致', () {
      final collection = ServiceCollection();
      final context = _context('p1', collection.build());
      expect(context.pluginId, context.metadata.id);
    });

    test('插件在 registerServices 中通过 owned 视图注册服务（owner 自动盖章）', () {
      final collection = ServiceCollection();
      final plugin = _RegisteringPlugin(
        const PluginMetadata(id: 'rp', name: 'RP', version: '1.0.0'),
      );

      plugin.registerServices(collection.owned('rp'));

      expect(collection.descriptors.single.owner, 'rp');
    });

    test('插件可在 registerExtensions 中注册扩展点与贡献', () {
      final registry = ExtensionRegistry();
      final plugin = _RegisteringPlugin(
        const PluginMetadata(id: 'rp', name: 'RP', version: '1.0.0'),
      );

      plugin.registerExtensions(registry);

      expect(registry.getAll(const ExtensionPoint<String>('mine')), [
        'contribution',
      ]);
    });
  });
}
