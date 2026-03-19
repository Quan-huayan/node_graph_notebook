import 'package:flutter/material.dart';
import '../../core/services/i18n.dart';

/// 插件市场页面
class PluginMarketPage extends StatelessWidget {
  /// 创建插件市场页面
  const PluginMarketPage({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.t('Plugin Market')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              i18n.t('Available Plugins'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 插件列表
            Expanded(
              child: ListView.builder(
                itemCount: 5, // 示例插件数量
                itemBuilder: _buildPluginCard,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建插件卡片
  Widget _buildPluginCard(BuildContext context, int index) {
    final i18n = I18n.of(context);
    // 示例插件数据
    final plugins = [
      {
        'nameKey': 'Markdown Enhancer',
        'descriptionKey': 'Enhanced markdown editing with advanced features',
        'version': '1.0.0',
        'author': 'Plugin Developer',
        'icon': Icons.text_format,
      },
      {
        'nameKey': 'Mind Map',
        'descriptionKey': 'Create mind maps from your nodes',
        'version': '1.2.0',
        'author': 'Mind Map Team',
        'icon': Icons.account_tree,
      },
      {
        'nameKey': 'Export Tools',
        'descriptionKey': 'Additional export formats for your graphs',
        'version': '0.9.0',
        'author': 'Export Plugin Dev',
        'icon': Icons.file_download,
      },
      {
        'nameKey': 'AI Assistant',
        'descriptionKey': 'Integrate AI capabilities into your workflow',
        'version': '1.1.0',
        'author': 'AI Team',
        'icon': Icons.smart_toy,
      },
      {
        'nameKey': 'Theme Manager',
        'descriptionKey': 'Customize the appearance of your notebook',
        'version': '1.3.0',
        'author': 'Theme Dev',
        'icon': Icons.color_lens,
      },
    ];

    final plugin = plugins[index];
    final pluginName = i18n.t(plugin['nameKey'] as String);
    final pluginDescription = i18n.t(plugin['descriptionKey'] as String);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  plugin['icon'] as IconData,
                  size: 48,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pluginName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${i18n.t('Version:')} ${plugin['version']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${i18n.t('Author:')} ${plugin['author']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // TODO: 实现插件安装功能
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${i18n.t('Installing...')} $pluginName'),
                      ),
                    );
                  },
                  child: Text(i18n.t('Install')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              pluginDescription,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
