import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/plugon_flutter.dart';

class _TestBloc extends Bloc<Object, int> {
  _TestBloc() : super(0);
}

class _OtherBloc extends Bloc<Object, String> {
  _OtherBloc() : super('');
}

class _BlocPlugin extends Plugin {
  _BlocPlugin(this.blocId);

  final String blocId;

  @override
  PluginMetadata get metadata =>
      PluginMetadata(id: blocId, name: blocId, version: '1.0.0');

  @override
  void registerServices(ServiceCollection services) {
    services.addBloc((sp) => _TestBloc()); // owner 由 owned 视图盖章
  }
}

void main() {
  group('Bloc 适配', () {
    test('addBloc 产出 BlocProvider 包装', () {
      final collection = ServiceCollection();
      collection.addBloc<_TestBloc>((sp) => _TestBloc());
      final provider = collection.build();

      expect(
        buildBlocProviders(provider).single,
        isA<BlocProvider<_TestBloc>>(),
      );
    });

    testWidgets('多次 buildBlocProviders 后树中解析到的仍是同一 DI 单例', (tester) async {
      final collection = ServiceCollection();
      collection.addBloc<_TestBloc>((sp) => _TestBloc());
      final provider = collection.build();

      _TestBloc? captured;
      Widget tree() => MaterialApp(
        home: MultiBlocProvider(
          providers: buildBlocProviders(provider),
          child: Builder(
            builder: (context) {
              captured = BlocProvider.of<_TestBloc>(context);
              return const SizedBox();
            },
          ),
        ),
      );

      await tester.pumpWidget(tree());
      final first = captured!;
      expect(
        first,
        same(provider.get<_TestBloc>()),
        reason: 'widget 树解析的正是 DI 单例（修复旧版每次新建的缺陷）',
      );

      await tester.pumpWidget(tree());
      expect(captured, same(first), reason: '重复构建仍包装同一实例');
    });

    test('activeOwners 过滤禁用插件的 bloc', () {
      final collection = ServiceCollection();
      collection.addBloc<_TestBloc>((sp) => _TestBloc(), owner: 'p1');
      collection.addBloc<_OtherBloc>((sp) => _OtherBloc(), owner: 'p2');
      final provider = collection.build();

      final providers = buildBlocProviders(provider, activeOwners: {'p1'});

      expect(providers.single, isA<BlocProvider<_TestBloc>>());
    });

    test('插件卸载时 DI 关闭其 bloc（onDispose → close，树不重复关闭）', () async {
      final collection = ServiceCollection();
      final manager = PluginManager(services: collection);
      await manager.loadPlugin(_BlocPlugin('bp'));

      final bloc = manager.services.get<_TestBloc>();
      expect(bloc.isClosed, isFalse);

      await manager.unloadPlugin('bp');

      expect(bloc.isClosed, isTrue, reason: '卸载由 DI 关闭 bloc');
      expect(manager.services.tryGet<_TestBloc>(), isNull);
    });

    testWidgets('MultiBlocProvider 树中 context.read 解析到 DI 单例', (tester) async {
      final collection = ServiceCollection();
      collection.addBloc<_TestBloc>((sp) => _TestBloc());
      final provider = collection.build();
      _TestBloc? captured;

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: buildBlocProviders(provider),
            child: Builder(
              builder: (context) {
                captured = BlocProvider.of<_TestBloc>(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured, same(provider.get<_TestBloc>()));
    });
  });
}
