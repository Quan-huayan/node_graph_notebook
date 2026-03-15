import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/plugin/dependency_container.dart';

// 测试服务
class TestService {
  String get message => 'Test service';
}

// 测试服务接口
abstract class TestServiceInterface {
  String get message;
}

// 测试服务实现
class TestServiceImpl implements TestServiceInterface {
  @override
  String get message => 'Test service implementation';
}

void main() {
  late DependencyContainer container;

  setUp(() {
    container = DependencyContainer();
  });

  test('should register and get dependency', () {
    final service = TestService();
    container.register<TestService>(service);

    final retrievedService = container.get<TestService>();
    expect(retrievedService, equals(service));
  });

  test('should throw exception for unregistered dependency', () {
    expect(() => container.get<TestService>(), throwsA(isA<DependencyNotFoundException>()));
  });

  test('should register and get dependency via factory', () {
    container.registerFactory<TestService>(
      (container) => TestService(),
    );

    final service1 = container.get<TestService>();
    final service2 = container.get<TestService>();
    expect(service1, isA<TestService>());
    expect(service1, equals(service2)); // 应该是同一个实例
  });

  test('should check if dependency exists', () {
    final service = TestService();
    container.register<TestService>(service);

    expect(container.contains<TestService>(), isTrue);
    expect(container.contains<TestServiceImpl>(), isFalse);
  });

  test('should unregister dependency', () {
    final service = TestService();
    container.register<TestService>(service);

    expect(container.contains<TestService>(), isTrue);

    container.unregister<TestService>();
    expect(container.contains<TestService>(), isFalse);
  });

  test('should clear all dependencies', () {
    final service = TestService();
    container.register<TestService>(service);
    container.registerFactory<TestServiceImpl>(
      (container) => TestServiceImpl(),
    );

    expect(container.contains<TestService>(), isTrue);
    expect(container.contains<TestServiceImpl>(), isTrue);

    container.clear();
    expect(container.contains<TestService>(), isFalse);
    expect(container.contains<TestServiceImpl>(), isFalse);
  });

  test('should register and get dependency with interface', () {
    final service = TestServiceImpl();
    container.register<TestServiceInterface>(service);

    final retrievedService = container.get<TestServiceInterface>();
    expect(retrievedService, equals(service));
    expect(retrievedService.message, equals('Test service implementation'));
  });
}
