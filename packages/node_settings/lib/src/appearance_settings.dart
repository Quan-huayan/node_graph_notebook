/// AppearanceSettings —— 外观设置条目（M7.2：字体大小恢复）。
///
/// 条目 = 设置节点（kind == 'settings-appearance'，references.settings
/// 指向设置容器）；open 形态 = 字体大小表单（编辑壳层 ThemeController
/// 的 textScale——MaterialApp 经 MediaQuery 应用，即时生效）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

/// 外观设置 Concept。
class AppearanceSettingsConcept extends Concept {
  /// 无状态（可 const 装配）。
  const AppearanceSettingsConcept();

  @override
  String get id => 'com.example.settings:appearance';

  @override
  String get name => '外观';

  @override
  String get description => '字体大小';

  @override
  Set<String> get slots => const <String>{'settings'};

  @override
  Set<String> get requiredSlots => const <String>{'settings'};

  @override
  Map<String, MetadataField> get metadataSchema =>
      const <String, MetadataField>{
        'kind': MetadataField(name: 'kind', type: MetadataType.string),
      };

  @override
  Set<String> get requiredMetadataKeys => const <String>{'kind'};

  @override
  ContentRequirement get contentRequirement => ContentRequirement.none;

  @override
  bool validate(Node node) =>
      node.metadata['kind'] == 'settings-appearance' &&
      node.references['settings'] != null;

  @override
  Node createInstance({
    required String id,
    required String title,
    String? content,
    Map<String, String>? references,
    Map<String, dynamic>? metadata,
  }) {
    throw UnimplementedError('设置条目节点由宿主播种（写路径）');
  }

  @override
  Hook createHook(Node instance, HookContext context) => AppearanceSettingsHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// 外观设置 Hook（open = 表单）。
class AppearanceSettingsHook extends Hook {
  /// 视图面。
  const AppearanceSettingsHook({required this.nodeId, required this.hookId});

  @override
  final String nodeId;

  @override
  final String hookId;

  @override
  Map<String, Hook> get references => const <String, Hook>{};

  @override
  void render(RenderContext context) {
    if (context is! FlutterRenderContext) {
      return;
    }
    final host = context.host;
    final sink = context.sink;
    if (host == null || sink == null) {
      return;
    }
    sink.add(
      AppearanceSettingsForm(
        theme: host.serviceProvider.get<ThemeController>(),
        i18n: host.i18nService,
      ),
    );
  }
}

/// 字体大小表单（open 形态）。
class AppearanceSettingsForm extends StatelessWidget {
  /// 注入主题控制器（壳层——textScale）与国际化服务。
  const AppearanceSettingsForm({
    super.key,
    required this.theme,
    required this.i18n,
  });

  /// 主题控制器（文字缩放）。
  final ThemeController theme;

  /// 国际化服务（壳层）。
  final I18nService i18n;

  /// 档位（小 / 中 / 大）。
  static const List<double> _scales = <double>[0.85, 1, 1.25];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // M7.2（E：语言切换即时刷新设置表单）。
    listenable: Listenable.merge(<Listenable>[theme, i18n]),
    builder: (context, _) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(i18n.t('settings.fontSize')),
          const SizedBox(height: 8),
          SegmentedButton<double>(
            segments: <ButtonSegment<double>>[
              ButtonSegment<double>(
                value: _scales[0],
                label: Text(i18n.t('settings.fontSmall')),
              ),
              ButtonSegment<double>(
                value: _scales[1],
                label: Text(i18n.t('settings.fontMedium')),
              ),
              ButtonSegment<double>(
                value: _scales[2],
                label: Text(i18n.t('settings.fontLarge')),
              ),
            ],
            selected: <double>{theme.textScale},
            onSelectionChanged: (selection) =>
                theme.setTextScale(selection.first),
            showSelectedIcon: false,
          ),
          const SizedBox(height: 16),
          // M7.2 补修（具体字体切换——旧版能力恢复）。
          Text(i18n.t('settings.fontFamily')),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: theme.fontFamily,
            decoration: const InputDecoration(isDense: true),
            items: <DropdownMenuItem<String?>>[
              DropdownMenuItem<String?>(
                value: null,
                child: Text(i18n.t('settings.fontDefault')),
              ),
              for (final family in _fontFamilies)
                DropdownMenuItem<String?>(value: family, child: Text(family)),
            ],
            onChanged: theme.setFontFamily,
          ),
        ],
      ),
    ),
  );

  /// 可选字体族（Windows 常见中文字体 + 等宽）。
  static const List<String> _fontFamilies = <String>[
    'Microsoft YaHei',
    'SimSun',
    'SimHei',
    'KaiTi',
    'Consolas',
  ];
}
