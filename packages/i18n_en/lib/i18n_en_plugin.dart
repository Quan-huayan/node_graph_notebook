import 'package:core/infrastructure/i18n.dart';
import 'package:flutter/material.dart';
import 'package:plugin/plugin.dart';

import 'en_translations.dart';

/// English Language Plugin
class I18nEnPlugin extends Plugin {
  @override
  PluginMetadata get metadata => const PluginMetadata(
    id: 'i18n_en',
    name: 'English Language Pack',
    version: '1.0.0',
    description: 'Provides English translations for the application',
    author: 'Node Graph Notebook',
  );

  @override
  List<ServiceRegistration> registerServices() => [];

  @override
  Future<void> onLoad(PluginContext context) async {
    final i18n = context.get<I18n>();
    i18n.registerLanguage('en', 'English', 'English');
    i18n.addTranslations('en', EnTranslations.data);
    debugPrint('[I18nEnPlugin] English language pack loaded');
  }
}
