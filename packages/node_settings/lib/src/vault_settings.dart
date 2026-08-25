/// VaultSettings —— 仓库设置条目（M7.3 多仓库）：
/// 仓库列表（切换/移除）+ 新建仓库。管理 = VaultManager 服务
/// （appframe 组合根注入——设置条目经 plugon DI 解析）。
library;

import 'package:appframe/appframe.dart';
import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';

/// 仓库设置 Concept（kind == 'settings-vault'）。
class VaultSettingsConcept extends Concept {
  /// 无状态（可 const 装配）。
  const VaultSettingsConcept();

  @override
  String get id => 'com.example.settings:vault';

  @override
  String get name => '仓库';

  @override
  String get description => '多仓库管理';

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
      node.metadata['kind'] == 'settings-vault' &&
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
  Hook createHook(Node instance, HookContext context) => VaultSettingsHook(
    nodeId: instance.id,
    hookId: '${instance.id}@${context.kind}',
  );
}

/// 仓库设置 Hook（open = 管理表单）。
class VaultSettingsHook extends Hook {
  /// 视图面。
  const VaultSettingsHook({required this.nodeId, required this.hookId});

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
    // 单仓库模式（测试/无 VaultHost 实现）→ 不渲染（tryGet 容错）。
    // M8：经接口解析——可替换实现（不依赖具体 VaultManager）。
    final manager = host.serviceProvider.tryGet<VaultHost>();
    if (manager == null) {
      return;
    }
    sink.add(VaultSettingsForm(manager: manager, i18n: host.i18nService));
  }
}

/// 仓库管理表单（列表 + 新建）。
class VaultSettingsForm extends StatefulWidget {
  /// 注入仓库管理器与国际化服务。
  const VaultSettingsForm({
    super.key,
    required this.manager,
    required this.i18n,
  });

  /// 多仓库宿主（M8：经 VaultHost 接口——可替换实现）。
  final VaultHost manager;

  /// 国际化服务（壳层）。
  final I18nService i18n;

  @override
  State<VaultSettingsForm> createState() => _VaultSettingsFormState();
}

class _VaultSettingsFormState extends State<VaultSettingsForm> {
  final TextEditingController _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.manager.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.manager.removeListener(_onChanged);
    _name.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    await widget.manager.createVault(name);
    _name.clear();
  }

  Future<void> _remove(VaultEntry entry) async {
    // 二次确认：移除 = 数据移入回收站（可找回），仍属危险操作。
    final i18n = widget.i18n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n.t('vault.removeConfirmTitle')),
        content: Text(
          i18n.t('vault.removeConfirmBody').replaceFirst('%s', entry.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(i18n.t('dialog.cancel')),
          ),
          // 危险操作（数据移入回收站）确认按钮错误色，与取消/主操作区分。
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(i18n.t('vault.remove')),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await widget.manager.removeVault(entry.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(i18n.t('vault.removed')),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    final manager = widget.manager;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.t('vault.settingsHint'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          // 仓库列表。
          for (final vault in manager.vaults)
            ListTile(
              dense: true,
              leading: Icon(
                vault.id == manager.current.id
                    ? Icons.storage
                    : Icons.folder_outlined,
                size: 18,
              ),
              title: Text(
                vault.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                vault.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              trailing: vault.id == manager.current.id
                  ? Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      tooltip: i18n.t('vault.remove'),
                      onPressed: () => _remove(vault),
                    ),
            ),
          const Divider(height: 8),
          // 新建仓库。
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: i18n.t('vault.name'),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _create(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _create,
                child: Text(i18n.t('vault.create')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
