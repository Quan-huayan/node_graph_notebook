import 'package:flutter_test/flutter_test.dart';
import 'package:plugon/core/extensions.dart';

const _toolbar = ExtensionPoint<String>('toolbar', name: '工具栏');
const _toolbarInt = ExtensionPoint<int>('toolbar');

void main() {
  group('ExtensionRegistry', () {
    test('注册扩展点；重复注册抛 ExtensionPointAlreadyRegisteredException', () {
      final r = ExtensionRegistry();
      r.registerExtensionPoint(_toolbar);

      expect(r.hasExtensionPoint(_toolbar), isTrue);
      expect(
        () => r.registerExtensionPoint(_toolbar),
        throwsA(isA<ExtensionPointAlreadyRegisteredException>()),
      );
    });

    test('向未注册的扩展点添加贡献抛 ExtensionPointNotRegisteredException（拼写安全）', () {
      final r = ExtensionRegistry();
      expect(
        () => r.addContribution(const ExtensionPoint<String>('nope'), 'x'),
        throwsA(isA<ExtensionPointNotRegisteredException>()),
      );
    });

    test('getAll 按优先级升序，同优先级按注册序破平', () {
      final r = ExtensionRegistry();
      r.registerExtensionPoint(_toolbar);
      r.addContribution(_toolbar, 'low', priority: 100);
      r.addContribution(_toolbar, 'high', priority: 0);
      r.addContribution(_toolbar, 'tie1', priority: 50);
      r.addContribution(_toolbar, 'tie2', priority: 50);

      expect(r.getAll(_toolbar), ['high', 'tie1', 'tie2', 'low']);
    });

    test('宿主贡献（owner 为 null）始终活跃；插件贡献默认非活跃', () {
      final r = ExtensionRegistry();
      r.registerExtensionPoint(_toolbar);
      r.addContribution(_toolbar, 'host');
      r.addContribution(_toolbar, 'plugin', ownerPluginId: 'p1');

      expect(r.getActive(_toolbar), ['host']);
      expect(r.getAll(_toolbar), ['host', 'plugin']);
    });

    test('setPluginActive 切换插件的贡献活跃性；重新激活无需重新注册', () {
      final r = ExtensionRegistry();
      r.registerExtensionPoint(_toolbar);
      r.addContribution(_toolbar, 'plugin', ownerPluginId: 'p1');

      r.setPluginActive('p1', true);
      expect(r.getActive(_toolbar), ['plugin']);
      expect(r.isPluginActive('p1'), isTrue);

      r.setPluginActive('p1', false);
      expect(r.getActive(_toolbar), isEmpty);
      expect(r.isPluginActive('p1'), isFalse);

      r.setPluginActive('p1', true);
      expect(r.getActive(_toolbar), ['plugin'], reason: '激活由插件状态派生，贡献无需重新注册');
    });

    test('removeOwner 移除该插件的贡献与激活状态，不影响其他插件', () {
      final r = ExtensionRegistry();
      r.registerExtensionPoint(_toolbar);
      r.addContribution(_toolbar, 'host');
      r.addContribution(_toolbar, 'a', ownerPluginId: 'p1');
      r.addContribution(_toolbar, 'b', ownerPluginId: 'p2');
      r.setPluginActive('p1', true);
      r.setPluginActive('p2', true);

      r.removeOwner('p1');

      expect(r.getAll(_toolbar), ['host', 'b']);
      expect(r.getActive(_toolbar), ['host', 'b']);
      expect(r.isPluginActive('p1'), isFalse);
      expect(r.isPluginActive('p2'), isTrue);
    });

    test('removeExtensionPoint 移除扩展点及其全部贡献', () {
      final r = ExtensionRegistry();
      r.registerExtensionPoint(_toolbar);
      r.addContribution(_toolbar, 'x');

      r.removeExtensionPoint(_toolbar);

      expect(r.pointCount, 0);
      expect(r.hasExtensionPoint(_toolbar), isFalse);
      expect(
        () => r.addContribution(_toolbar, 'y'),
        throwsA(isA<ExtensionPointNotRegisteredException>()),
      );
    });

    test('同 id 不同泛型类型的扩展点共存（键为 (Type, id)）', () {
      final r = ExtensionRegistry();
      r.registerExtensionPoint(_toolbar);
      r.registerExtensionPoint(_toolbarInt);
      r.addContribution(_toolbar, 'a');
      r.addContribution(_toolbarInt, 1);

      expect(r.pointCount, 2);
      expect(r.getAll(_toolbar), ['a']);
      expect(r.getAll(_toolbarInt), [1]);
      expect(r.extensionPointKeys, contains((type: String, id: 'toolbar')));
      expect(r.extensionPointKeys, contains((type: int, id: 'toolbar')));
    });

    test('同一插件可向同一扩展点贡献多个值，按优先级排序', () {
      final r = ExtensionRegistry();
      r.registerExtensionPoint(_toolbar);
      r.addContribution(_toolbar, 'm1', ownerPluginId: 'p1', priority: 10);
      r.addContribution(_toolbar, 'm2', ownerPluginId: 'p1', priority: 5);
      r.setPluginActive('p1', true);

      expect(r.getActive(_toolbar), ['m2', 'm1']);
      expect(r.contributionCount, 2);
    });

    test('hasContributions 支持 includeInactive 参数', () {
      final r = ExtensionRegistry();
      r.registerExtensionPoint(_toolbar);
      r.addContribution(_toolbar, 'x', ownerPluginId: 'p1');

      expect(r.hasContributions(_toolbar, includeInactive: true), isTrue);
      expect(r.hasContributions(_toolbar), isFalse, reason: 'p1 未激活');
    });

    test('对未注册扩展点的查询返回空，不抛错', () {
      final r = ExtensionRegistry();
      const missing = ExtensionPoint<String>('missing');

      expect(r.getAll(missing), isEmpty);
      expect(r.getActive(missing), isEmpty);
      expect(r.hasContributions(missing), isFalse);
    });
  });
}
