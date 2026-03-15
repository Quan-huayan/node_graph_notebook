import 'package:flutter/material.dart';
import '../../plugins/builtin_plugins/graph/service/create_node_dialog.dart';
import '../../plugins/builtin_plugins/graph/ui/graph_view.dart';
import '../bars/core_toolbar.dart';

/// 主页面
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CoreToolbar(),
      body: const GraphView(),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateNodeDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateNodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const CreateNodeDialog(),
    );
  }
}
