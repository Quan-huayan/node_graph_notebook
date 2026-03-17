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
      test('should register service successfully', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        expect(registry.isRegistered<TestService>(), true);
      });

      test('should throw exception when registering same service twice', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        expect(
          () => registry.registerService('test_plugin', TestServiceBinding('test2')),
          throwsA(isA<ServiceRegistrationException>()),
        );
      });

      test('should instantiate service immediately by default', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        final service = registry.getServiceDirect<TestService>();
        expect(service.name, 'test');
      });

      test('should track plugin services', () {
        registry.registerService('plugin_a', TestServiceBinding('service_a'));

        final services = registry.getPluginServices('plugin_a');
        expect(services, contains(TestService));
      });
    });

    group('unregisterPluginServices - 服务注销', () {
      test('should unregister all plugin services', () {
        registry..registerService('test_plugin', TestServiceBinding('test'))

        ..unregisterPluginServices('test_plugin');

        expect(registry.isRegistered<TestService>(), false);
      });

      test('should dispose services when unregistering', () {
        registry..registerService('test_plugin', TestDisposableServiceBinding())

        ..unregisterPluginServices('test_plugin');

        expect(registry.isRegistered<TestDisposableService>(), false);
      });

      test('should handle non-existent plugin gracefully', () {
        expect(
          () => registry.unregisterPluginServices('non_existent'),
          returnsNormally,
        );
      });
    });

    group('lazy loading - 懒加载', () {
      test('should not instantiate lazy service on registration', () {
        registry.registerService('test_plugin', TestLazyServiceBinding('lazy'));

        expect(registry.isRegistered<TestLazyService>(), true);
      });

      test('should instantiate lazy service on first request', () {
        registry.registerService('test_plugin', TestLazyServiceBinding('lazy'));

        final service = registry.getServiceDirect<TestLazyService>();
        expect(service.name, 'lazy');
      });
    });

    group('getService - 服务获取', () {
      test('should return null for non-existent service', () {
        final service = registry.getService<TestService>();
        expect(service, isNull);
      });

      test('should return service instance', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        final service = registry.getService<TestService>();
        expect(service, isNotNull);
        expect(service!.name, 'test');
      });

      test('should return same instance for singleton', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        final service1 = registry.getService<TestService>();
        final service2 = registry.getService<TestService>();

        expect(identical(service1, service2), true);
      });
    });

    group('getServiceDirect - 直接服务获取', () {
      test('should throw exception for non-existent service', () {
        expect(
          () => registry.getServiceDirect<TestService>(),
          throwsA(isA<ServiceNotFoundException>()),
        );
      });

      test('should return service instance', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        final service = registry.getServiceDirect<TestService>();
        expect(service.name, 'test');
      });
    });

    group('hasService - 服务可用性检查', () {
      test('should return false for non-existent service', () {
        expect(registry.hasService<TestService>(), false);
      });

      test('should return true for registered service', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        expect(registry.hasService<TestService>(), true);
      });

      test('should return true for lazy service', () {
        registry.registerService('test_plugin', TestLazyServiceBinding('lazy'));

        expect(registry.hasService<TestLazyService>(), true);
      });
    });

    group('generateProviders - Provider 生成', () {
      test('should return empty list when no services registered', () {
        final providers = registry.generateProviders();
        expect(providers, isEmpty);
      });

      test('should return providers for registered services', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));

        final providers = registry.generateProviders();
        expect(providers.length, 1);
      });
    });

    group('core dependencies - 核心依赖', () {
      test('should provide core dependencies to services', () {
        final coreDeps = <Type, dynamic>{
          String: 'core_value',
        };
        final registryWithCore = ServiceRegistry(coreDependencies: coreDeps);

        expect(registryWithCore.hasService<String>(), false);
      });
    });

    group('change notification - 变更通知', () {
      test('should notify listeners on service registration', () {
        var notified = false;
        registry..addListener(() {
          notified = true;
        })

        ..registerService('test_plugin', TestServiceBinding('test'));

        expect(notified, true);
      });

      test('should notify listeners on service unregistration', () {
        registry.registerService('test_plugin', TestServiceBinding('test'));
        var notified = false;
        registry..addListener(() {
          notified = true;
        })

        ..unregisterPluginServices('test_plugin');

        expect(notified, true);
      });
    });

    group('clear - 清空', () {
      test('should clear all services', () {
        registry..registerService('test_plugin', TestServiceBinding('test'))

        ..clear();

        expect(registry.isRegistered<TestService>(), false);
        expect(registry.registeredTypes, isEmpty);
      });
    });
  });
}
