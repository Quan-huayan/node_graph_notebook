import 'package:flutter/material.dart';
import '../dialogs/create_node_dialog.dart';
import '../views/graph_view.dart';
import '../bars/note_app_bar.dart';

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
      appBar: const NoteAppBarWidget(),
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