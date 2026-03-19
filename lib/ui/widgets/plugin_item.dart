import 'package:flutter/material.dart';
import '../../core/services/i18n.dart';

/// 插件项组件
class PluginItem extends StatelessWidget {
  /// 创建插件项组件
  const PluginItem({
    super.key,
    required this.name,
    required this.description,
    required this.version,
    required this.author,
    required this.icon,
    required this.onInstall,
  });

  /// 插件名称
  final String name;
  
  /// 插件描述
  final String description;
  
  /// 插件版本
  final String version;
  
  /// 插件作者
  final String author;
  
  /// 插件图标
  final IconData icon;
  
  /// 安装按钮点击回调
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final i18n = I18n.of(context);

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
                Icon(icon, size: 48, color: Theme.of(context).primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${i18n.t('Version:')} $version',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${i18n.t('Author:')} $author',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: onInstall,
                  child: Text(i18n.t('Install')),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
