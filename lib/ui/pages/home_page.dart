import 'package:flutter/material.dart';
import '../../plugins/graph/service/create_node_dialog.dart';
import '../../plugins/graph/ui/graph_view.dart';
import '../bars/core_toolbar.dart';

/// 主页面
///
/// 应用的主页面，包含核心工具栏、图形视图和创建节点的浮动按钮
class HomePage extends StatefulWidget {
  /// 创建一个主页面
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: const CoreToolbar(),
      body: const GraphView(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateNodeDialog,
        child: const Icon(Icons.add),
      ),
    );

  /// 显示创建节点对话框
  void _showCreateNodeDialog() {
    showDialog(context: context, builder: (ctx) => const CreateNodeDialog());
  }
}
