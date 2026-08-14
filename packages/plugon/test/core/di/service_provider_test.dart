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

class _Baz {
  _Baz(this.bar);
  final _Bar bar;
}

/// 循环依赖夹具：A 依赖 B、B 依赖 A。
class _CycleA {
  _CycleA(this.b);
  final _CycleB b;
}

class _CycleB {
  _CycleB(this.a);
  final _CycleA a;
}

/// 无参构造的接口实现（供双类型注册测试）。
abstract class _IFoo {}

class _FooImpl implements _IFoo {
  _FooImpl();
}

ServiceProvider _build(void Function(ServiceCollection c) setup) {
  final collection = ServiceCollection();
  setup(collection);
  return collection.build();
}

void main() {
  group('ServiceProvider', () {
    test('未注册类型 get 抛 ServiceNotFoundException（而非裸 TypeError）', () {
      final provider = _build((c) {});

      expect(
        () => provider.get<_Foo>(),
        throwsA(isA<ServiceNotFoundException>()),
      );
    });

    test('tryGet 未注册返回 null，已注册返回值', () {
      final provider = _build((c) => c.addSingleton<_Foo>((sp) => _Foo(1)));

      expect(provider.tryGet<_Bar>(), isNull);
      expect(provider.tryGet<_Foo>()?.value, 1);
    });

    test('tryGet 对单例走缓存——不新建实例（回归：example 集成测试发现）', () {
      var created = 0;
      final provider = _build(
        (c) => c.addSingleton<_Foo>((sp) {
          created++;
          return _Foo(1);
        }),
      );

      final first = provider.get<_Foo>();
      expect(
        provider.tryGet<_Foo>(),
        same(first),
        reason: 'tryGet 必须返回缓存实例而非新实例',
      );
      expect(created, 1);
    });

    test('单例工厂懒加载——build 后未实例化，首次 get 才执行', () {
      var created = 0;
      final provider = _build(
        (c) => c.addSingleton<_Foo>((sp) {
          created++;
          return _Foo();
        }),
      );

      expect(created, 0, reason: 'build 不应触发任何工厂');
      provider.get<_Foo>();
      expect(created, 1);
    });

    test('单例重复 get 返回同一实例', () {
      final provider = _build((c) => c.addSingleton<_Foo>((sp) => _Foo()));
      expect(provider.get<_Foo>(), same(provider.get<_Foo>()));
    });

    test('transient 每次 get 都调用工厂并返回不同实例', () {
      var created = 0;
      final provider = _build(
        (c) => c.addTransient<_Foo>((sp) {
          created++;
          return _Foo();
        }),
      );

      expect(provider.get<_Foo>(), isNot(same(provider.get<_Foo>())));
      expect(created, 2);
    });

    test('嵌套解析时单例工厂恰好执行一次', () {
      var fooCreated = 0;
      final provider = _build((c) {
        c.addSingleton<_Foo>((sp) {
          fooCreated++;
          return _Foo();
        });
        c.addSingleton<_Bar>((sp) => _Bar(sp.get<_Foo>()));
        c.addSingleton<_Baz>((sp) => _Baz(sp.get<_Bar>()));
      });

      final baz = provider.get<_Baz>();
      expect(baz.bar.foo, same(provider.get<_Foo>()));
      expect(fooCreated, 1);
    });

    test('scoped 实例按作用域隔离；单例跨作用域共享', () {
      final provider = _build((c) {
        c.addScoped<_Foo>((sp) => _Foo());
        c.addSingleton<_Bar>((sp) => _Bar(sp.get<_Foo>()));
      });

      final s1 = provider.createScope();
      final s2 = provider.createScope();

      final a1 = s1.get<_Foo>();
      expect(s1.get<_Foo>(), same(a1), reason: '同一 scope 内复用');
      expect(s2.get<_Foo>(), isNot(same(a1)), reason: '不同 scope 独立');

      expect(s1.get<_Bar>(), same(provider.get<_Bar>()), reason: '单例共享');
    });

    test('工厂抛错时异常原样传播，且单例不缓存失败（可重试）', () {
      var calls = 0;
      final provider = _build(
        (c) => c.addSingleton<_Foo>((sp) {
          calls++;
          if (calls == 1) throw StateError('boom');
          return _Foo();
        }),
      );

      expect(() => provider.get<_Foo>(), throwsStateError);
      expect(() => provider.get<_Foo>(), returnsNormally, reason: '失败不缓存');
      expect(calls, 2);
    });

    test('isRegistered 反映注册状态而非实例化状态', () {
      var created = 0;
      final provider = _build(
        (c) => c.addSingleton<_Foo>((sp) {
          created++;
          return _Foo();
        }),
      );

      expect(provider.isRegistered<_Foo>(), isTrue);
      expect(created, 0);
    });

    test('last-wins：重复注册时 get/tryGet 返回最后一个', () {
      final provider = _build((c) {
        c.addSingleton<_Foo>((sp) => _Foo(1));
        c.addSingleton<_Foo>((sp) => _Foo(2));
      });

      expect(provider.get<_Foo>().value, 2);
      expect(provider.tryGet<_Foo>()?.value, 2);
    });

    test('getAll：按注册序返回全部；单例按描述符缓存复用', () {
      final provider = _build((c) {
        c.addSingleton<_Foo>((sp) => _Foo(1));
        c.addSingleton<_Foo>((sp) => _Foo(2));
      });

      final all = provider.getAll<_Foo>();
      expect(all.map((f) => f.value).toList(), [1, 2]);
      expect(
        all[0],
        same(provider.getAll<_Foo>()[0]),
        reason: '单例按描述符缓存，多次 getAll 复用',
      );
    });

    test('getAll：transient 每次新建（对应 .NET IEnumerable<T> 语义）', () {
      var created = 0;
      final provider = _build(
        (c) => c.addTransient<_Foo>((sp) {
          created++;
          return _Foo(created);
        }),
      );

      final first = provider.getAll<_Foo>();
      final second = provider.getAll<_Foo>();
      expect(first.single, isNot(same(second.single)));
      expect(created, 2);
    });

    test('getAll：未注册返回空列表', () {
      final provider = _build((c) {});
      expect(provider.getAll<_Foo>(), isEmpty);
    });

    test('双类型注册：别名键解析到同一实例', () {
      final provider = _build((c) {
        c.addSingletonFor<_IFoo, _FooImpl>(factory: (sp) => _FooImpl());
      });

      expect(provider.get<_IFoo>(), same(provider.get<_FooImpl>()));
    });

    test('分裂陷阱：具体类型单独再注册后两个键各自 last-wins', () {
      final provider = _build((c) {
        c.addSingletonFor<_IFoo, _FooImpl>(factory: (sp) => _FooImpl());
        c.addSingleton<_FooImpl>((sp) => _FooImpl());
      });

      expect(provider.get<_IFoo>(), isA<_FooImpl>());
      expect(
        provider.get<_FooImpl>(),
        isNot(same(provider.get<_IFoo>())),
        reason: 'get<IFoo> 走别名描述符，get<FooImpl> 走单独描述符',
      );
    });

    test('循环依赖：A→B→A 抛 CircularDependencyException 并带完整链路', () {
      final provider = _build((c) {
        c.addSingleton<_CycleA>((sp) => _CycleA(sp.get<_CycleB>()));
        c.addSingleton<_CycleB>((sp) => _CycleB(sp.get<_CycleA>()));
      });

      expect(
        () => provider.get<_CycleA>(),
        throwsA(
          isA<CircularDependencyException>().having((e) => e.chain, 'chain', [
            _CycleA,
            _CycleB,
            _CycleA,
          ]),
        ),
      );
    });

    test('循环检测按描述符身份：别名键自引用也报循环', () {
      final provider = _build((c) {
        c.addSingletonFor<_IFoo, _FooImpl>(
          factory: (sp) => sp.get<_IFoo>() as _FooImpl,
        );
      });

      expect(
        () => provider.get<_IFoo>(),
        throwsA(isA<CircularDependencyException>()),
      );
    });

    test('单例工厂收到根 provider：scoped 依赖命中根级缓存（不跨代捕获）', () {
      final provider = _build((c) {
        c.addScoped<_Foo>((sp) => _Foo(1));
        c.addSingleton<_Bar>((sp) => _Bar(sp.get<_Foo>()));
      });
      final s1 = provider.createScope();
      final s2 = provider.createScope();

      final barFromS1 = s1.get<_Bar>();
      expect(barFromS1, same(s2.get<_Bar>()), reason: '单例共享');
      expect(
        barFromS1.foo,
        same(provider.get<_Foo>()),
        reason: '工厂收到根 provider，scoped 依赖缓存于根而非 s1',
      );
    });

    test('validateScopes 默认关闭：根解析 scoped 允许（退化为根级实例）', () {
      final provider = _build((c) => c.addScoped<_Foo>((sp) => _Foo()));
      expect(provider.get<_Foo>(), isA<_Foo>());
      expect(
        provider.get<_Foo>(),
        same(provider.get<_Foo>()),
        reason: '根级 scoped 退化为根内单例',
      );
    });

    test('validateScopes：开启后根解析 scoped 抛异常，scope 内正常', () {
      final collection = ServiceCollection();
      collection.addScoped<_Foo>((sp) => _Foo());
      final strict = collection.build(validateScopes: true);

      expect(
        () => strict.get<_Foo>(),
        throwsA(isA<ScopedResolutionFromRootException>()),
      );
      expect(strict.createScope().get<_Foo>(), isA<_Foo>());
    });
  });
}
