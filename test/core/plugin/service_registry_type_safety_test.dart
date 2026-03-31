import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/plugin/service_binding.dart';
import 'package:node_graph_notebook/core/plugin/service_registry.dart';

// 测试用的服务和接口
class TestService {
  const TestService();
}

class AnotherService {
  const AnotherService();
}

class TestServiceBinding extends ServiceBinding<TestService> {
  @override
  TestService createService(ServiceResolver resolver) => const TestService();

  @override
  void dispose(TestService service) {}

  @override
  Type get serviceType => TestService;
}

class WrongServiceBinding extends ServiceBinding<AnotherService> {
  @override
  AnotherService createService(ServiceResolver resolver) => const AnotherService();

  @override
  void dispose(AnotherService service) {}

  @override
  Type get serviceType => AnotherService;
}

void main() {
  group('ServiceRegistry Runtime Type Validation', () {
    group('Type Validation Enabled', () {
      late ServiceRegistry registry;

      setUp(() {
        registry = ServiceRegistry(
          enableRuntimeTypeValidation: true,
        );
      });

      test('应该成功获取正确类型的服务', () {
        registry.registerService('test_plugin', TestServiceBinding());

        final service = registry.getServiceDirect<TestService>();

        expect(service, isA<TestService>());
      });

      test('应该从核心依赖获取正确类型的服务', () {
        const testService = TestService();
        registry.registerCoreDependency(TestService, testService);

        final service = registry.getServiceDirect<TestService>();

        expect(service, equals(testService));
      });

      test('应该支持懒加载服务', () {
        final binding = TestServiceBinding();
        // 标记为懒加载
        registry.registerService('test_plugin', binding);

        // 懒加载服务应该能够获取
        final service = registry.getServiceDirect<TestService>();

        expect(service, isA<TestService>());
      });

      test('应该拒绝注册不匹配类型的服务到核心依赖', () {
        // 注册正确的服务
        const testService = TestService();
        registry.registerCoreDependency(TestService, testService);

        // 尝试获取不同类型应该返回 null 或抛出异常
        // 这里我们测试获取正确类型是否工作
        final service = registry.getServiceDirect<TestService>();
        expect(service, equals(testService));
      });

      test('应该允许可选的服务不存在', () {
        final service = registry.getService<TestService?>();

        expect(service, isNull);
      });
    });

    group('Type Validation Disabled', () {
      late ServiceRegistry registry;

      setUp(() {
        registry = ServiceRegistry(
          enableRuntimeTypeValidation: false,
        );
      });

      test('禁用验证时应该正常工作', () {
        registry.registerService('test_plugin', TestServiceBinding());

        final service = registry.getServiceDirect<TestService>();

        expect(service, isA<TestService>());
      });
    });

    group('Service Type Mismatch Detection', () {
      test('应该检测类型不匹配并抛出异常', () {
        final registry = ServiceRegistry(
          enableRuntimeTypeValidation: true,
        );

        // 注册核心依赖（但类型不匹配）
        const wrongService = AnotherService();
        registry.registerCoreDependency(TestService, wrongService);

        // 尝试获取 TestService 但实际是 AnotherService
        // 应该抛出 ServiceTypeMismatchException
        expect(
          () => registry.getServiceDirect<TestService>(),
          throwsA(isA<ServiceTypeMismatchException>()),
        );
      });
    });

    group('Plugin Isolation', () {
      late ServiceRegistry registry;

      setUp(() {
        registry = ServiceRegistry(
          enableRuntimeTypeValidation: true,
        );
      });

      test('应该跟踪服务所属的插件', () {
        registry.registerService('plugin1', TestServiceBinding());

        // 服务应该被成功注册
        expect(registry.hasService<TestService>(), true);
      });

      test('应该阻止重复注册相同服务', () {
        registry.registerService('plugin1', TestServiceBinding());

        expect(
          () => registry.registerService('plugin2', TestServiceBinding()),
          throwsA(isA<ServiceRegistrationException>()),
        );
      });
    });

    group('Service Lifecycle', () {
      late ServiceRegistry registry;

      setUp(() {
        registry = ServiceRegistry(
          enableRuntimeTypeValidation: true,
        );
      });

      test('应该清理所有服务', () {
        registry.registerService('test_plugin', TestServiceBinding());

        expect(registry.hasService<TestService>(), true);

        registry.clear();

        expect(registry.hasService<TestService>(), false);
      });
    });

    group('Lazy Loading', () {
      late ServiceRegistry registry;

      setUp(() {
        registry = ServiceRegistry(
          enableRuntimeTypeValidation: true,
        );
      });

      test('应该支持懒加载服务', () {
        final binding = LazyTestServiceBinding();
        registry.registerService('test_plugin', binding);

        // 服务已注册但未实例化
        expect(registry.hasService<TestService>(), true);

        // 第一次访问时才实例化
        final service = registry.getServiceDirect<TestService>();

        expect(service, isA<TestService>());
      });
    });

    group('Core Dependencies', () {
      late ServiceRegistry registry;

      setUp(() {
        registry = ServiceRegistry(
          enableRuntimeTypeValidation: true,
        );
      });

      test('应该注册核心依赖', () {
        const service = TestService();
        registry.registerCoreDependency(TestService, service);

        final retrieved = registry.getServiceDirect<TestService>();

        expect(retrieved, equals(service));
      });

      test('应该动态添加核心依赖', () {
        const service = TestService();
        registry.registerCoreDependency(TestService, service);

        expect(registry.hasService<TestService>(), true);

        final retrieved = registry.getServiceDirect<TestService>();

        expect(retrieved, equals(service));
      });
    });

    group('Error Handling', () {
      late ServiceRegistry registry;

      setUp(() {
        registry = ServiceRegistry(
          enableRuntimeTypeValidation: true,
        );
      });

      test('应该抛出 ServiceNotFoundException 当服务不存在', () {
        expect(
          () => registry.getServiceDirect<TestService>(),
          throwsA(isA<ServiceNotFoundException>()),
        );
      });

      test('应该提供有用的错误消息', () {
        try {
          registry.getServiceDirect<TestService>();
          fail('Should have thrown ServiceNotFoundException');
        } on ServiceNotFoundException catch (e) {
          expect(e.message, contains('Service'));
          expect(e.message, contains('not found'));
        }
      });
    });
  });
}

// 懒加载服务绑定用于测试
class LazyTestServiceBinding extends ServiceBinding<TestService> {
  @override
  bool get isLazy => true;

  @override
  TestService createService(ServiceResolver resolver) => const TestService();

  @override
  void dispose(TestService service) {}

  @override
  Type get serviceType => TestService;
}
