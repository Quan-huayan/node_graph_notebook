/// MarketDialog —— 插件市场对话框（M7，01 拍板 #40）。
///
/// 静态列表：已装插件（plugins 参数——M7 修正：服务注入，不依赖
/// 组合根 host）+ 本地概念条目——MVP 无网络（市场 = 展示层）。
library;

import 'package:appframe/appframe.dart';
import 'package:flutter/material.dart';
import 'package:plugon/plugon.dart';

/// 插件市场对话框。
class MarketDialog extends StatelessWidget {
  /// 注入已装插件列表与国际化服务（M7 修正：经 plugon DI）。
  const MarketDialog({super.key, required this.plugins, required this.i18n});

  /// 已装插件列表。
  final List<Plugin> plugins;

  /// 国际化服务（壳层文案）。
  final I18nService i18n;

  @override
  Widget build(BuildContext context) {
    final installed = plugins;
    return AlertDialog(
      title: Text(i18n.t('market.title')),
      content: SizedBox(
        width: 420,
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                i18n.t('market.installed'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final plugin in installed)
              ListTile(
                dense: true,
                leading: const Icon(Icons.extension, size: 18),
                title: Text(plugin.metadata.name),
                subtitle: Text(plugin.metadata.id),
                trailing: const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Colors.green,
                ),
              ),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                i18n.t('market.concepts'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            for (final entry in _concepts)
              ListTile(
                dense: true,
                leading: const Icon(Icons.schema_outlined, size: 18),
                title: Text(entry.$1),
                subtitle: Text(i18n.t(entry.$2)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(i18n.t('dialog.close')),
        ),
      ],
    );
  }
}

/// 本地概念条目（静态展示数据——MVP 无网络市场；描述走翻译表）。
const List<(String, String)> _concepts = <(String, String)>[
  ('folder', 'market.concept.folder'),
  ('contain', 'market.concept.contain'),
  ('canvas', 'market.concept.canvas'),
  ('connection', 'market.concept.connection'),
  ('ai', 'market.concept.ai'),
  ('chat', 'market.concept.chat'),
  ('Lua Concept', 'market.concept.lua'),
];
