/// AISettings —— AI 设置条目（M7.2 阶段 C：AI API key 设置恢复）。
///
/// 条目 = 设置节点（kind == 'settings-ai'，references.settings 指向设置
/// 容器）——**sidebar 形态 = 列表行**（点击 = 自弹打开），**open 形态 =
/// API key 表单**（编辑 AIProviderConfig，ConfigAIProvider 即时生效）。
/// 聚合归设置容器（数据引用），插件不互依赖（04 §三 约束 3）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

import 'ai_provider_config.dart';

/// AI 设置 Concept。
class AISettingsConcept extends Concept {
  /// 无状态（可 const 装配）。
  const AISettingsConcept();

  @override
  String get id => 'com.example.ai:settings';

  @override
  String get name => 'AI 设置';

  @override
  String get description => 'AI API key 配置';

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
      node.metadata['kind'] == 'settings-ai' &&
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
  Hook createHook(Node instance, HookContext context) => AISettingsHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// AI 设置 Hook（sidebar = 行；open = 表单）。
class AISettingsHook extends Hook {
  /// 视图面。
  const AISettingsHook({required this.nodeId, required this.hookId});

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
      AISettingsForm(
        config: host.serviceProvider.get<AIProviderConfig>(),
        i18n: host.i18nService,
      ),
    );
  }
}

/// API key 表单（open 形态）。
class AISettingsForm extends StatefulWidget {
  /// 注入配置与国际化服务。
  const AISettingsForm({super.key, required this.config, required this.i18n});

  /// AI 后端配置。
  final AIProviderConfig config;

  /// 国际化服务（壳层——文案走语言包）。
  final I18nService i18n;

  @override
  State<AISettingsForm> createState() => _AISettingsFormState();
}

class _AISettingsFormState extends State<AISettingsForm> {
  late final TextEditingController _key;
  late final TextEditingController _model;
  late final TextEditingController _baseUrl;

  @override
  void initState() {
    super.initState();
    _key = TextEditingController(text: widget.config.apiKey);
    _model = TextEditingController(text: widget.config.model);
    _baseUrl = TextEditingController(text: widget.config.baseUrl);
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  void _save() {
    widget.config
      ..setApiKey(_key.text)
      ..setModel(_model.text)
      ..setBaseUrl(_baseUrl.text);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.i18n.t('settings.saved')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    // M7.2（E：语言切换即时刷新设置表单）；P0-4：config 也监听——
    // 保存后模式指示即时刷新（Mock/OpenAI 状态明示）。
    listenable: Listenable.merge(<Listenable>[widget.i18n, widget.config]),
    builder: (context, _) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // P0-4：当前模式明示——未配置 key 时用户知道 AI 处于 Mock 演示。
          Row(
            children: [
              Icon(
                widget.config.apiKey.isEmpty
                    ? Icons.science_outlined
                    : Icons.check_circle_outline,
                size: 16,
                color: widget.config.apiKey.isEmpty
                    ? Theme.of(context).colorScheme.outline
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.i18n.t('ai.modeLabel')}：'
                '${widget.config.apiKey.isEmpty ? widget.i18n.t('ai.modeMock') : widget.i18n.t('ai.modeOpenAI')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // M7.2 补修（设置不再简陋）：key + 模型 + 基础 URL 三字段。
          Text(widget.i18n.t('settings.aiKey')),
          const SizedBox(height: 8),
          TextField(
            controller: _key,
            obscureText: true,
            decoration: const InputDecoration(hintText: 'sk-…', isDense: true),
          ),
          const SizedBox(height: 12),
          Text(widget.i18n.t('settings.aiModel')),
          const SizedBox(height: 8),
          TextField(
            controller: _model,
            decoration: const InputDecoration(
              hintText: 'gpt-4o-mini',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          Text(widget.i18n.t('settings.aiBaseUrl')),
          const SizedBox(height: 8),
          TextField(
            controller: _baseUrl,
            decoration: const InputDecoration(
              hintText: 'https://api.openai.com/v1',
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _save,
            child: Text(widget.i18n.t('dialog.save')),
          ),
        ],
      ),
    ),
  );
}
