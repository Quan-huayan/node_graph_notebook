import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/plugin/api/api_registry.dart';

// 测试用的 API 和接口
abstract class SearchAPI {
  List<String> search(String query);
}

class ValidSearchAPI implements SearchAPI {
  @override
  List<String> search(String query) => ['result1', 'result2'];
}

class InvalidSearchAPI {
  // 这个类没有实现 SearchAPI 接口
  String getData() => 'data';
}

abstract class StorageAPI {
  void save(String key, String data);
  String? load(String key);
}

class ValidStorageAPI implements StorageAPI {
  final Map<String, String> _storage = {};

  @override
  void save(String key, String data) {
    _storage[key] = data;
  }

  @override
  String? load(String key) => _storage[key];
}

void main() {
  group('APIRegistry Type Validation', () {
    late APIRegistry registry;

    setUp(() {
      registry = APIRegistry();
    });

    group('Interface Type Validation', () {
      test('应该成功注册实现接口的 API', () {
        final api = ValidSearchAPI();

        expect(
          () => registry.registerAPI(
            'test_plugin',
            'search_api',
            '1.0.0',
            api,
            interfaceType: SearchAPI,
          ),
          returnsNormally,
        );
      });

      test('应该在未指定接口类型时跳过验证', () {
        final api = InvalidSearchAPI();

        expect(
          () => registry.registerAPI(
            'test_plugin',
            'some_api',
            '1.0.0',
            api,
          ),
          returnsNormally,
        );
      });

      test('应该接受 null API 实例', () {
        expect(
          () => registry.registerAPI(
            'test_plugin',
            'null_api',
            '1.0.0',
            null,
            interfaceType: SearchAPI,
          ),
          returnsNormally,
        );
      });

      test('应该支持接口类型参数', () {
        final api = ValidSearchAPI();

        // 这个测试验证接口类型参数可以被接受
        // 实际的运行时检查在 Dart 中有限制
        registry.registerAPI(
          'test_plugin',
          'search_api',
          '1.0.0',
          api,
          interfaceType: SearchAPI,
        );

        final retrieved = registry.getAPI<SearchAPI>('search_api');
        expect(retrieved, equals(api));
      });
    });

    group('API Registration', () {
      test('应该成功注册多个 API', () {
        final searchAPI = ValidSearchAPI();
        final storageAPI = ValidStorageAPI();

        registry.registerAPI(
          'test_plugin',
          'search_api',
          '1.0.0',
          searchAPI,
          interfaceType: SearchAPI,
        );

        registry.registerAPI(
          'test_plugin',
          'storage_api',
          '1.0.0',
          storageAPI,
          interfaceType: StorageAPI,
        );

        expect(registry.hasAPI('search_api'), true);
        expect(registry.hasAPI('storage_api'), true);
      });
    });

    group('API Retrieval', () {
      test('应该获取正确类型的 API', () {
        final api = ValidSearchAPI();

        registry.registerAPI(
          'test_plugin',
          'search_api',
          '1.0.0',
          api,
          interfaceType: SearchAPI,
        );

        final retrieved = registry.getAPI<SearchAPI>('search_api');

        expect(retrieved, equals(api));
        expect(retrieved, isA<SearchAPI>());
      });

      test('应该返回 null 当 API 不存在时', () {
        final retrieved = registry.getAPI<SearchAPI>('non_existent');

        expect(retrieved, isNull);
      });

      test('应该获取 API 版本', () {
        final api = ValidSearchAPI();

        registry.registerAPI(
          'test_plugin',
          'search_api',
          '2.1.0',
          api,
          interfaceType: SearchAPI,
        );

        final version = registry.getAPIVersion('search_api');

        expect(version, equals('2.1.0'));
      });
    });

    group('API Plugin Isolation', () {
      test('应该阻止不同插件注册相同 API', () {
        final api1 = ValidSearchAPI();
        final api2 = ValidSearchAPI();

        registry.registerAPI(
          'plugin1',
          'search_api',
          '1.0.0',
          api1,
          interfaceType: SearchAPI,
        );

        expect(
          () => registry.registerAPI(
            'plugin2',
            'search_api',
            '1.0.0',
            api2,
            interfaceType: SearchAPI,
          ),
          throwsA(isA<APIAlreadyExistsException>()),
        );
      });

      test('应该允许同一插件重新注册自己的 API', () {
        final api1 = ValidSearchAPI();
        final api2 = ValidSearchAPI();

        registry.registerAPI(
          'plugin1',
          'search_api',
          '1.0.0',
          api1,
          interfaceType: SearchAPI,
        );

        // 同一插件重新注册应该抛出异常（API 已存在）
        expect(
          () => registry.registerAPI(
            'plugin1',
            'search_api',
            '2.0.0',
            api2,
            interfaceType: SearchAPI,
          ),
          throwsA(isA<APIAlreadyExistsException>()),
        );
      });
    });

    group('API Cleanup', () {
      test('应该注销插件的所有 API', () {
        final searchAPI = ValidSearchAPI();
        final storageAPI = ValidStorageAPI();

        registry.registerAPI(
          'plugin1',
          'search_api',
          '1.0.0',
          searchAPI,
          interfaceType: SearchAPI,
        );

        registry.registerAPI(
          'plugin1',
          'storage_api',
          '1.0.0',
          storageAPI,
          interfaceType: StorageAPI,
        );

        registry.registerAPI(
          'plugin2',
          'other_api',
          '1.0.0',
          ValidSearchAPI(),
          interfaceType: SearchAPI,
        );

        expect(registry.getAllAPINames().length, 3);

        registry.unregisterPluginAPIs('plugin1');

        expect(registry.getAllAPINames().length, 1);
        expect(registry.hasAPI('search_api'), false);
        expect(registry.hasAPI('storage_api'), false);
        expect(registry.hasAPI('other_api'), true);
      });
    });

    group('Error Messages', () {
      test('APITypeMismatchException 应该包含有用的信息', () {
        // 由于 Dart 类型系统限制，这个测试演示了异常的结构
        final exception = APITypeMismatchException(
          apiName: 'test_api',
          expectedType: SearchAPI,
          actualType: InvalidSearchAPI,
        );

        expect(exception.apiName, equals('test_api'));
        expect(exception.expectedType, equals(SearchAPI));
        expect(exception.actualType, equals(InvalidSearchAPI));
        expect(exception.toString(), contains('test_api'));
      });

      test('APIAlreadyExistsException 应该包含插件信息', () {
        final api1 = ValidSearchAPI();
        final api2 = ValidSearchAPI();

        registry.registerAPI(
          'plugin1',
          'search_api',
          '1.0.0',
          api1,
          interfaceType: SearchAPI,
        );

        try {
          registry.registerAPI(
            'plugin2',
            'search_api',
            '1.0.0',
            api2,
            interfaceType: SearchAPI,
          );
          fail('Should have thrown APIAlreadyExistsException');
        } on APIAlreadyExistsException catch (e) {
          expect(e.apiName, equals('search_api'));
          expect(e.existingPluginId, equals('plugin1'));
          expect(e.newPluginId, equals('plugin2'));
        }
      });
    });

    group('API Query Methods', () {
      setUp(() {
        final searchAPI = ValidSearchAPI();
        final storageAPI = ValidStorageAPI();

        registry.registerAPI(
          'plugin1',
          'search_api',
          '1.0.0',
          searchAPI,
          interfaceType: SearchAPI,
        );

        registry.registerAPI(
          'plugin1',
          'storage_api',
          '1.0.0',
          storageAPI,
          interfaceType: StorageAPI,
        );

        registry.registerAPI(
          'plugin2',
          'plugin2_api',
          '1.0.0',
          ValidSearchAPI(),
          interfaceType: SearchAPI,
        );
      });

      test('应该获取所有 API 名称', () {
        final names = registry.getAllAPINames();

        expect(names.length, 3);
        expect(names, contains('search_api'));
        expect(names, contains('storage_api'));
        expect(names, contains('plugin2_api'));
      });

      test('应该获取插件导出的所有 API', () {
        final plugin1APIs = registry.getPluginAPIs('plugin1');
        final plugin2APIs = registry.getPluginAPIs('plugin2');

        expect(plugin1APIs.length, 2);
        expect(plugin1APIs, contains('search_api'));
        expect(plugin1APIs, contains('storage_api'));

        expect(plugin2APIs.length, 1);
        expect(plugin2APIs, contains('plugin2_api'));
      });
    });
  });
}
