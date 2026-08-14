import 'package:core/infrastructure/i18n.dart';
import 'package:flutter/material.dart';
import 'package:plugin/plugin.dart';

import 'zh_translations.dart';

/// Chinese Language Plugin
class I18nZhPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'i18n_zh',
    name: 'Chinese Language Pack',
    version: '1.0.0',
    description: 'Provides Chinese translations for the application',
    author: 'Node Graph Notebook',
  );

  @override
  List<ServiceRegistration> registerServices() => [];

  @override
  Future<void> onLoad(PluginContext context) async {
    final i18n = context.get<I18n>();
    i18n.registerLanguage('zh', 'Chinese', '简体中文');
    i18n.addTranslations('zh', ZhTranslations.data);
    debugPrint('[I18nZhPlugin] Chinese language pack loaded');
  }
}
