import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/core/di.dart';

/// 记录 dispose 次数的可释放实例。
class _Tracker implements Disposable {
  _Tracker(this.disposed);
  int disposed;

  @override
  void dispose() => disposed++;
}

class _Plain {}

/// 记录销毁顺序的可释放实例。
class _OrderTracker implements Disposable {
  _OrderTracker(this.name, this.log);
  final String name;
  final List<String> log;

  @override
  void dispose() => log.add(name);
}

ServiceProvider _build(void Function(ServiceCollection c) setup) {
  final collection = ServiceCollection();
  setup(collection);
  return collection.build();
}

void main() {
  group('所有权清理', () {
    test('disposeOwner 通过 Disposable 接口清理已实例化的单例', () {
      final tracker = _Tracker(0);
      final provider = _build((c) {
        c.owned('p1').addSingleton<_Tracker>((sp) => tracker);
        c.owned('p1').addSingleton<_Plain>((sp) => _Plain());
      });
      provider.get<_Tracker>();

      provider.disposeOwner('p1');

      expect(tracker.disposed, 1);
    });

    test('disposeOwner 调用 onDispose 回调（非 Disposable 实例）', () {
      var callbackCalls = 0;
      final provider = _build((c) {
        c
            .owned('p1')
            .addSingleton<_Plain>(
              (sp) => _Plain(),
              onDispose: (_) => callbackCalls++,
            );
      });
      provider.get<_Plain>();

      provider.disposeOwner('p1');

      expect(callbackCalls, 1);
    });

    test('disposeOwner 只清理实际实例化的实例（从未 get 的不触发清理）', () {
      final tracker = _Tracker(0);
      final provider = _build((c) {
        c.owned('p1').addSingleton<_Tracker>((sp) => tracker);
      });
      // 从未 get —— 不应被实例化，也不应被清理

      provider.disposeOwner('p1');

      expect(tracker.disposed, 0);
    });

    test('disposeOwner 移除该 owner 的描述符——之后 get 抛 ServiceNotFoundException', () {
      final provider = _build((c) {
        c.owned('p1').addSingleton<_Plain>((sp) => _Plain());
      });

      provider.disposeOwner('p1');

      expect(
        () => provider.get<_Plain>(),
        throwsA(isA<ServiceNotFoundException>()),
      );
      expect(provider.isRegistered<_Plain>(), isFalse);
    });

    test('disposeOwner 不影响其他 owner 的服务与实例', () {
      final p2Tracker = _Tracker(0);
      final provider = _build((c) {
        c.owned('p1').addSingleton<_Plain>((sp) => _Plain());
        c.owned('p2').addSingleton<_Tracker>((sp) => p2Tracker);
      });
      final p2Instance = provider.get<_Tracker>();

      provider.disposeOwner('p1');

      expect(p2Tracker.disposed, 0);
      expect(provider.get<_Tracker>(), same(p2Instance));
      expect(
        () => provider.get<_Plain>(),
        throwsA(isA<ServiceNotFoundException>()),
        reason: 'p1 描述符已移除，再解析应抛异常',
      );
    });

    test('disposeOwner 幂等——第二次调用不重复清理', () {
      final tracker = _Tracker(0);
      final provider = _build((c) {
        c.owned('p1').addSingleton<_Tracker>((sp) => tracker);
      });
      provider.get<_Tracker>();

      provider.disposeOwner('p1');
      provider.disposeOwner('p1');

      expect(tracker.disposed, 1);
    });

    test('provider.dispose 清理所有 owner 的已缓存实例，之后 get 抛 StateError', () {
      final t1 = _Tracker(0);
      final provider = _build((c) {
        c.owned('p1').addSingleton<_Tracker>((sp) => t1);
        c.owned('p2').addSingleton<_Plain>((sp) => _Plain());
      });
      provider.get<_Tracker>();
      provider.get<_Plain>();

      provider.dispose();

      expect(t1.disposed, 1);
      expect(() => provider.get<_Plain>(), throwsStateError);
    });

    test('disposeOwner 清理活跃 scope 中该 owner 的 scoped 实例', () {
      final tracker = _Tracker(0);
      final provider = _build((c) {
        c.owned('p1').addScoped<_Tracker>((sp) => tracker);
      });
      final scope = provider.createScope();
      scope.get<_Tracker>();

      provider.disposeOwner('p1');

      expect(tracker.disposed, 1);
    });

    test('scope.dispose 清理自己的 scoped 实例，但不清理共享单例', () {
      var scopedCreated = 0;
      final provider = _build((c) {
        c.addScoped<_Tracker>((sp) {
          scopedCreated++;
          return _Tracker(0);
        });
        c.addSingleton<_Plain>((sp) => _Plain());
      });
      final scope = provider.createScope();
      final scoped = scope.get<_Tracker>();
      provider.get<_Plain>();

      scope.dispose();

      expect(scoped.disposed, 1, reason: 'scoped 实例随作用域销毁');
      expect(provider.get<_Plain>(), isA<_Plain>(), reason: '单例不受影响');
      final rootTracker = provider.get<_Tracker>();
      expect(
        rootTracker,
        isNot(same(scoped)),
        reason: '根 provider 可创建自己的 scoped 实例',
      );
      expect(rootTracker.disposed, 0);
      expect(scopedCreated, 2);
    });

    test('transient 追踪：Disposable transient 在 scope 销毁时清理', () {
      final log = <String>[];
      final provider = _build((c) {
        c.addTransient<_OrderTracker>((sp) => _OrderTracker('t', log));
      });
      final scope = provider.createScope();
      scope.get<_OrderTracker>();

      scope.dispose();

      expect(log, ['t']);
    });

    test('transient 追踪：根销毁时清理根级解析的 transient', () {
      final log = <String>[];
      final provider = _build((c) {
        c.addTransient<_OrderTracker>((sp) => _OrderTracker('t', log));
      });
      provider.get<_OrderTracker>();

      provider.dispose();

      expect(log, ['t']);
    });

    test('transient 逆创建序销毁（.NET reverse creation order）', () {
      final log = <String>[];
      final provider = _build((c) {
        c.addTransient<_OrderTracker>((sp) => _OrderTracker('first', log));
        c.addTransient<_OrderTracker>((sp) => _OrderTracker('second', log));
      });
      final scope = provider.createScope();
      scope.getAll<_OrderTracker>();

      scope.dispose();

      expect(log, ['second', 'first']);
    });

    test('scoped 逆创建序销毁（.NET reverse creation order）', () {
      final log = <String>[];
      final provider = _build((c) {
        c.addScoped<_OrderTracker>((sp) => _OrderTracker('first', log));
        c.addScoped<_OrderTracker>((sp) => _OrderTracker('second', log));
      });
      final scope = provider.createScope();
      scope.getAll<_OrderTracker>();

      scope.dispose();

      expect(log, ['second', 'first']);
    });

    test('单例逆创建序销毁（.NET reverse creation order）', () {
      final log = <String>[];
      final provider = _build((c) {
        c.addSingleton<_Plain>(
          (sp) => _Plain(),
          onDispose: (_) => log.add('first'),
        );
        c.addSingleton<_Plain>(
          (sp) => _Plain(),
          onDispose: (_) => log.add('second'),
        );
      });
      provider.getAll<_Plain>(); // 实例化两个描述符的实例

      provider.dispose();

      expect(log, ['second', 'first']);
    });

    test('disposeOwner 清理该 owner 的可追踪 transient（根与 scope）', () {
      final log = <String>[];
      final provider = _build((c) {
        c
            .owned('p1')
            .addTransient<_OrderTracker>((sp) => _OrderTracker('root', log));
        c
            .owned('p1')
            .addTransient<_OrderTracker>((sp) => _OrderTracker('scope', log));
      });
      final scope = provider.createScope();
      provider.getAll<_OrderTracker>(); // 根级：两个描述符都实例化
      scope.get<_OrderTracker>(); // scope 级：last-wins 描述符

      provider.disposeOwner('p1');
      provider.disposeOwner('p1'); // 幂等

      expect(log.toSet(), {'root', 'scope'}, reason: '两处 transient 都被清理');
      expect(log.length, 3, reason: '根 2 个 + scope 1 个，不重复清理');
    });

    test('同类型多注册：disposeOwner 只清理目标 owner 的实例', () {
      final p1Tracker = _Tracker(0);
      final p2Tracker = _Tracker(0);
      final provider = _build((c) {
        c.owned('p1').addSingleton<_Tracker>((sp) => p1Tracker);
        c.owned('p2').addSingleton<_Tracker>((sp) => p2Tracker);
      });
      provider.getAll<_Tracker>(); // 实例化两个描述符的实例

      provider.disposeOwner('p1');

      expect(p1Tracker.disposed, 1);
      expect(p2Tracker.disposed, 0);
      expect(
        provider.get<_Tracker>(),
        same(p2Tracker),
        reason: 'last-wins 实例不受影响',
      );
    });

    test('已销毁的 scope 从根活跃列表移除——根销毁时不重复清理', () {
      final log = <String>[];
      final provider = _build((c) {
        c.addScoped<_OrderTracker>((sp) => _OrderTracker('s', log));
      });
      final scope = provider.createScope();
      scope.get<_OrderTracker>();
      scope.dispose();

      provider.dispose();

      expect(log, ['s'], reason: 'scope 已销毁并移除，根销毁不重复清理');
    });
  });
}
