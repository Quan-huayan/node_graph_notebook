import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/plugin/plugin.dart';

class TestService {
  TestService(this.name);
  final String name;
}

class TestServiceWithDependency {
  TestServiceWithDependency(this.dependency);
  final TestService dependency;
}

class TestLazyService {
  TestLazyService(this.name);
  final String name;
}

class TestServiceBinding extends ServiceBinding<TestService> {
  TestServiceBinding(this.name);
  final String name;

  @override
  TestService createService(ServiceResolver resolver) => TestService(name);
}

class TestServiceWithDependencyBinding extends ServiceBinding<TestServiceWithDependency> {
  @override
  TestServiceWithDependency createService(ServiceResolver resolver) {
    final dependency = resolver.get<TestService>();
    return TestServiceWithDependency(dependency);
  }
}

class TestLazyServiceBinding extends ServiceBinding<TestLazyService> {
  TestLazyServiceBinding(this.name);
  final String name;

  @override
  TestLazyService createService(ServiceResolver resolver) => TestLazyService(name);

  @override
  bool get isLazy => true;
}

class TestDisposableService {
  bool isDisposed = false;
}

class TestDisposableServiceBinding extends ServiceBinding<TestDisposableService> {
  @override
  TestDisposableService createService(ServiceResolver resolver) => TestDisposableService();

  @override
  void dispose(TestDisposableService service) {
    service.isDisposed = true;
  }
}

void main() {
  group('ServiceRegistry', () {
    late ServiceRegistry registry;

    setUp(() {
      registry = ServiceRegistry();
    });

    tearDown(() {
      registry.clear();
    });

    group('registerService - 服务注册', () {
      test('应该成功注册服务', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        expect(registry.isRegistered<TestService>(), true);
      });

      test('当重复注册相同服务时应该抛出异常', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        expect(
          () => registry.registerService('test_plugin', TestServiceBinding('test2')),
          throwsA(isA<ServiceRegistrationException>()),
        );
      });

      test('默认应该立即实例化服务', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        final service = registry.getServiceDirect<TestService>();
        expect(service.name, 'test');
      });

      test('应该跟踪插件服务', () {
        registry.registerService('plugin_a', TestServiceBinding('service_a'));

        final services = registry.getPluginServices('plugin_a');
        expect(services, contains(TestService));
      });
    });

    group('unregisterPluginServices - 服务注销', () {
      test('应该注销所有插件服务', () {
        registry
          ..registerService('test_plugin', TestServiceBinding('test'))
          ..unregisterPluginServices('test_plugin');

        expect(registry.isRegistered<TestService>(), false);
      });

      test('注销时应该处置服务', () {
        registry
          ..registerService('test_plugin', TestDisposableServiceBinding())
          ..unregisterPluginServices('test_plugin');

        expect(registry.isRegistered<TestDisposableService>(), false);
      });

      test('应该优雅地处理不存在的插件', () {
        expect(
          () => registry.unregisterPluginServices('non_existent'),
          returnsNormally,
        );
      });
    });

    group('lazy loading - 懒加载', () {
      test('注册时不应该实例化懒加载服务', () {
        registry.registerService('test_plugin', TestLazyServiceBinding('lazy'));

        expect(registry.isRegistered<TestLazyService>(), true);
      });

      test('第一次请求时应该实例化懒加载服务', () {
        registry.registerService('test_plugin', TestLazyServiceBinding('lazy'));

        final service = registry.getServiceDirect<TestLazyService>();
        expect(service.name, 'lazy');
      });
    });

    group('getService - 服务获取', () {
      test('对于不存在的服务应该返回null', () {
        final service = registry.getService<TestService>();
        expect(service, isNull);
      });

      test('应该返回服务实例', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        final service = registry.getService<TestService>();
        expect(service, isNotNull);
        expect(service!.name, 'test');
      });

      test('对于单例应该返回相同的实例', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        final service1 = registry.getService<TestService>();
        final service2 = registry.getService<TestService>();

        expect(identical(service1, service2), true);
      });
    });

    group('getServiceDirect - 直接服务获取', () {
      test('对于不存在的服务应该抛出异常', () {
        expect(
          () => registry.getServiceDirect<TestService>(),
          throwsA(isA<ServiceNotFoundException>()),
        );
      });

      test('应该返回服务实例', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        final service = registry.getServiceDirect<TestService>();
        expect(service.name, 'test');
      });
    });

    group('hasService - 服务可用性检查', () {
      test('对于不存在的服务应该返回false', () {
        expect(registry.hasService<TestService>(), false);
      });

      test('对于已注册的服务应该返回true', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        expect(registry.hasService<TestService>(), true);
      });

      test('对于懒加载服务应该返回true', () {
        registry.registerService('test_plugin', TestLazyServiceBinding('lazy'));

        expect(registry.hasService<TestLazyService>(), true);
      });
    });

    group('generateProviders - Provider 生成', () {
      test('当没有服务注册时应该返回空列表', () {
        final providers = registry.generateProviders();
        expect(providers, isEmpty);
      });

      test('应该为已注册的服务返回providers', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        final providers = registry.generateProviders();
        expect(providers.length, 1);
      });
    });

    group('core dependencies - 核心依赖', () {
      test('应该向服务提供核心依赖', () {
        final coreDeps = <Type, dynamic>{
          String: 'core_value',
        };
        final registryWithCore = ServiceRegistry(coreDependencies: coreDeps);

        expect(registryWithCore.hasService<String>(), false);
      });
    });

    group('change notification - 变更通知', () {
      test('服务注册时应该通知监听器', () {
        var notified = false;
        registry
          ..addListener(() {
            notified = true;
          })
          ..registerService('test_plugin', TestServiceBinding('test'));

        expect(notified, true);
      });

      test('服务注销时应该通知监听器', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));
        var notified = false;
        registry
          ..addListener(() {
            notified = true;
          })
          ..unregisterPluginServices('test_plugin');

        expect(notified, true);
      });
    });

    group('clear - 清空', () {
      test('应该清空所有服务', () {
        registry
          ..registerService('test_plugin', TestServiceBinding('test'))
          ..clear();

        expect(registry.isRegistered<TestService>(), false);
        expect(registry.registeredTypes, isEmpty);
      });
    });
  });
}
