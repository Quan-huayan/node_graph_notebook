import 'package:flutter/material.dart';
import '../widgets/plugin_item.dart';

/// 插件市场页面
class PluginMarketPage extends StatelessWidget {
  PluginMarketPage({super.key});

  // 示例插件数据
  final List<Map<String, dynamic>> plugins = [
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
      'icon': Icons.smart_toy      
    },
    {
      'name': 'Theme Manager',
      'description': 'Customize the appearance of your notebook',
      'version': '1.3.0',
      'author': 'Theme Dev',
      'icon': Icons.color_lens,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plugin Market'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Available Plugins',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // 插件列表
            Expanded(
              child: ListView.builder(
                itemCount: plugins.length, // 插件数量
                itemBuilder: (context, index) {
                  final plugin = plugins[index];
                  return PluginItem(
                    name: plugin['name'] as String,
                    description: plugin['description'] as String,
                    version: plugin['version'] as String,
                    author: plugin['author'] as String,
                    icon: plugin['icon'] as IconData,
                    onInstall: () {
                      // 实现插件安装功能
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Installing ${plugin['name']}...')),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
