/// I18nSettings —— 语言设置条目（M7.2 阶段 C + 上移壳层修正）。
///
/// 条目 = 设置节点（kind == 'settings-i18n'，references.settings 指向
/// 设置容器）；open 形态 = 语言切换表单（编辑**壳层 I18nService**——
/// M7.2：i18n 上移 appframe，语言包全局可达，切换即时生效）。
/// 聚合归设置容器（数据引用），插件不互依赖（04 §三 约束 3）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

/// 语言设置 Concept。
class I18nSettingsConcept extends Concept {
  /// 无状态（可 const 装配）。
  const I18nSettingsConcept();

  /// Concept id（契约字段，接口文档见 core_data Concept）。
  @override
  String get id => 'com.example.i18n:settings';

  /// 语言条目显示名。
  @override
  String get name => '语言';

  /// 语言条目说明。
  @override
  String get description => '界面语言（中文 / English）';

  /// 设置槽位（聚合归设置容器反查）。
  @override
  Set<String> get slots => const <String>{'settings'};

  /// 必需设置槽位（不挂设置容器即不匹配）。
  @override
  Set<String> get requiredSlots => const <String>{'settings'};

  /// 元数据模式（仅 kind；字段语义见 core_data MetadataField）。
  @override
  Map<String, MetadataField> get metadataSchema =>
      const <String, MetadataField>{
        'kind': MetadataField(name: 'kind', type: MetadataType.string),
      };

  /// 必需元数据键（kind）。
  @override
  Set<String> get requiredMetadataKeys => const <String>{'kind'};

  /// 内容要求（无内容负载）。
  @override
  ContentRequirement get contentRequirement => ContentRequirement.none;

  /// 结构匹配：kind == 'settings-i18n' 且指向设置容器。
  @override
  bool validate(Node node) =>
      node.metadata['kind'] == 'settings-i18n' &&
      node.references['settings'] != null;

  /// 播种实例：设置条目由宿主创建，此处显式拒绝（契约 core_data
  /// Concept.createInstance 文档化）。
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

  /// 创建语言设置 Hook（open 形态 = 切换表单）。
  @override
  Hook createHook(Node instance, HookContext context) => I18nSettingsHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// 语言设置 Hook（open = 表单）。
class I18nSettingsHook extends Hook {
  /// 视图面。
  const I18nSettingsHook({required this.nodeId, required this.hookId});

  /// 节点 id（契约字段，core_data Hook 文档化）。
  @override
  final String nodeId;

  /// Hook id（节点 id@形态）。
  @override
  final String hookId;

  /// 无子 Hook 引用。
  @override
  Map<String, Hook> get references => const <String, Hook>{};

  /// open 形态渲染语言切换表单（契约见 core_data Hook.render）。
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
    sink.add(I18nSettingsForm(i18n: host.serviceProvider.get<I18nService>()));
  }
}

/// 语言切换表单（open 形态）。
class I18nSettingsForm extends StatefulWidget {
  /// 注入国际化服务。
  const I18nSettingsForm({super.key, required this.i18n});

  /// 国际化服务。
  final I18nService i18n;

  @override
  State<I18nSettingsForm> createState() => _I18nSettingsFormState();
}

class _I18nSettingsFormState extends State<I18nSettingsForm> {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.i18n.t('settings.language')),
        const SizedBox(height: 8),
        SegmentedButton<AppLanguage>(
          segments: <ButtonSegment<AppLanguage>>[
            ButtonSegment<AppLanguage>(
              value: AppLanguage.zh,
              label: Text(widget.i18n.t('language.zh')),
            ),
            const ButtonSegment<AppLanguage>(
              value: AppLanguage.en,
              label: Text('English'),
            ),
          ],
          selected: <AppLanguage>{widget.i18n.language},
          onSelectionChanged: (selection) =>
              setState(() => widget.i18n.setLanguage(selection.first)),
          showSelectedIcon: false,
        ),
      ],
    ),
  );
}
