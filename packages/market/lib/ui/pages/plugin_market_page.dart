import 'package:flutter/material.dart';

/// 插件市场页面
///
/// 显示插件列表，允许用户浏览、安装和管理插件
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
      body: const Center(
        child: Text('Plugin Market - Coming Soon'),
      ),
    );
}
