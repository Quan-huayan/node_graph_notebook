import 'package:flutter/material.dart';
import '../../plugins/graph/ui/graph_view.dart';
import '../bars/core_toolbar.dart';

/// 主页面
///
/// 应用的主页面，包含核心工具栏和图形视图
class HomePage extends StatefulWidget {
  /// 创建一个主页面
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) => const Scaffold(
      appBar: CoreToolbar(),
      body: GraphView(),
    );
}
