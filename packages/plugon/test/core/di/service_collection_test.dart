import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/core/di.dart';

class _Foo {
  _Foo([this.value = 0]);
  int value;
}

class _Bar {
  _Bar(this.foo);
  final _Foo foo;
}

/// 无参构造的接口实现（供 construct 模式测试）。
abstract class _IFoo {}

class _FooImpl implements _IFoo {
  _FooImpl();
}

void main() {
  group('ServiceCollection', () {
    test('owned 视图写入的描述符带 owner 标记，且共享宿主描述符列表', () {
      final collection = ServiceCollection();
      collection.owned('p1').addSingleton<_Foo>((sp) => _Foo());

      expect(collection.count, 1);
      final d = collection.descriptors.single;
      expect(d.owner, 'p1');
    });

    test('addInstance 产生普通单例描述符，owner 为空（宿主所有）', () {
      final collection = ServiceCollection();
      collection.addInstance<_Foo>(_Foo(42));

      final d = collection.descriptors.single;
      expect(d.lifetime, ServiceLifetime.singleton);
      expect(d.isNotifier, isFalse);
      expect(d.owner, isNull);
      expect(collection.count, 1);
    });

    test('owned 视图的盖章优先于显式 owner 参数（防止插件逃逸清理）', () {
      final collection = ServiceCollection();
      collection.owned('p1').addSingleton<_Foo>((sp) => _Foo(), owner: 'p2');
      expect(collection.descriptors.single.owner, 'p1');
    });

    test('同 owner 重复注册同 Type：get 返回最后一个注册（last-wins）', () {
      final collection = ServiceCollection();
      collection.owned('p1').addSingleton<_Foo>((sp) => _Foo(1));
      collection.owned('p1').addSingleton<_Foo>((sp) => _Foo(2));

      final provider = collection.build();
      expect(provider.get<_Foo>().value, 2, reason: 'last-wins');
      expect(
        provider.getAll<_Foo>().map((f) => f.value).toList(),
        [1, 2],
        reason: 'getAll 按注册序返回全部',
      );
    });

    test('跨 owner 重复注册同 Type：last-wins，各描述符保留 owner', () {
      final collection = ServiceCollection();
      collection.owned('p1').addSingleton<_Foo>((sp) => _Foo(1));
      collection.owned('p2').addSingleton<_Foo>((sp) => _Foo(2));

      final provider = collection.build();
      expect(provider.get<_Foo>().value, 2);
      expect(collection.descriptors.map((d) => d.owner).toList(), ['p1', 'p2']);
    });

    test('不同类型共存不冲突', () {
      final collection = ServiceCollection();
      collection.addSingleton<_Foo>((sp) => _Foo());
      collection.addSingleton<_Bar>((sp) => _Bar(sp.get<_Foo>()));
      expect(collection.build, returnsNormally);
      expect(collection.count, 2);
    });

    test('build 可多次调用，产生独立 provider 与独立单例缓存', () {
      final collection = ServiceCollection();
      collection.addSingleton<_Foo>((sp) => _Foo());

      final p1 = collection.build();
      final p2 = collection.build();
      expect(p1, isNot(same(p2)));
      final f1 = p1.get<_Foo>();
      expect(p1.get<_Foo>(), same(f1));
      expect(p2.get<_Foo>(), isNot(same(f1)));
    });

    test('注册序计数器是 collection 实例级的（两个集合各自从 0 开始）', () {
      final a = ServiceCollection();
      final b = ServiceCollection();
      a.addSingleton<_Foo>((sp) => _Foo());
      a.addSingleton<_Bar>((sp) => _Bar(sp.get<_Foo>()));
      b.addSingleton<_Foo>((sp) => _Foo());

      expect(a.descriptors[0].registrationOrder, 0);
      expect(a.descriptors[1].registrationOrder, 1);
      expect(b.descriptors[0].registrationOrder, 0);
    });

    test('isNotifier 标记被记录（core 不依赖 Flutter 类型）', () {
      final collection = ServiceCollection();
      collection.addSingleton<_Foo>((sp) => _Foo(), isNotifier: true);
      expect(collection.descriptors.single.isNotifier, isTrue);
    });

    test('null 工厂抛 InvalidServiceRegistrationException', () {
      final collection = ServiceCollection();
      expect(
        () => collection.addSingleton<_Foo>(null),
        throwsA(isA<InvalidServiceRegistrationException>()),
      );
    });

    test('descriptors 返回不可变快照', () {
      final collection = ServiceCollection();
      collection.addSingleton<_Foo>((sp) => _Foo());
      expect(() => collection.descriptors.clear(), throwsUnsupportedError);
    });

    test('双类型注册：TService 与 TImpl 都是解析键，type 为 TService', () {
      final collection = ServiceCollection();
      collection.addSingletonFor<_IFoo, _FooImpl>(factory: (sp) => _FooImpl());

      final d = collection.descriptors.single;
      expect(d.type, _IFoo);
      expect(d.implType, _FooImpl);
      expect(d.keys, [_IFoo, _FooImpl]);
      expect(d.lifetime, ServiceLifetime.singleton);
    });

    test('双类型 construct 模式：无参构造器 tear-off 直接注册', () {
      final collection = ServiceCollection();
      collection.addSingletonFor<_IFoo, _FooImpl>(construct: _FooImpl.new);

      final provider = collection.build();
      expect(provider.get<_IFoo>(), isA<_FooImpl>());
      expect(
        provider.get<_FooImpl>(),
        same(provider.get<_IFoo>()),
        reason: '两个键解析到同一实例',
      );
    });

    test(
      '双类型注册缺 factory/construct 或都给：抛 InvalidServiceRegistrationException',
      () {
        expect(
          () => ServiceCollection().addSingletonFor<_IFoo, _FooImpl>(),
          throwsA(isA<InvalidServiceRegistrationException>()),
        );
        expect(
          () => ServiceCollection().addSingletonFor<_IFoo, _FooImpl>(
            factory: (sp) => _FooImpl(),
            construct: _FooImpl.new,
          ),
          throwsA(isA<InvalidServiceRegistrationException>()),
        );
      },
    );

    test('TImpl == TService 的退化注册允许（.NET AddSingleton<Foo, Foo>）', () {
      final collection = ServiceCollection();
      collection.addSingletonFor<_Foo, _Foo>(factory: (sp) => _Foo(7));

      final provider = collection.build();
      expect(provider.get<_Foo>().value, 7);
    });

    test('tryAddSingleton：已注册时 no-op（描述符数不变）', () {
      final collection = ServiceCollection();
      collection.addSingleton<_Foo>((sp) => _Foo(1));
      collection.tryAddSingleton<_Foo>((sp) => _Foo(2));

      expect(collection.count, 1);
      expect(collection.build().get<_Foo>().value, 1);
    });

    test('tryAddSingletonFor：任一键已注册即 no-op（双键检查，比 .NET 更严）', () {
      final collection = ServiceCollection();
      collection.addSingleton<_FooImpl>((sp) => _FooImpl());
      collection.tryAddSingletonFor<_IFoo, _FooImpl>(
        factory: (sp) => _FooImpl(),
      );

      expect(collection.count, 1, reason: 'TImpl 键已占用，双类型注册被拒');
    });

    test('tryAddSingletonFor：两个键都空闲时正常注册', () {
      final collection = ServiceCollection();
      collection.tryAddSingletonFor<_IFoo, _FooImpl>(
        factory: (sp) => _FooImpl(),
      );

      expect(collection.count, 1);
      expect(collection.build().get<_IFoo>(), isA<_FooImpl>());
    });

    test('注册方法返回 this 支持链式（.NET IServiceCollection 风格）', () {
      final collection = ServiceCollection();
      final chained = collection
          .addSingleton<_Foo>((sp) => _Foo())
          .addTransient<_Bar>((sp) => _Bar(sp.get<_Foo>()));

      expect(chained, same(collection));
      expect(collection.count, 2);
    });

    test('addTransient 支持 onDispose（与 singleton/scoped 对称）', () {
      var disposed = 0;
      final collection = ServiceCollection();
      collection.addTransient<_Foo>(
        (sp) => _Foo(),
        onDispose: (_) => disposed++,
      );

      final provider = collection.build();
      provider.get<_Foo>();
      provider.dispose();

      expect(disposed, 1, reason: '可追踪 transient 在根销毁时清理');
    });

    test('build 支持 validateScopes 选项', () {
      final collection = ServiceCollection();
      collection.addScoped<_Foo>((sp) => _Foo());
      expect(collection.build(validateScopes: true), isA<ServiceProvider>());
    });
  });
}
