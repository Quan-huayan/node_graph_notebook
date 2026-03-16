import 'package:flutter/material.dart';

/// 插件市场页面
class PluginMarketPage extends StatelessWidget {
  /// 创建插件市场页面
  const PluginMarketPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
        title: const Text('Plugin Market'),
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
            const Text(
              'Available Plugins',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  /// 构建插件卡片
  Widget _buildPluginCard(BuildContext context, int index) {
    // 示例插件数据
    final plugins = [
      {
        'name': 'Markdown Enhancer',
        'description': 'Enhanced markdown editing with advanced features',
        'version': '1.0.0',
        'author': 'Plugin Developer',
        'icon': Icons.text_format,
      },
      {
        'name': 'Mind Map',
        'description': 'Create mind maps from your nodes',
        'version': '1.2.0',
        'author': 'Mind Map Team',
        'icon': Icons.account_tree,
      },
      {
        'name': 'Export Tools',
        'description': 'Additional export formats for your graphs',
        'version': '0.9.0',
        'author': 'Export Plugin Dev',
        'icon': Icons.file_download,
      },
      {
        'name': 'AI Assistant',
        'description': 'Integrate AI capabilities into your workflow',
        'version': '1.1.0',
        'author': 'AI Team',
        'icon': Icons.smart_toy,
      },
      {
        'name': 'Theme Manager',
        'description': 'Customize the appearance of your notebook',
        'version': '1.3.0',
        'author': 'Theme Dev',
        'icon': Icons.color_lens,
      },
    ];

    final plugin = plugins[index];

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
                        plugin['name'] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Version: ${plugin['version']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        'By: ${plugin['author']}',
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
                        content: Text('Installing ${plugin['name']}...'),
                      ),
                    );
                  },
                  child: const Text('Install'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              plugin['description'] as String,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
