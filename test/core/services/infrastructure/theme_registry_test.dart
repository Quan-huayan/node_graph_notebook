import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:node_graph_notebook/core/services/infrastructure/theme_registry.dart' as theme;

void main() {
  group('ThemeExtension', () {
    test('应该创建包含所有属性的 ThemeExtension', () {
      const extension = theme.ThemeExtension(
        id: 'test',
        displayName: 'Test Extension',
        lightColors: {
          'primary': Color(0xFFFF0000),
          'secondary': Color(0xFF00FF00),
        },
        darkColors: {
          'primary': Color(0xFF0000FF),
          'secondary': Color(0xFFFFFF00),
        },
        customData: {
          'key1': 'value1',
          'key2': 42,
        },
      );

      expect(extension.id, 'test');
      expect(extension.displayName, 'Test Extension');
      expect(extension.lightColors.length, 2);
      expect(extension.darkColors.length, 2);
      expect(extension.customData.length, 2);
    });

    test('应该创建包含空颜色的 ThemeExtension', () {
      const extension = theme.ThemeExtension(
        id: 'test',
        displayName: 'Test Extension',
      );

      expect(extension.lightColors.isEmpty, true);
      expect(extension.darkColors.isEmpty, true);
      expect(extension.customData.isEmpty, true);
    });

    test('应该将 ThemeExtension 转换为 JSON', () {
      const extension = theme.ThemeExtension(
        id: 'test',
        displayName: 'Test Extension',
        lightColors: {
          'primary': Color(0xFFFF0000),
        },
        darkColors: {
          'primary': Color(0xFF0000FF),
        },
      );

      final json = extension.toJson();

      expect(json['id'], 'test');
      expect(json['displayName'], 'Test Extension');
      final lightColors = json['lightColors'] as Map<String, dynamic>;
      expect(lightColors['primary'], 4294901760);
      final darkColors = json['darkColors'] as Map<String, dynamic>;
      expect(darkColors['primary'], 4278190335);
    });

    test('应该获取亮色模式颜色', () {
      const extension = theme.ThemeExtension(
        id: 'test',
        displayName: 'Test Extension',
        lightColors: {
          'primary': Color(0xFFFF0000),
        },
      );

      final color = extension.getLightColor('primary');

      expect(color, const Color(0xFFFF0000));
    });

    test('对于不存在的亮色模式颜色应该返回 null', () {
      const extension = theme.ThemeExtension(
        id: 'test',
        displayName: 'Test Extension',
      );

      final color = extension.getLightColor('nonexistent');

      expect(color, null);
    });

    test('应该获取暗色模式颜色', () {
      const extension = theme.ThemeExtension(
        id: 'test',
        displayName: 'Test Extension',
        darkColors: {
          'primary': Color(0xFF0000FF),
        },
      );

      final color = extension.getDarkColor('primary');

      expect(color, const Color(0xFF0000FF));
    });

    test('对于不存在的暗色模式颜色应该返回 null', () {
      const extension = theme.ThemeExtension(
        id: 'test',
        displayName: 'Test Extension',
      );

      final color = extension.getDarkColor('nonexistent');

      expect(color, null);
    });

    test('应该根据亮度获取颜色', () {
      const extension = theme.ThemeExtension(
        id: 'test',
        displayName: 'Test Extension',
        lightColors: {
          'primary': Color(0xFFFF0000),
        },
        darkColors: {
          'primary': Color(0xFF0000FF),
        },
      );

      final lightColor = extension.getColor('primary', isDark: false);
      final darkColor = extension.getColor('primary', isDark: true);

      expect(lightColor, const Color(0xFFFF0000));
      expect(darkColor, const Color(0xFF0000FF));
    });

    test('应该获取自定义数据', () {
      const extension = theme.ThemeExtension(
        id: 'test',
        displayName: 'Test Extension',
        customData: {
          'key1': 'value1',
          'key2': 42,
        },
      );

      expect(extension.getCustomData<String>('key1'), 'value1');
      expect(extension.getCustomData<int>('key2'), 42);
    });

    test('对于不存在的自定义数据应该返回 null', () {
      const extension = theme.ThemeExtension(
        id: 'test',
        displayName: 'Test Extension',
      );

      expect(extension.getCustomData<String>('nonexistent'), null);
    });

    test('应该复制并更新属性', () {
      const extension = theme.ThemeExtension(
        id: 'test',
        displayName: 'Test Extension',
        lightColors: {
          'primary': Color(0xFFFF0000),
        },
      );

      final copied = extension.copyWith(
        id: 'new_id',
        displayName: 'New Extension',
      );

      expect(copied.id, 'new_id');
      expect(copied.displayName, 'New Extension');
      expect(copied.lightColors, extension.lightColors);
    });
  });

  group('ThemeRegistry', () {
    late theme.ThemeRegistry registry;

    setUp(() {
      registry = theme.ThemeRegistry();
    });

    group('Registration', () {
      test('应该注册主题扩展', () {
        const extension = theme.ThemeExtension(
          id: 'test',
          displayName: 'Test Extension',
        );

        registry.register(extension);

        expect(registry.isRegistered('test'), true);
        expect(registry.extensions.length, 1);
      });

      test('应该覆盖已存在的扩展', () {
        const extension1 = theme.ThemeExtension(
          id: 'test',
          displayName: 'Test Extension 1',
        );

        const extension2 = theme.ThemeExtension(
          id: 'test',
          displayName: 'Test Extension 2',
        );

        registry..register(extension1)
        ..register(extension2);

        expect(registry.extensions.length, 1);
        expect(registry.getExtension('test')?.displayName, 'Test Extension 2');
      });

      test('应该注册多个扩展', () {
        final extensions = [
          const theme.ThemeExtension(
            id: 'test1',
            displayName: 'Test Extension 1',
          ),
          const theme.ThemeExtension(
            id: 'test2',
            displayName: 'Test Extension 2',
          ),
          const theme.ThemeExtension(
            id: 'test3',
            displayName: 'Test Extension 3',
          ),
        ];

        registry.registerAll(extensions);

        expect(registry.extensions.length, 3);
        expect(registry.isRegistered('test1'), true);
        expect(registry.isRegistered('test2'), true);
        expect(registry.isRegistered('test3'), true);
      });
    });

    group('Unregistration', () {
      test('应该注销主题扩展', () {
        const extension = theme.ThemeExtension(
          id: 'test',
          displayName: 'Test Extension',
        );

        registry..register(extension)
        ..unregister('test');

        expect(registry.isRegistered('test'), false);
        expect(registry.extensions.length, 0);
      });

      test('注销不存在的扩展时不应该抛出错误', () {
        registry.unregister('nonexistent');

        expect(registry.extensions.length, 0);
      });
    });

    group('Get Extensions', () {
      test('应该通过 id 获取扩展', () {
        const extension = theme.ThemeExtension(
          id: 'test',
          displayName: 'Test Extension',
        );

        registry.register(extension);

        final retrieved = registry.getExtension('test');

        expect(retrieved, isNotNull);
        expect(retrieved?.id, 'test');
      });

      test('对于不存在的扩展应该返回 null', () {
        final retrieved = registry.getExtension('nonexistent');

        expect(retrieved, null);
      });

      test('应该获取所有扩展', () {
        final extensions = [
          const theme.ThemeExtension(
            id: 'test1',
            displayName: 'Test Extension 1',
          ),
          const theme.ThemeExtension(
            id: 'test2',
            displayName: 'Test Extension 2',
          ),
        ];

        registry.registerAll(extensions);

        final allExtensions = registry.extensions;

        expect(allExtensions.length, 2);
      });

      test('应该获取所有扩展 ID', () {
        final extensions = [
          const theme.ThemeExtension(
            id: 'test1',
            displayName: 'Test Extension 1',
          ),
          const theme.ThemeExtension(
            id: 'test2',
            displayName: 'Test Extension 2',
          ),
        ];

        registry.registerAll(extensions);

        final ids = registry.extensionIds;

        expect(ids.length, 2);
        expect(ids, contains('test1'));
        expect(ids, contains('test2'));
      });
    });

    group('Colors', () {
      test('应该获取所有亮色模式颜色', () {
        final extensions = [
          const theme.ThemeExtension(
            id: 'test1',
            displayName: 'Test Extension 1',
            lightColors: {
              'primary': Color(0xFFFF0000),
            },
          ),
          const theme.ThemeExtension(
            id: 'test2',
            displayName: 'Test Extension 2',
            lightColors: {
              'secondary': Color(0xFF00FF00),
            },
          ),
        ];

        registry.registerAll(extensions);

        final colors = registry.getAllLightColors();

        expect(colors.length, 2);
        expect(colors['primary'], const Color(0xFFFF0000));
        expect(colors['secondary'], const Color(0xFF00FF00));
      });

      test('应该获取所有暗色模式颜色', () {
        final extensions = [
          const theme.ThemeExtension(
            id: 'test1',
            displayName: 'Test Extension 1',
            darkColors: {
              'primary': Color(0xFF0000FF),
            },
          ),
          const theme.ThemeExtension(
            id: 'test2',
            displayName: 'Test Extension 2',
            darkColors: {
              'secondary': Color(0xFFFFFF00),
            },
          ),
        ];

        registry.registerAll(extensions);

        final colors = registry.getAllDarkColors();

        expect(colors.length, 2);
        expect(colors['primary'], const Color(0xFF0000FF));
        expect(colors['secondary'], const Color(0xFFFFFF00));
      });

      test('应该根据亮度获取所有颜色', () {
        const extension1 = theme.ThemeExtension(
          id: 'test1',
          displayName: 'Test Extension 1',
          lightColors: {
            'primary': Color(0xFFFF0000),
          },
          darkColors: {
            'primary': Color(0xFF0000FF),
          },
        );

        registry.register(extension1);

        final lightColors = registry.getAllColors(isDark: false);
        final darkColors = registry.getAllColors(isDark: true);

        expect(lightColors['primary'], const Color(0xFFFF0000));
        expect(darkColors['primary'], const Color(0xFF0000FF));
      });

      test('应该获取特定颜色', () {
        const extension = theme.ThemeExtension(
          id: 'test',
          displayName: 'Test Extension',
          lightColors: {
            'primary': Color(0xFFFF0000),
          },
          darkColors: {
            'primary': Color(0xFF0000FF),
          },
        );

        registry.register(extension);

        final lightColor = registry.getColor('primary', isDark: false);
        final darkColor = registry.getColor('primary', isDark: true);

        expect(lightColor, const Color(0xFFFF0000));
        expect(darkColor, const Color(0xFF0000FF));
      });

      test('对于不存在的颜色应该返回 null', () {
        final color = registry.getColor('nonexistent', isDark: false);

        expect(color, null);
      });
    });

    group('Merge Extensions', () {
      test('应该将扩展合并到 ThemeData', () {
        const extension = theme.ThemeExtension(
          id: 'test',
          displayName: 'Test Extension',
          lightColors: {
            'primary': Color(0xFFFF0000),
          },
        );

        registry.register(extension);

        final baseTheme = ThemeData();
        final mergedTheme = registry.mergeExtensions(baseTheme, isDark: false);

        expect(mergedTheme, isNotNull);
      });
    });

    group('Export and Import', () {
      test('应该将扩展导出为 JSON', () {
        const extension = theme.ThemeExtension(
          id: 'test',
          displayName: 'Test Extension',
          lightColors: {
            'primary': Color(0xFFFF0000),
          },
        );

        registry.register(extension);

        final json = registry.exportToJson();

        expect(json.containsKey('test'), true);
        final testJson = json['test'] as Map<String, dynamic>;
        expect(testJson['id'], 'test');
        expect(testJson['displayName'], 'Test Extension');
      });
    });

    group('Clear', () {
      test('应该清除所有扩展', () {
        final extensions = [
          const theme.ThemeExtension(
            id: 'test1',
            displayName: 'Test Extension 1',
          ),
          const theme.ThemeExtension(
            id: 'test2',
            displayName: 'Test Extension 2',
          ),
        ];

        registry..registerAll(extensions)
        ..clear();

        expect(registry.extensions.length, 0);
      });
    });

    group('Statistics', () {
      test('应该返回正确的统计信息', () {
        final extensions = [
          const theme.ThemeExtension(
            id: 'test1',
            displayName: 'Test Extension 1',
            lightColors: {
              'primary': Color(0xFFFF0000),
              'secondary': Color(0xFF00FF00),
            },
            darkColors: {
              'primary': Color(0xFF0000FF),
            },
          ),
          const theme.ThemeExtension(
            id: 'test2',
            displayName: 'Test Extension 2',
            lightColors: {
              'tertiary': Color(0xFFFFFF00),
            },
          ),
        ];

        registry.registerAll(extensions);

        final stats = registry.statistics;

        expect(stats['totalExtensions'], 2);
        expect(stats['extensionIds'], contains('test1'));
        expect(stats['extensionIds'], contains('test2'));
        expect(stats['totalLightColors'], 3);
        expect(stats['totalDarkColors'], 1);
      });
    });

    group('Plugin Extensions', () {
      test('应该按插件获取扩展', () {
        final extensions = [
          const theme.ThemeExtension(
            id: 'ai.primary',
            displayName: 'AI Primary',
          ),
          const theme.ThemeExtension(
            id: 'ai.secondary',
            displayName: 'AI Secondary',
          ),
          const theme.ThemeExtension(
            id: 'graph.primary',
            displayName: 'Graph Primary',
          ),
        ];

        registry.registerAll(extensions);

        final aiExtensions = registry.getExtensionsByPlugin('ai');
        final graphExtensions = registry.getExtensionsByPlugin('graph');

        expect(aiExtensions.length, 2);
        expect(graphExtensions.length, 1);
      });

      test('应该移除插件扩展', () {
        final extensions = [
          const theme.ThemeExtension(
            id: 'ai.primary',
            displayName: 'AI Primary',
          ),
          const theme.ThemeExtension(
            id: 'ai.secondary',
            displayName: 'AI Secondary',
          ),
          const theme.ThemeExtension(
            id: 'graph.primary',
            displayName: 'Graph Primary',
          ),
        ];

        registry..registerAll(extensions)
        ..removePluginExtensions('ai');

        expect(registry.isRegistered('ai.primary'), false);
        expect(registry.isRegistered('ai.secondary'), false);
        expect(registry.isRegistered('graph.primary'), true);
      });
    });

    group('ChangeNotifier', () {
      test('注册扩展时应该通知监听器', () {
        const extension = theme.ThemeExtension(
          id: 'test',
          displayName: 'Test Extension',
        );

        var notified = false;
        registry..addListener(() {
          notified = true;
        })

        ..register(extension);

        expect(notified, true);
      });

      test('注销扩展时应该通知监听器', () {
        const extension = theme.ThemeExtension(
          id: 'test',
          displayName: 'Test Extension',
        );

        registry.register(extension);

        var notified = false;
        registry..addListener(() {
          notified = true;
        })

        ..unregister('test');

        expect(notified, true);
      });

      test('清除扩展时应该通知监听器', () {
        const extension = theme.ThemeExtension(
          id: 'test',
          displayName: 'Test Extension',
        );

        registry.register(extension);

        var notified = false;
        registry..addListener(() {
          notified = true;
        })

        ..clear();

        expect(notified, true);
      });
    });
  });
}
