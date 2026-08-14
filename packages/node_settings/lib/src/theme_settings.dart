/// ThemeSettings —— 主题设置条目（M7.2 阶段 C：设置容器化）。
///
/// 条目 = 设置节点（kind == 'settings-theme'，references.settings 指向
/// 设置容器）——**sidebar 形态 = 列表行**（点击 = 自弹打开，D1 打开
/// 契约），**open 形态 = 主题切换表单**（编辑壳层 ThemeController，
/// M7.2 E3：MaterialApp 即时响应）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

/// 主题设置 Concept。
class ThemeSettingsConcept extends Concept {
  /// 无状态（可 const 装配）。
  const ThemeSettingsConcept();

  @override
  String get id => 'com.example.settings:theme';

  @override
  String get name => '主题';

  @override
  String get description => '主题设置（明/暗/跟随系统）';

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
      node.metadata['kind'] == 'settings-theme' &&
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
  Hook createHook(Node instance, HookContext context) => ThemeSettingsHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// 主题设置 Hook（sidebar = 行；open = 表单）。
class ThemeSettingsHook extends Hook {
  /// 视图面。
  const ThemeSettingsHook({required this.nodeId, required this.hookId});

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
    // open 形态 = 表单（M7.2 修正：设置容器内联铺开，无 sidebar 行/嵌套弹框）。
    sink.add(
      ThemeSettingsForm(
        theme: host.serviceProvider.get<ThemeController>(),
        i18n: host.i18nService,
      ),
    );
  }
}

/// 主题切换表单（open 形态——原 SettingsDialog 内容，M7.2 E3 接线）。
class ThemeSettingsForm extends StatelessWidget {
  /// 注入主题控制器（壳层服务）与国际化服务。
  const ThemeSettingsForm({super.key, required this.theme, required this.i18n});

  /// 主题控制器。
  final ThemeController theme;

  /// 国际化服务（壳层——文案走语言包）。
  final I18nService i18n;

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
          Text(i18n.t('settings.theme')),
          const SizedBox(height: 8),
          SegmentedButton<AppThemeMode>(
            segments: <ButtonSegment<AppThemeMode>>[
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.system,
                label: Text(i18n.t('theme.system')),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.light,
                label: Text(i18n.t('theme.light')),
              ),
              ButtonSegment<AppThemeMode>(
                value: AppThemeMode.dark,
                label: Text(i18n.t('theme.dark')),
              ),
            ],
            selected: <AppThemeMode>{theme.mode},
            onSelectionChanged: (selection) => theme.setMode(selection.first),
            showSelectedIcon: false,
          ),
        ],
      ),
    ),
  );
}
